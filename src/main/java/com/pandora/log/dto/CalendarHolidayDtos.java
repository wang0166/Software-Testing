package com.pandora.log.dto;

import java.util.List;

/**
 * 日历节假日数据。仅用于日历展示，不与个人事项或公司任务关联。
 * 字段与移动端 HolidayYearData 对齐：dataStatus 取值 published（已公布）、
 * partial（放假已公布但传统节日不完整）、not_published（该年度尚未公布）、
 * unavailable（数据源不可用且暂无缓存）。
 */
public final class CalendarHolidayDtos {

    private CalendarHolidayDtos() {
    }

    /**
     * dayType 取值：holiday（法定放假）、makeup_workday（调休补班）、
     * normal（普通日，此处用于仅作为传统节日展示的日期）。
     */
    public record HolidayDayDto(
            String date,
            String dayType,
            String holidayName,
            List<String> festivals,
            String sourceUrl) {
    }

    public record HolidayYearDto(
            int year,
            String region,
            String timezone,
            String dataStatus,
            String lastSyncedAt,
            String source,
            String sourceUrl,
            boolean fromCache,
            String message,
            List<HolidayDayDto> days) {
    }
}
