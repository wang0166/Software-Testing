package com.pandora.log.service;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.AdminDtos.CompanyMatterRequest;
import com.pandora.log.dto.MobileDtos.CompanyItemDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class ContentService {

    private static final RowMapper<CompanyItemDto> MAPPER = (rs, index) -> new CompanyItemDto(
            rs.getLong("id"),
            rs.getString("title"),
            rs.getString("content"),
            rs.getInt("sort_order"),
            rs.getObject("updated_at", OffsetDateTime.class));

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;
    private final AuditService auditService;

    public ContentService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext,
            AuditService auditService) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
        this.auditService = auditService;
    }

    public PageResult<CompanyItemDto> matters(Integer page, Integer size) {
        return list("company_matters", page, size);
    }

    public PageResult<CompanyItemDto> importantTasks(Integer page, Integer size) {
        return list("company_important_tasks", page, size);
    }

    public Long createMatter(CompanyMatterRequest request) {
        CurrentUser currentUser = requireMatterManage();
        if (request == null) {
            throw validation("请求体不能为空");
        }
        String title = requireText(request.title(), "标题不能为空", 200);
        String content = requireText(request.content(), "内容不能为空", 0);
        int sortOrder = request.sortOrder() == null ? 0 : request.sortOrder();
        Long id = jdbcTemplate.queryForObject(
                "INSERT INTO company_matters (title, content, sort_order, updated_by) "
                        + "VALUES (?, ?, ?, ?) RETURNING id",
                Long.class, title, content, sortOrder, currentUser.id());
        auditService.record("创建公司事项", "COMPANY_MATTER", String.valueOf(id), title, "SUCCESS");
        return id;
    }

    public CompanyItemDto updateMatter(Long id, CompanyMatterRequest request) {
        CurrentUser currentUser = requireMatterManage();
        if (request == null) {
            throw validation("请求体不能为空");
        }
        String title = requireText(request.title(), "标题不能为空", 200);
        String content = requireText(request.content(), "内容不能为空", 0);
        int sortOrder = request.sortOrder() == null ? 0 : request.sortOrder();
        int updated = jdbcTemplate.update(
                "UPDATE company_matters SET title = ?, content = ?, sort_order = ?, updated_by = ?, "
                        + "updated_at = now() WHERE id = ?",
                title, content, sortOrder, currentUser.id(), id);
        if (updated == 0) {
            throw new BusinessException(ErrorCode.NOT_FOUND);
        }
        auditService.record("编辑公司事项", "COMPANY_MATTER", String.valueOf(id), title, "SUCCESS");
        return jdbcTemplate.query("SELECT id, title, content, sort_order, updated_at FROM company_matters WHERE id = ?",
                MAPPER, id).get(0);
    }

    private CurrentUser requireMatterManage() {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("company-matter:manage")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        return currentUser;
    }

    private static String requireText(String value, String message, int maxLength) {
        String clean = value == null ? "" : value.trim();
        if (clean.isEmpty()) {
            throw validation(message);
        }
        if (maxLength > 0 && clean.length() > maxLength) {
            throw validation("长度不能超过 " + maxLength + " 个字符");
        }
        return clean;
    }

    private static BusinessException validation(String message) {
        return new BusinessException(ErrorCode.VALIDATION_FAILED, message);
    }

    private PageResult<CompanyItemDto> list(String table, Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("content:read")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        PageQuery pageQuery = PageQuery.of(page, size);
        Long total = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + table, Long.class);
        List<CompanyItemDto> items = jdbcTemplate.query(
                "SELECT id, title, content, sort_order, updated_at FROM " + table
                        + " ORDER BY sort_order ASC, id ASC LIMIT ? OFFSET ?",
                MAPPER, pageQuery.size(), pageQuery.offset());
        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }
}
