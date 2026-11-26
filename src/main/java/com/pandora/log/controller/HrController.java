package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.CrmDtos.ActivityDto;
import com.pandora.log.dto.CrmDtos.CreateEmployeeArchiveRequest;
import com.pandora.log.dto.CrmDtos.EmployeeArchiveDto;
import com.pandora.log.service.HrService;

@RestController
@RequestMapping("/api/hr")
public class HrController {
    private final HrService service;

    public HrController(HrService service) {
        this.service = service;
    }

    @GetMapping("/employees")
    public ApiResponse<PageResult<EmployeeArchiveDto>> employees(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) String role,
            @RequestParam(required = false) Integer contractExpiringDays,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(service.employees(keyword, departmentId, role,
                contractExpiringDays, page, size));
    }

    @PostMapping("/employees")
    public ApiResponse<EmployeeArchiveDto> createEmployee(
            @RequestBody CreateEmployeeArchiveRequest request) {
        return ApiResponse.success(service.createEmployee(request));
    }

    @GetMapping("/employees/{id}/activities")
    public ApiResponse<List<ActivityDto>> activities(@PathVariable Long id) {
        return ApiResponse.success(service.employeeActivities(id));
    }
}
