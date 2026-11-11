package com.pandora.log.service;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.common.BusinessException;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.CalendarHolidayDtos.HolidayDayDto;
import com.pandora.log.dto.CalendarHolidayDtos.HolidayYearDto;
import com.pandora.log.service.HolidaySourceClient.HolidayDay;
import com.pandora.log.service.HolidaySourceClient.LunarDay;

/**
 * 中国大陆节假日查询：按年合并法定放假、调休补班与农历传统节日。
 * 数据按年写入 holiday_year_cache，外部接口不可用时回退到已有缓存；
 * 未公布放假安排的年份返回 NOT_PUBLISHED，不会当成“没有假期”。
 */
@Service
public class HolidayService {

    private static final Logger log = LoggerFactory.getLogger(HolidayService.class);

    private static final int MIN_YEAR = 2007;
    private static final int MAX_YEAR = 2100;
    private static final Duration PARTIAL_CACHE_TTL = Duration.ofHours(1);
    private static final String SOURCE = "timor.tech(法定放假/补班) + apihubs.cn(农历)";
    private static final DateTimeFormatter SYNCED_AT_FORMAT = DateTimeFormatter.ISO_OFFSET_DATE_TIME;

    /** 农历固定日期的传统节日，不一定是法定假日。 */
    private static final Map<String, String> LUNAR_FESTIVALS = Map.ofEntries(
            Map.entry("1-1", "春节"),
            Map.entry("1-15", "元宵节"),
            Map.entry("2-2", "龙抬头"),
            Map.entry("5-5", "端午节"),
            Map.entry("7-7", "七夕节"),
            Map.entry("7-15", "中元节"),
            Map.entry("8-15", "中秋节"),
            Map.entry("9-9", "重阳节"),
            Map.entry("12-8", "腊八节"));

    /** 数据源本身以节日命名的传统节日（清明为节气，不参与农历换算）。 */
    private static final Set<String> NAMED_TRADITIONAL_FESTIVALS = Set.of(
            "春节", "除夕", "清明节", "端午节", "中秋节");

    private final JdbcTemplate jdbcTemplate;
    private final HolidaySourceClient sourceClient;
    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final Duration cacheTtl;

    public HolidayService(JdbcTemplate jdbcTemplate,
            HolidaySourceClient sourceClient,
            ObjectMapper objectMapper,
            Clock clock,
            @Value("${app.holiday.cache-hours:24}") long cacheHours) {
        this.jdbcTemplate = jdbcTemplate;
        this.sourceClient = sourceClient;
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.cacheTtl = Duration.ofHours(Math.max(1, cacheHours));
    }

