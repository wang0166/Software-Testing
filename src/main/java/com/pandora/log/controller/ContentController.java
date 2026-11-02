package com.pandora.log.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.CalendarDto;
import com.pandora.log.dto.MobileDtos.CompanyItemDto;
import com.pandora.log.dto.AdminDtos.MatterDto;
import com.pandora.log.service.AdminMatterService;
import com.pandora.log.dto.MobileDtos.TaskMapDto;
import com.pandora.log.service.CalendarService;
import com.pandora.log.service.ContentService;

@RestController
@RequestMapping("/api")
public class ContentController {

    private final ContentService contentService;
    private final CalendarService calendarService;
    private final AdminMatterService matterService;

    public ContentController(ContentService contentService, CalendarService calendarService, AdminMatterService matterService) {
        this.contentService = contentService;
        this.calendarService = calendarService;
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

    @GetMapping("/task-map")
    public ApiResponse<TaskMapDto> taskMap(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(calendarService.taskMap(page, size));
    }
}
