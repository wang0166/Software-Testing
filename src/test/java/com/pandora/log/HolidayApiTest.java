package com.pandora.log;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.service.HolidaySourceClient;
import com.pandora.log.service.HolidaySourceClient.HolidayDay;
import com.pandora.log.service.HolidaySourceClient.HolidaySourceException;
import com.pandora.log.service.HolidaySourceClient.LunarDay;
import com.pandora.log.service.HolidaySourceClient.LunarSnapshot;
import com.pandora.log.service.HolidaySourceClient.StatutorySnapshot;
import com.pandora.log.support.EmbeddedPostgresSupport;

/** 日历节假日接口：法定放假、调休补班、传统节日、缓存与降级行为。 */
@SpringBootTest
@AutoConfigureMockMvc
class HolidayApiTest extends EmbeddedPostgresSupport {

    private static final String URL = createDatabase("pandora_holiday_test");
    private static final String PASSWORD = "holiday-pass-123";

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> URL);
        registry.add("spring.datasource.username", () -> "postgres");
        registry.add("spring.datasource.password", () -> "");
        registry.add("app.jwt.secret", () -> "pandora-holiday-test-secret-key-0123456789");
        registry.add("app.admin.init-password", () -> "");
        registry.add("app.log-deadline-job.enabled", () -> "false");
    }

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private PasswordEncoder passwords;

    @MockBean
    private HolidaySourceClient sourceClient;

    private String token;

    @BeforeEach
    void fixtures() throws Exception {
        jdbc.execute("TRUNCATE holiday_year_cache");
        jdbc.execute("TRUNCATE companies, users RESTART IDENTITY CASCADE");
        jdbc.queryForObject(
                "INSERT INTO users(username, password_hash, real_name, role_code) "
                        + "VALUES ('admin', ?, 'admin', 'ADMIN') RETURNING id",
                Long.class, passwords.encode(PASSWORD));
        token = response(post("/api/auth/login"), null,
                Map.of("username", "admin", "password", PASSWORD)).path("data")
                .path("accessToken").asText();
    }

    @Test
    void mergesStatutoryDaysAndTraditionalFestivalsAndCaches() throws Exception {
        when(sourceClient.fetchStatutory(2026)).thenReturn(statutory2026());
        when(sourceClient.fetchLunar(2026)).thenReturn(lunar2026());

        JsonNode data = ok(get("/api/calendar/holidays").param("year", "2026"));

        assertThat(data.path("year").asInt()).isEqualTo(2026);
        assertThat(data.path("region").asText()).isEqualTo("CN");
        assertThat(data.path("timezone").asText()).isEqualTo("Asia/Shanghai");
        assertThat(data.path("dataStatus").asText()).isEqualTo("published");
        assertThat(data.path("lastSyncedAt").asText()).isNotBlank();
        assertThat(data.path("sourceUrl").asText()).isNotBlank();
        assertThat(data.path("fromCache").asBoolean()).isFalse();

        JsonNode newYear = day(data, "2026-01-01");
        assertThat(newYear.path("dayType").asText()).isEqualTo("holiday");
        assertThat(newYear.path("holidayName").asText()).isEqualTo("元旦");
        assertThat(newYear.path("festivals").size()).isZero();
        assertThat(newYear.path("sourceUrl").asText()).isNotBlank();

        assertThat(day(data, "2026-01-04").path("dayType").asText()).isEqualTo("makeup_workday");
        // 除夕与春节来自农历换算，落在法定放假日上时写入 festivals
        assertThat(day(data, "2026-02-16").path("festivals").get(0).asText()).isEqualTo("除夕");
        assertThat(day(data, "2026-02-17").path("festivals").get(0).asText()).isEqualTo("春节");
        assertThat(day(data, "2026-09-25").path("festivals").get(0).asText()).isEqualTo("中秋节");
        // 重阳节不放假，以 normal 日期承载传统节日名称
        assertThat(day(data, "2026-10-18").path("dayType").asText()).isEqualTo("normal");
        assertThat(day(data, "2026-10-18").path("festivals").get(0).asText()).isEqualTo("重阳节");

        assertThat(jdbc.queryForObject("SELECT count(*) FROM holiday_year_cache", Long.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT source FROM holiday_year_cache WHERE year = 2026",
                String.class)).isNotBlank();
        assertThat(jdbc.queryForObject("SELECT synced_at IS NOT NULL FROM holiday_year_cache WHERE year = 2026",
                Boolean.class)).isTrue();

        JsonNode cached = ok(get("/api/calendar/holidays").param("year", "2026"));
        assertThat(cached.path("fromCache").asBoolean()).isTrue();
        verify(sourceClient, times(1)).fetchStatutory(2026);
    }

    @Test
    void unpublishedYearReturnsExplicitStatusInsteadOfEmptyHolidays() throws Exception {
        when(sourceClient.fetchStatutory(2035))
                .thenReturn(new StatutorySnapshot("https://example.test/2035", List.of()));

        JsonNode data = ok(get("/api/calendar/holidays").param("year", "2035"));

        assertThat(data.path("dataStatus").asText()).isEqualTo("not_published");
        assertThat(data.path("days").size()).isZero();
        assertThat(data.path("message").asText()).contains("尚未公布");
        verify(sourceClient, never()).fetchLunar(2035);
    }

    @Test
    void fallsBackToStaleCacheWhenSourceFails() throws Exception {
        when(sourceClient.fetchStatutory(2026)).thenReturn(statutory2026());
        when(sourceClient.fetchLunar(2026)).thenReturn(lunar2026());
        ok(get("/api/calendar/holidays").param("year", "2026"));
        jdbc.update("UPDATE holiday_year_cache SET synced_at = now() - interval '3 days' WHERE year = 2026");

        when(sourceClient.fetchStatutory(2026))
                .thenThrow(new HolidaySourceException("外部接口不可用"));

        JsonNode data = ok(get("/api/calendar/holidays").param("year", "2026"));

        assertThat(data.path("dataStatus").asText()).isEqualTo("published");
        assertThat(data.path("fromCache").asBoolean()).isTrue();
        assertThat(data.path("message").asText()).contains("缓存");
        assertThat(data.path("days").size()).isGreaterThan(0);
    }

    @Test
    void reportsUnavailableWhenSourceFailsWithoutCache() throws Exception {
        when(sourceClient.fetchStatutory(2026))
                .thenThrow(new HolidaySourceException("外部接口不可用"));

        JsonNode data = ok(get("/api/calendar/holidays").param("year", "2026"));

        assertThat(data.path("dataStatus").asText()).isEqualTo("unavailable");
        assertThat(data.path("days").size()).isZero();
        assertThat(data.path("message").asText()).contains("不可用");
    }

    @Test
    void marksPartialWhenLunarSourceFails() throws Exception {
        when(sourceClient.fetchStatutory(2026)).thenReturn(statutory2026());
        when(sourceClient.fetchLunar(2026)).thenThrow(new HolidaySourceException("农历接口不可用"));

        JsonNode data = ok(get("/api/calendar/holidays").param("year", "2026"));

        assertThat(data.path("dataStatus").asText()).isEqualTo("partial");
        assertThat(data.path("message").asText()).contains("农历");
        assertThat(day(data, "2026-01-01").path("dayType").asText()).isEqualTo("holiday");
    }

    @Test
    void rejectsUnsupportedYear() throws Exception {
        JsonNode body = response(get("/api/calendar/holidays").param("year", "1999"), token, null);

        assertThat(body.path("code").asInt()).isEqualTo(40001);
    }

    private StatutorySnapshot statutory2026() {
        return new StatutorySnapshot("https://example.test/holiday/2026", List.of(
                new HolidayDay("2026-01-01", true, "元旦"),
                new HolidayDay("2026-01-04", false, "元旦后补班"),
                new HolidayDay("2026-02-16", true, "除夕"),
                new HolidayDay("2026-02-17", true, "初一"),
                new HolidayDay("2026-06-19", true, "端午节"),
                new HolidayDay("2026-09-25", true, "中秋节")));
    }

    private LunarSnapshot lunar2026() {
        return new LunarSnapshot("https://example.test/lunar/2026", List.of(
                new LunarDay("2026-02-17", 1, 1),
                new LunarDay("2026-03-03", 1, 15),
                new LunarDay("2026-06-19", 5, 5),
                new LunarDay("2026-09-25", 8, 15),
                new LunarDay("2026-10-18", 9, 9)));
    }

    private static JsonNode day(JsonNode data, String date) {
        for (JsonNode node : data.path("days")) {
            if (date.equals(node.path("date").asText())) {
                return node;
            }
        }
        throw new AssertionError("未返回日期 " + date);
    }

    private JsonNode ok(MockHttpServletRequestBuilder request) throws Exception {
        return response(request, token, null).path("data");
    }

    private JsonNode response(MockHttpServletRequestBuilder request, String bearer, Object body)
            throws Exception {
        if (bearer != null) {
            request.header("Authorization", "Bearer " + bearer);
        }
        if (body != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        }
        var result = mvc.perform(request).andReturn();
        return json.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }
}