    public HolidayYearDto holidays(int year) {
        if (year < MIN_YEAR || year > MAX_YEAR) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED,
                    "年份需在 " + MIN_YEAR + " 至 " + MAX_YEAR + " 之间");
        }

        CacheRow cached = findCache(year);
        if (cached != null && fresh(cached)) {
            return toDto(cached, true, null);
        }

        try {
            Snapshot snapshot = fetch(year);
            OffsetDateTime syncedAt = saveCache(snapshot);
            return toDto(snapshot, syncedAt, false);
        } catch (RuntimeException exception) {
            if (cached != null) {
                log.warn("节假日数据源不可用，改用 {} 年缓存：{}", year, exception.getMessage());
                return toDto(cached, true, "外部节假日接口暂时不可用，已使用本地缓存数据");
            }
            log.warn("节假日数据源不可用且无 {} 年缓存：{}", year, exception.getMessage());
            return new HolidayYearDto(year, "UNAVAILABLE", false, SOURCE, null, null, false,
                    "外部节假日接口暂时不可用，且本地暂无该年份缓存", List.of());
        }
    }

    private Snapshot fetch(int year) {
        HolidaySourceClient.StatutorySnapshot statutory = sourceClient.fetchStatutory(year);
        if (statutory.days().isEmpty()) {
            // 空结果代表放假安排尚未公布，需要保留明确状态而不是当成没有假期。
            return new Snapshot(year, false, true, statutory.sourceUrl(), List.of(),
                    "该年度放假安排尚未公布");
        }

        List<LunarDay> lunar;
        boolean lunarAvailable = true;
        try {
            lunar = sourceClient.fetchLunar(year).days();
        } catch (RuntimeException exception) {
            lunar = List.of();
            lunarAvailable = false;
        }

        List<HolidayDayDto> days = merge(statutory.days(), lunar);
        return new Snapshot(year, true, lunarAvailable, statutory.sourceUrl(), days,
                lunarAvailable ? null : "农历数据源暂时不可用，元宵节等传统节日可能不完整");
    }

    private List<HolidayDayDto> merge(List<HolidayDay> statutoryDays, List<LunarDay> lunarDays) {
        Map<String, String> festivals = new HashMap<>();
        String springFestival = null;
        for (LunarDay day : lunarDays) {
            if (day.lunarMonth() == 1 && day.lunarDay() == 1) {
                springFestival = day.date();
            }
            String festival = LUNAR_FESTIVALS.get(day.lunarMonth() + "-" + day.lunarDay());
            if (festival != null) {
                festivals.put(day.date(), festival);
            }
        }
        if (springFestival != null) {
            festivals.putIfAbsent(LocalDate.parse(springFestival).minusDays(1).toString(), "除夕");
        }

        List<HolidayDayDto> days = new ArrayList<>();
        Set<String> covered = new HashSet<>();
        for (HolidayDay day : statutoryDays) {
            covered.add(day.date());
            String traditional = festivals.get(day.date());
            if (traditional == null && NAMED_TRADITIONAL_FESTIVALS.contains(day.name())) {
                traditional = day.name();
            }
            days.add(new HolidayDayDto(day.date(), day.offDay() ? "HOLIDAY" : "WORKDAY",
                    day.name(), traditional, day.offDay(), !day.offDay()));
        }
        for (Map.Entry<String, String> festival : festivals.entrySet()) {
            if (covered.contains(festival.getKey())) {
                continue;
            }
            days.add(new HolidayDayDto(festival.getKey(), "TRADITIONAL_FESTIVAL",
                    festival.getValue(), festival.getValue(), false, false));
        }
        days.sort(Comparator.comparing(HolidayDayDto::date));
        return days;
    }

    private CacheRow findCache(int year) {
        List<CacheRow> rows = jdbcTemplate.query(
                "SELECT year, published, complete, source, source_url, payload, synced_at "
                        + "FROM holiday_year_cache WHERE year = ?",
                (rs, index) -> new CacheRow(
                        rs.getInt("year"),
                        rs.getBoolean("published"),
                        rs.getBoolean("complete"),
                        rs.getString("source"),
                        rs.getString("source_url"),
                        rs.getString("payload"),
                        rs.getObject("synced_at", OffsetDateTime.class)),
                year);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private boolean fresh(CacheRow row) {
        if (row.syncedAt() == null) {
            return false;
        }
        Duration ttl = row.complete() ? cacheTtl : PARTIAL_CACHE_TTL;
        return row.syncedAt().isAfter(OffsetDateTime.now(clock).minus(ttl));
    }

    private OffsetDateTime saveCache(Snapshot snapshot) {
        OffsetDateTime syncedAt = OffsetDateTime.now(clock);
        jdbcTemplate.update(
                "INSERT INTO holiday_year_cache (year, published, complete, source, source_url, payload, synced_at) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?) "
                        + "ON CONFLICT (year) DO UPDATE SET published = EXCLUDED.published, "
                        + "complete = EXCLUDED.complete, source = EXCLUDED.source, "
                        + "source_url = EXCLUDED.source_url, payload = EXCLUDED.payload, "
                        + "synced_at = EXCLUDED.synced_at",
                snapshot.year(), snapshot.published(), snapshot.complete(), SOURCE,
                snapshot.sourceUrl(), payload(snapshot.days()), syncedAt);
        return syncedAt;
    }

    private String payload(List<HolidayDayDto> days) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("days", days);
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (Exception exception) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR, "节假日缓存写入失败");
        }
    }

    private List<HolidayDayDto> parseDays(String payload) {
        List<HolidayDayDto> days = new ArrayList<>();
        try {
            JsonNode root = objectMapper.readTree(payload == null ? "" : payload);
            for (JsonNode node : root.path("days")) {
                days.add(new HolidayDayDto(
                        node.path("date").asText(""),
                        node.path("type").asText(""),
                        node.path("name").asText(""),
                        node.path("traditionalFestival").isNull()
                                ? null : node.path("traditionalFestival").asText(""),
                        node.path("offDay").asBoolean(false),
                        node.path("workday").asBoolean(false)));
            }
        } catch (Exception exception) {
            log.warn("节假日缓存内容解析失败：{}", exception.getClass().getSimpleName());
            return List.of();
        }
        return days;
    }

    private HolidayYearDto toDto(Snapshot snapshot, OffsetDateTime syncedAt, boolean fromCache) {
        boolean published = snapshot.published();
        return new HolidayYearDto(snapshot.year(), published ? "PUBLISHED" : "NOT_PUBLISHED",
                published, SOURCE, snapshot.sourceUrl(),
                SYNCED_AT_FORMAT.format(syncedAt), fromCache,
                snapshot.message(), snapshot.days());
    }

    private HolidayYearDto toDto(CacheRow row, boolean fromCache, String message) {
        return new HolidayYearDto(row.year(), row.published() ? "PUBLISHED" : "NOT_PUBLISHED",
                row.published(), row.source(), row.sourceUrl(),
                row.syncedAt() == null ? null : SYNCED_AT_FORMAT.format(row.syncedAt()),
                fromCache, message == null ? (row.published() ? null : "该年度放假安排尚未公布") : message,
                parseDays(row.payload()));
    }

    private record Snapshot(int year, boolean published, boolean complete, String sourceUrl,
            List<HolidayDayDto> days, String message) {
    }

    private record CacheRow(int year, boolean published, boolean complete, String source,
            String sourceUrl, String payload, OffsetDateTime syncedAt) {
    }
}
