package com.pandora.log.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.AdminDtos.MatterDto;
import com.pandora.log.dto.CalendarHolidayDtos.HolidayYearDto;
import com.pandora.log.dto.MobileDtos.CalendarDto;
import com.pandora.log.dto.MobileDtos.CompanyItemDto;
import com.pandora.log.dto.MobileDtos.TaskMapDto;
import com.pandora.log.service.AdminMatterService;
import com.pandora.log.service.CalendarService;
import com.pandora.log.service.ContentService;
import com.pandora.log.service.HolidayService;

@RestController
@RequestMapping("/api")
public class ContentController {

    private final ContentService contentService;
    private final CalendarService calendarService;
    private final HolidayService holidayService;
    private final AdminMatterService matterService;

    public ContentController(ContentService contentService, CalendarService calendarService,
            HolidayService holidayService, AdminMatterService matterService) {
        this.contentService = contentService;
        this.calendarService = calendarService;
        this.holidayService = holidayService;
        this.matterService = matterService;
    }

    @GetMapping("/company-matters")
    public ApiResponse<PageResult<MatterDto>> matters(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(matterService.list(page, size));
    }

    @GetMapping("/company-important-tasks")
    public ApiResponse<PageResult<CompanyItemDto>> importantTasks(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(contentService.importantTasks(page, size));
    }

    @GetMapping("/calendar")
    public ApiResponse<CalendarDto> calendar(@RequestParam String from, @RequestParam String to) {
        return ApiResponse.success(calendarService.calendar(from, to));
    }

    /** 日历节假日：法定放假、调休补班与传统节日，仅用于日历展示。 */
    @GetMapping("/calendar/holidays")
    public ApiResponse<HolidayYearDto> holidays(@RequestParam int year) {
        return ApiResponse.success(holidayService.holidays(year));
    }

    @GetMapping("/task-map")
    public ApiResponse<TaskMapDto> taskMap(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(calendarService.taskMap(page, size));
    }
}
