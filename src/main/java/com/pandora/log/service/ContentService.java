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

    public ContentService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
    }

    public PageResult<CompanyItemDto> importantTasks(Integer page, Integer size) {
        return list("company_important_tasks", page, size);
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
