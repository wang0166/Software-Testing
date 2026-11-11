package com.pandora.log.dto;

import java.util.List;

/**
 * 日历节假日数据。仅用于日历展示，不与个人事项或公司任务关联。
 * status 取值：PUBLISHED（已公布）、NOT_PUBLISHED（该年度放假安排尚未公布）、
 * UNAVAILABLE（外部数据源不可用且暂无缓存）。
 */
public final class CalendarHolidayDtos {

    private CalendarHolidayDtos() {
    }

    /**
     * type 取值：HOLIDAY（法定放假）、WORKDAY（调休补班）、TRADITIONAL_FESTIVAL（传统节日，非法定假日）。
     */
    public record HolidayDayDto(
            String date,
            String type,
            String name,
            String traditionalFestival,
            boolean offDay,
            boolean workday) {
    }

    public record HolidayYearDto(
            int year,
            String status,
            boolean published,
            String source,
            String sourceUrl,
            String syncedAt,
            boolean fromCache,
            String message,
            List<HolidayDayDto> days) {
    }
}
