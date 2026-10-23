package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.dto.AdminDtos.DepartmentCreateRequest;
import com.pandora.log.dto.AdminDtos.IdDto;
import com.pandora.log.dto.AdminDtos.OrgUnitDto;
import com.pandora.log.dto.AdminDtos.TeamCreateRequest;
import com.pandora.log.service.OrganizationService;

@RestController
@RequestMapping("/api")
public class OrganizationController {

    private final OrganizationService organizationService;

    public OrganizationController(OrganizationService organizationService) {
        this.organizationService = organizationService;
    }

    @GetMapping("/departments")
    public ApiResponse<List<OrgUnitDto>> departments() {
        return ApiResponse.success(organizationService.departments());
    }

    @PostMapping("/departments")
    public ApiResponse<IdDto> createDepartment(@RequestBody DepartmentCreateRequest request) {
        return ApiResponse.success(new IdDto(organizationService.createDepartment(
                request == null ? null : request.name(),
                request == null ? null : request.companyId())));
    }

    @DeleteMapping("/departments/{id}")
    public ApiResponse<Void> deleteDepartment(@PathVariable Long id) {
        organizationService.deleteDepartment(id);
        return ApiResponse.success();
    }

    @GetMapping("/teams")
    public ApiResponse<List<OrgUnitDto>> teams() {
        return ApiResponse.success(organizationService.teams());
    }

    @PostMapping("/teams")
    public ApiResponse<IdDto> createTeam(@RequestBody TeamCreateRequest request) {
        return ApiResponse.success(new IdDto(organizationService.createTeam(
                request == null ? null : request.name(),
                request == null ? null : request.departmentId())));
    }

    @DeleteMapping("/teams/{id}")
    public ApiResponse<Void> deleteTeam(@PathVariable Long id) {
        organizationService.deleteTeam(id);
        return ApiResponse.success();
    }
}
