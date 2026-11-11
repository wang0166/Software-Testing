package com.pandora.log.controller;

import java.util.List;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import com.pandora.log.common.*;
import com.pandora.log.dto.AdminDtos.*;
import com.pandora.log.service.*;

@RestController
@RequestMapping("/api")
public class AdminController {
    private final AdminUserService users;
    private final AdminOrganizationService org;
    private final AdminMatterService matters;
    private final AdminAuditService audits;
    public AdminController(AdminUserService users, AdminOrganizationService org, AdminMatterService matters, AdminAuditService audits) {
        this.users = users; this.org = org; this.matters = matters; this.audits = audits;
    }
    @GetMapping("/users")
    public ApiResponse<PageResult<UserDto>> users(@RequestParam(required=false) String keyword,
            @RequestParam(required=false) String role, @RequestParam(required=false) String status,
            @RequestParam(required=false) Long departmentId, @RequestParam(required=false) Long teamId,
            @RequestParam(required=false) Integer page, @RequestParam(required=false) Integer size) {
        return ApiResponse.success(users.list(keyword,role,status,departmentId,teamId,page,size));
    }
    @GetMapping("/users/{id}") public ApiResponse<UserDto> user(@PathVariable Long id) { return ApiResponse.success(users.get(id)); }
    @PostMapping("/users") public ApiResponse<IdDto> createUser(@Valid @RequestBody CreateUserRequest r) { return ApiResponse.success(users.create(r)); }
    @PutMapping("/users/{id}") public ApiResponse<Void> updateUser(@PathVariable Long id, @Valid @RequestBody UpdateUserRequest r) { users.update(id,r); return ApiResponse.success(); }
    @PatchMapping("/users/{id}/status") public ApiResponse<Void> status(@PathVariable Long id, @Valid @RequestBody UserStatusRequest r) { users.status(id,r); return ApiResponse.success(); }
    @PutMapping("/users/{id}/password") public ApiResponse<Void> password(@PathVariable Long id, @Valid @RequestBody PasswordRequest r) { users.password(id,r); return ApiResponse.success(); }
    @GetMapping("/companies") public ApiResponse<List<CompanyDto>> companies() { return ApiResponse.success(org.companies()); }
    @GetMapping("/companies/{id}") public ApiResponse<CompanyDto> company(@PathVariable Long id) { return ApiResponse.success(org.company(id)); }
    @PutMapping("/companies/{id}") public ApiResponse<Void> company(@PathVariable Long id, @Valid @RequestBody CompanyRequest r) { org.updateCompany(id,r); return ApiResponse.success(); }
    @GetMapping("/departments") public ApiResponse<List<DepartmentDto>> departments() { return ApiResponse.success(org.departments()); }
    @GetMapping("/departments/{id}") public ApiResponse<DepartmentDto> department(@PathVariable Long id) { return ApiResponse.success(org.department(id)); }
    @PostMapping("/departments") public ApiResponse<IdDto> department(@Valid @RequestBody DepartmentRequest r) { return ApiResponse.success(org.createDepartment(r)); }
    @PutMapping("/departments/{id}") public ApiResponse<Void> department(@PathVariable Long id, @Valid @RequestBody DepartmentRequest r) { org.updateDepartment(id,r); return ApiResponse.success(); }
    @DeleteMapping("/departments/{id}") public ApiResponse<Void> deleteDepartment(@PathVariable Long id) { org.deleteDepartment(id); return ApiResponse.success(); }
    @GetMapping("/teams") public ApiResponse<List<TeamDto>> teams() { return ApiResponse.success(org.teams()); }
    @GetMapping("/teams/{id}") public ApiResponse<TeamDto> team(@PathVariable Long id) { return ApiResponse.success(org.team(id)); }
    @PostMapping("/teams") public ApiResponse<IdDto> team(@Valid @RequestBody TeamRequest r) { return ApiResponse.success(org.createTeam(r)); }
    @PutMapping("/teams/{id}") public ApiResponse<Void> team(@PathVariable Long id, @Valid @RequestBody TeamRequest r) { org.updateTeam(id,r); return ApiResponse.success(); }
    @DeleteMapping("/teams/{id}") public ApiResponse<Void> deleteTeam(@PathVariable Long id) { org.deleteTeam(id); return ApiResponse.success(); }
    @PostMapping("/company-matters") public ApiResponse<IdDto> matter(@Valid @RequestBody MatterRequest r) { return ApiResponse.success(matters.create(r)); }
    @PutMapping("/company-matters/{id}") public ApiResponse<Void> matter(@PathVariable Long id, @Valid @RequestBody MatterRequest r) { matters.update(id,r); return ApiResponse.success(); }
    @GetMapping("/audits")
    public ApiResponse<PageResult<AuditDto>> audits(@RequestParam(required=false) String actor,
            @RequestParam(required=false) String action, @RequestParam(required=false) String from,
            @RequestParam(required=false) String to, @RequestParam(required=false) Integer page,
            @RequestParam(required=false) Integer size) { return ApiResponse.success(audits.list(actor,action,from,to,page,size)); }
}
