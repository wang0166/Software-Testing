package com.pandora.log.service;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Set;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.PersonalTaskDto;
import com.pandora.log.dto.MobileDtos.PersonalTaskRequest;
import com.pandora.log.security.CurrentUserContext;

@Service
public class PersonalTaskService {

    private static final Set<String> STATUSES = Set.of("NOT_STARTED", "IN_PROGRESS", "COMPLETED");

    private static final RowMapper<PersonalTaskDto> MAPPER = (rs, index) -> new PersonalTaskDto(
            rs.getLong("id"),
            rs.getLong("owner_id"),
            rs.getString("name"),
            rs.getString("details"),
            rs.getString("status"),
            rs.getObject("created_at", OffsetDateTime.class),
            rs.getObject("updated_at", OffsetDateTime.class));

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;

    public PersonalTaskService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
    }

    public PageResult<PersonalTaskDto> list(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        requireSelfPermission(currentUser);
        PageQuery pageQuery = PageQuery.of(page, size);

        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM personal_tasks WHERE owner_id = ?", Long.class, currentUser.id());
        List<PersonalTaskDto> items = jdbcTemplate.query(
                "SELECT id, owner_id, name, details, status, created_at, updated_at FROM personal_tasks "
                        + "WHERE owner_id = ? ORDER BY updated_at DESC, id DESC LIMIT ? OFFSET ?",
                MAPPER, currentUser.id(), pageQuery.size(), pageQuery.offset());

        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    @Transactional
    public PersonalTaskDto create(PersonalTaskRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        requireSelfPermission(currentUser);
        String name = requireText(request.name());
        String details = requireText(request.details());
        String status = parseStatus(request.status());

        Long id = jdbcTemplate.queryForObject(
                "INSERT INTO personal_tasks (owner_id, name, details, status) VALUES (?, ?, ?, ?) RETURNING id",
                Long.class, currentUser.id(), name, details, status);
        return findById(id);
    }

    @Transactional
    public PersonalTaskDto update(Long id, PersonalTaskRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        requireSelfPermission(currentUser);
        PersonalTaskDto existing = findById(id);
        if (existing == null) {
            throw new BusinessException(ErrorCode.TASK_NOT_FOUND);
        }
        if (!existing.ownerId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        String name = requireText(request.name());
        String details = requireText(request.details());
        String status = parseStatus(request.status());

        jdbcTemplate.update(
                "UPDATE personal_tasks SET name = ?, details = ?, status = ?, updated_at = now() WHERE id = ?",
                name, details, status, id);
        return findById(id);
    }

    private PersonalTaskDto findById(Long id) {
        List<PersonalTaskDto> rows = jdbcTemplate.query(
                "SELECT id, owner_id, name, details, status, created_at, updated_at FROM personal_tasks "
                        + "WHERE id = ?",
                MAPPER, id);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private void requireSelfPermission(CurrentUser currentUser) {
        if (!currentUser.hasPermission("task:self")) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }
    }

    private String requireText(String value) {
        String text = value == null ? "" : value.trim();
        if (text.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return text;
    }

    private String parseStatus(String value) {
        if (value == null || value.isBlank()) {
            return "NOT_STARTED";
        }
        String status = value.trim().toUpperCase();
        if (!STATUSES.contains(status)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return status;
    }
}
