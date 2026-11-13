package com.pandora.log.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * 节假日数据源客户端：
 * 1) 法定放假与调休补班取 timor.tech 的公开接口；
 * 2) 农历日期取 apihubs.cn，用于识别元宵、七夕等不放假但属于传统节日的日期。
 * 所有调用只在服务端进行，失败时抛出 {@link HolidaySourceException} 由上层决定是否降级到缓存。
 */
@Service
public class HolidaySourceClient {

    private static final Logger log = LoggerFactory.getLogger(HolidaySourceClient.class);

    private final ObjectMapper objectMapper;
    private final String statutoryBaseUrl;
    private final String lunarBaseUrl;
    private final Duration requestTimeout;
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    public HolidaySourceClient(ObjectMapper objectMapper,
            @Value("${app.holiday.statutory-base-url:https://timor.tech/api/holiday/year}") String statutoryBaseUrl,
            @Value("${app.holiday.lunar-base-url:https://api.apihubs.cn/holiday/get}") String lunarBaseUrl,
            @Value("${app.holiday.timeout-seconds:10}") long timeoutSeconds) {
        this.objectMapper = objectMapper;
        this.statutoryBaseUrl = trimSlash(statutoryBaseUrl, "https://timor.tech/api/holiday/year");
        this.lunarBaseUrl = trimSlash(lunarBaseUrl, "https://api.apihubs.cn/holiday/get");
        this.requestTimeout = Duration.ofSeconds(Math.max(3, timeoutSeconds));
    }

    /** 查询某年的法定放假与调休补班；返回空列表表示该年度安排尚未公布。 */
    public StatutorySnapshot fetchStatutory(int year) {
        String url = statutoryBaseUrl + "/" + year;
        JsonNode root = get(url);
        if (root.path("code").asInt(-1) != 0) {
            throw new HolidaySourceException("法定节假日接口返回异常状态");
        }
        List<HolidayDay> days = new ArrayList<>();
        JsonNode holiday = root.path("holiday");
        if (holiday.isObject()) {
            Iterator<Map.Entry<String, JsonNode>> fields = holiday.fields();
            while (fields.hasNext()) {
                JsonNode node = fields.next().getValue();
                String date = node.path("date").asText("").trim();
                if (date.isEmpty()) {
                    continue;
                }
                days.add(new HolidayDay(date, node.path("holiday").asBoolean(false),
                        node.path("name").asText("").trim()));
            }
        }
        days.sort(Comparator.comparing(HolidayDay::date));
        return new StatutorySnapshot(url, days);
    }

    /** 查询某年的每日农历日期，用于推导传统节日。 */
    public LunarSnapshot fetchLunar(int year) {
        String url = lunarBaseUrl + "?year=" + year + "&size=400";
        JsonNode root = get(url);
        if (root.path("code").asInt(-1) != 0) {
            throw new HolidaySourceException("农历数据接口返回异常状态");
        }
        List<LunarDay> days = new ArrayList<>();
        for (JsonNode node : root.path("data").path("list")) {
            String date = node.path("date").asText("").trim();
            int lunarDate = node.path("lunar_date").asInt(0);
            if (date.isEmpty() || date.length() != 8 || lunarDate <= 0) {
                continue;
            }
            days.add(new LunarDay(
                    date.substring(0, 4) + "-" + date.substring(4, 6) + "-" + date.substring(6, 8),
                    (lunarDate / 100) % 100,
                    lunarDate % 100));
        }
        days.sort(Comparator.comparing(LunarDay::date));
        return new LunarSnapshot(url, days);
    }

    private JsonNode get(String url) {
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .header("Accept", "application/json")
                    .timeout(requestTimeout)
                    .GET()
                    .build();
            HttpResponse<String> response = httpClient.send(request,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() != 200) {
                throw new HolidaySourceException("节假日数据源返回 HTTP " + response.statusCode());
            }
            return objectMapper.readTree(response.body());
        } catch (HolidaySourceException exception) {
            throw exception;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new HolidaySourceException("节假日数据源调用被中断");
        } catch (Exception exception) {
            log.warn("节假日数据源调用失败：{} {}", url, exception.getClass().getSimpleName());
            throw new HolidaySourceException("节假日数据源暂时不可用");
        }
    }

    private static String trimSlash(String value, String fallback) {
        String normalized = value == null || value.isBlank() ? fallback : value.trim();
        return normalized.endsWith("/") ? normalized.substring(0, normalized.length() - 1) : normalized;
    }

    public record HolidayDay(String date, boolean offDay, String name) {
    }

    public record StatutorySnapshot(String sourceUrl, List<HolidayDay> days) {
    }

    public record LunarDay(String date, int lunarMonth, int lunarDay) {
    }

    public record LunarSnapshot(String sourceUrl, List<LunarDay> days) {
    }

    /** 数据源调用失败。上层据此改用缓存或返回明确的不可用状态。 */
    public static class HolidaySourceException extends RuntimeException {
        public HolidaySourceException(String message) {
            super(message);
        }
    }
}
