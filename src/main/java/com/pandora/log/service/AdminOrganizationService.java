package com.pandora.log.service;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.pandora.log.common.*;
import com.pandora.log.dto.AdminDtos.*;

@Service
public class AdminOrganizationService {
    private static final RowMapper<CompanyDto> COMPANY = (rs, n) -> new CompanyDto(rs.getLong("id"),
            rs.getString("name"), rs.getObject("founder_id", Long.class));
    private static final RowMapper<DepartmentDto> DEPARTMENT = (rs, n) -> new DepartmentDto(rs.getLong("id"),
            rs.getString("name"), rs.getString("description"), rs.getLong("company_id"), rs.getObject("manager_id", Long.class));
    private static final RowMapper<TeamDto> TEAM = (rs, n) -> new TeamDto(rs.getLong("id"),
            rs.getString("name"), rs.getString("description"), rs.getLong("department_id"), rs.getObject("leader_id", Long.class));
    private final JdbcTemplate jdbc;
    private final AdminSupport support;
    private final AdminUserService users;

    public AdminOrganizationService(JdbcTemplate jdbc, AdminSupport support, AdminUserService users) {
        this.jdbc = jdbc; this.support = support; this.users = users;
    }

    public List<CompanyDto> companies() {
        support.require("org:manage");
        return jdbc.query("SELECT id,name,founder_id FROM companies ORDER BY id", COMPANY);
    }
    public CompanyDto company(Long id) {
        support.require("org:manage");
        return first(jdbc.query("SELECT id,name,founder_id FROM companies WHERE id=?", COMPANY, id));
    }
    @Transactional
    public void updateCompany(Long id, CompanyRequest request) {
        support.require("org:manage"); support.lock(); company(id);
        jdbc.update("UPDATE companies SET name=? WHERE id=?", request.name().trim(), id);
        support.audit("编辑公司", "COMPANY", id);
    }
    public List<DepartmentDto> departments() {
        support.require("org:manage");
        return jdbc.query("SELECT id,name,description,company_id,manager_id FROM departments ORDER BY id", DEPARTMENT);
    }
    public DepartmentDto department(Long id) {
        support.require("org:manage");
        return first(jdbc.query("SELECT id,name,description,company_id,manager_id FROM departments WHERE id=?", DEPARTMENT, id));
    }
    @Transactional
    public IdDto createDepartment(DepartmentRequest request) {
        support.require("org:manage"); support.lock(); company(request.companyId());
        duplicateDepartment(request, -1L);
        Long id = jdbc.queryForObject("INSERT INTO departments(name,company_id,description) VALUES (?,?,?) RETURNING id",
                Long.class, request.name().trim(), request.companyId(), request.description());
        support.audit("创建部门", "DEPARTMENT", id); return new IdDto(id);
    }
    @Transactional
    public void updateDepartment(Long id, DepartmentRequest request) {
        support.require("org:manage"); support.lock();
        DepartmentDto old = department(id); company(request.companyId());
        if (!old.companyId().equals(request.companyId()) && departmentInUse(id)) {
            throw new BusinessException(ErrorCode.ORGANIZATION_IN_USE);
        }
        duplicateDepartment(request, id);
        jdbc.update("UPDATE departments SET name=?,company_id=?,description=? WHERE id=?",
                request.name().trim(), request.companyId(), request.description(), id);
        support.audit("编辑部门", "DEPARTMENT", id);
    }
    @Transactional
    public void deleteDepartment(Long id) {
        support.require("org:manage"); support.lock(); department(id);
        if (departmentInUse(id)) throw new BusinessException(ErrorCode.ORGANIZATION_IN_USE);
        jdbc.update("DELETE FROM departments WHERE id=?", id);
        support.audit("删除部门", "DEPARTMENT", id);
    }
    public List<TeamDto> teams() {
        support.require("org:manage");
        return jdbc.query("SELECT id,name,description,department_id,leader_id FROM teams ORDER BY id", TEAM);
    }
    public TeamDto team(Long id) {
        support.require("org:manage");
        return first(jdbc.query("SELECT id,name,description,department_id,leader_id FROM teams WHERE id=?", TEAM, id));
    }
    @Transactional
    public IdDto createTeam(TeamRequest request) {
        support.require("org:manage"); support.lock(); department(request.departmentId());
        if (request.leaderId() != null) AdminSupport.invalid("请先创建团队，再通过用户归属或团队编辑指定负责人");
        duplicateTeam(request, -1L);
        Long id = jdbc.queryForObject("INSERT INTO teams(name,department_id,description) VALUES (?,?,?) RETURNING id",
                Long.class, request.name().trim(), request.departmentId(), request.description());
        support.audit("创建团队", "TEAM", id); return new IdDto(id);
    }
    @Transactional
    public void updateTeam(Long id, TeamRequest request) {
        support.require("org:manage"); support.lock();
        TeamDto old = team(id); department(request.departmentId());
        if (!old.departmentId().equals(request.departmentId()) && teamInUse(id)) {
            throw new BusinessException(ErrorCode.ORGANIZATION_IN_USE);
        }
        duplicateTeam(request, id);
        if (request.leaderId() != null && !request.leaderId().equals(old.leaderId())) {
            UserDto next = users.get(request.leaderId());
            if (!id.equals(next.teamId()) || !request.departmentId().equals(next.departmentId())
                    || !(next.role().equals("EMPLOYEE") || next.role().equals("TEAM_LEADER"))) {
                AdminSupport.invalid("新负责人必须是本团队的员工");
            }
            if (old.leaderId() != null) {
                UserDto previous = users.get(old.leaderId());
                users.update(previous.id(), new UpdateUserRequest(previous.realName(), "EMPLOYEE", previous.departmentId(), previous.teamId()));
            }
            users.update(next.id(), new UpdateUserRequest(next.realName(), "TEAM_LEADER", next.departmentId(), next.teamId()));
        }
        jdbc.update("UPDATE teams SET name=?,department_id=?,description=? WHERE id=?",
                request.name().trim(), request.departmentId(), request.description(), id);
        support.audit("编辑团队", "TEAM", id);
    }
    @Transactional
    public void deleteTeam(Long id) {
        support.require("org:manage"); support.lock(); team(id);
        if (teamInUse(id)) throw new BusinessException(ErrorCode.ORGANIZATION_IN_USE);
        jdbc.update("DELETE FROM teams WHERE id=?", id);
        support.audit("删除团队", "TEAM", id);
    }
    private boolean departmentInUse(Long id) {
        return support.exists("SELECT EXISTS(SELECT 1 FROM users WHERE department_id=?) OR EXISTS(SELECT 1 FROM teams WHERE department_id=?)", id, id);
    }
    private boolean teamInUse(Long id) {
        return support.exists("SELECT EXISTS(SELECT 1 FROM users WHERE team_id=?)", id);
    }
    private void duplicateDepartment(DepartmentRequest r, Long id) {
        if (support.exists("SELECT EXISTS(SELECT 1 FROM departments WHERE company_id=? AND name=? AND id<>?)", r.companyId(), r.name().trim(), id)) {
            throw new BusinessException(ErrorCode.ORGANIZATION_NAME_EXISTS);
        }
    }
    private void duplicateTeam(TeamRequest r, Long id) {
        if (support.exists("SELECT EXISTS(SELECT 1 FROM teams WHERE department_id=? AND name=? AND id<>?)", r.departmentId(), r.name().trim(), id)) {
            throw new BusinessException(ErrorCode.ORGANIZATION_NAME_EXISTS);
        }
    }
    private static <T> T first(List<T> items) {
        return items.stream().findFirst().orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
    }
}
