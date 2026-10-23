package com.pandora.log.service;

import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.AdminDtos.OrgUnitDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class OrganizationService {

    private static final RowMapper<OrgUnitDto> DEPARTMENT_MAPPER = (rs, index) -> new OrgUnitDto(
            rs.getLong("id"), rs.getString("name"), rs.getLong("company_id"));

    private static final RowMapper<OrgUnitDto> TEAM_MAPPER = (rs, index) -> new OrgUnitDto(
            rs.getLong("id"), rs.getString("name"), rs.getLong("department_id"));

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;
    private final AuditService auditService;

    public OrganizationService(JdbcTemplate jdbcTemplate,
            CurrentUserContext currentUserContext,
            AuditService auditService) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
        this.auditService = auditService;
    }

    public List<OrgUnitDto> departments() {
        requireManage();
        return jdbcTemplate.query("SELECT id, name, company_id FROM departments ORDER BY id", DEPARTMENT_MAPPER);
    }

    public List<OrgUnitDto> teams() {
        requireManage();
        return jdbcTemplate.query("SELECT id, name, department_id FROM teams ORDER BY id", TEAM_MAPPER);
    }

    public Long createDepartment(String name, Long companyId) {
        requireManage();
        String cleanName = requireName(name);
        Long targetCompanyId = companyId != null ? companyId : firstCompanyId();
        requireExists("SELECT COUNT(*) FROM companies WHERE id = ?", targetCompanyId, "公司不存在");
        Long id;
        try {
            id = jdbcTemplate.queryForObject(
                    "INSERT INTO departments (name, company_id) VALUES (?, ?) RETURNING id",
                    Long.class, cleanName, targetCompanyId);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "该公司下已存在同名部门");
        }
        auditService.record("创建部门", "DEPARTMENT", String.valueOf(id), cleanName, "SUCCESS");
        return id;
    }

    public Long createTeam(String name, Long departmentId) {
        requireManage();
        String cleanName = requireName(name);
        if (departmentId == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "请选择所属部门");
        }
        requireExists("SELECT COUNT(*) FROM departments WHERE id = ?", departmentId, "部门不存在");
        Long id;
        try {
            id = jdbcTemplate.queryForObject(
                    "INSERT INTO teams (name, department_id) VALUES (?, ?) RETURNING id",
                    Long.class, cleanName, departmentId);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "该部门下已存在同名团队");
        }
        auditService.record("创建团队", "TEAM", String.valueOf(id), cleanName, "SUCCESS");
        return id;
    }

    public void deleteDepartment(Long id) {
        requireManage();
        String name = currentName("SELECT name FROM departments WHERE id = ?", id, "部门不存在");
        Long members = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users WHERE department_id = ?", Long.class, id);
        Long children = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM teams WHERE department_id = ?", Long.class, id);
        if ((members != null && members > 0) || (children != null && children > 0)) {
            auditService.record("删除部门", "DEPARTMENT", String.valueOf(id), name, "拒绝：仍有关联成员或下级");
            throw new BusinessException(ErrorCode.ORG_IN_USE);
        }
        try {
            jdbcTemplate.update("DELETE FROM departments WHERE id = ?", id);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.ORG_IN_USE);
        }
        auditService.record("删除部门", "DEPARTMENT", String.valueOf(id), name, "SUCCESS");
    }

    public void deleteTeam(Long id) {
        requireManage();
        String name = currentName("SELECT name FROM teams WHERE id = ?", id, "团队不存在");
        Long members = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users WHERE team_id = ?", Long.class, id);
        if (members != null && members > 0) {
            auditService.record("删除团队", "TEAM", String.valueOf(id), name, "拒绝：仍有成员");
            throw new BusinessException(ErrorCode.ORG_IN_USE);
        }
        try {
            jdbcTemplate.update("DELETE FROM teams WHERE id = ?", id);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.ORG_IN_USE);
        }
        auditService.record("删除团队", "TEAM", String.valueOf(id), name, "SUCCESS");
    }

    private void requireManage() {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("org:manage")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }

    private static String requireName(String name) {
        String cleanName = name == null ? "" : name.trim();
        if (cleanName.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "名称不能为空");
        }
        if (cleanName.length() > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "名称不能超过 100 个字符");
        }
        return cleanName;
    }

    private void requireExists(String sql, Long id, String message) {
        Long count = jdbcTemplate.queryForObject(sql, Long.class, id);
        if (count == null || count == 0) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, message);
        }
    }

    private String currentName(String sql, Long id, String message) {
        List<String> rows = jdbcTemplate.queryForList(sql, String.class, id);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.NOT_FOUND, message);
        }
        return rows.get(0);
    }

    private Long firstCompanyId() {
        List<Long> rows = jdbcTemplate.queryForList("SELECT id FROM companies ORDER BY id LIMIT 1", Long.class);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "请先创建公司");
        }
        return rows.get(0);
    }
}
