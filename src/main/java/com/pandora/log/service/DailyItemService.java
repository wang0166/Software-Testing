package com.pandora.log.service;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.security.CurrentUserContext;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.MobileDtos.DailyItemDto;
import com.pandora.log.dto.MobileDtos.DailyItemRequest;

/**
 * 每日待办云端同步。移动端本地数据以用户为单位上传到这里，换设备后可拉回。
 */
@Service
public class DailyItemService {

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;

    public DailyItemService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
    }

    public List<DailyItemDto> list(LocalDate from, LocalDate to) {
        CurrentUser currentUser = currentUserContext.require();
        if (from != null && to != null && to.isBefore(from)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (from != null && to != null) {
            return jdbcTemplate.query(
                    "SELECT id, item_date, title, note, completed, updated_at FROM daily_items "
                            + "WHERE user_id = ? AND item_date BETWEEN ? AND ? "
                            + "ORDER BY item_date DESC, created_at DESC, id DESC",
                    (rs, index) -> toDto(rs), currentUser.id(), from, to);
        }
        if (from != null) {
            return jdbcTemplate.query(
                    "SELECT id, item_date, title, note, completed, updated_at FROM daily_items "
                            + "WHERE user_id = ? AND item_date >= ? "
                            + "ORDER BY item_date DESC, created_at DESC, id DESC",
                    (rs, index) -> toDto(rs), currentUser.id(), from);
        }
        if (to != null) {
            return jdbcTemplate.query(
                    "SELECT id, item_date, title, note, completed, updated_at FROM daily_items "
                            + "WHERE user_id = ? AND item_date <= ? "
                            + "ORDER BY item_date DESC, created_at DESC, id DESC",
                    (rs, index) -> toDto(rs), currentUser.id(), to);
        }
        return jdbcTemplate.query(
                "SELECT id, item_date, title, note, completed, updated_at FROM daily_items "
                        + "WHERE user_id = ? ORDER BY item_date DESC, created_at DESC, id DESC",
                (rs, index) -> toDto(rs), currentUser.id());
    }

    @Transactional
    public DailyItemDto create(DailyItemRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        LocalDate date = requireDate(request);
        String title = requireTitle(request);
        String note = note(request);
        boolean completed = request != null && Boolean.TRUE.equals(request.completed());
        Long id = jdbcTemplate.queryForObject(
                "INSERT INTO daily_items (user_id, item_date, title, note, completed) "
                        + "VALUES (?, ?, ?, ?, ?) RETURNING id",
                Long.class, currentUser.id(), date, title, note, completed);
        return require(id);
    }

    @Transactional
    public DailyItemDto update(Long id, DailyItemRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        DailyItemDto existing = require(id);
        if (!existing.id().equals(id) || !ownedBy(id, currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        LocalDate date = request == null || request.date() == null ? existing.date() : request.date();
        String title = request == null || request.title() == null ? existing.title() : requireTitle(request);
        String note = request == null || request.note() == null ? existing.note() : note(request);
        boolean completed = request == null || request.completed() == null
                ? existing.completed() : request.completed();
        jdbcTemplate.update(
                "UPDATE daily_items SET item_date = ?, title = ?, note = ?, completed = ?, "
                        + "updated_at = now() WHERE id = ? AND user_id = ?",
                date, title, note, completed, id, currentUser.id());
        return require(id);
    }

    @Transactional
    public void delete(Long id) {
        CurrentUser currentUser = currentUserContext.require();
        require(id);
        if (!ownedBy(id, currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        jdbcTemplate.update("DELETE FROM daily_items WHERE id = ? AND user_id = ?", id, currentUser.id());
    }

    private boolean ownedBy(Long id, Long userId) {
        Long count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM daily_items WHERE id = ? AND user_id = ?",
                Long.class, id, userId);
        return count != null && count > 0;
    }

    private DailyItemDto require(Long id) {
        List<DailyItemDto> rows = jdbcTemplate.query(
                "SELECT id, item_date, title, note, completed, updated_at FROM daily_items WHERE id = ?",
                (rs, index) -> toDto(rs), id);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_NOT_FOUND);
        }
        return rows.get(0);
    }

    private DailyItemDto toDto(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new DailyItemDto(
                rs.getLong("id"),
                rs.getObject("item_date", LocalDate.class),
                rs.getString("title"),
                rs.getString("note"),
                rs.getBoolean("completed"),
                rs.getObject("updated_at", OffsetDateTime.class));
    }

    private LocalDate requireDate(DailyItemRequest request) {
        if (request == null || request.date() == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return request.date();
    }

    private String requireTitle(DailyItemRequest request) {
        String title = request == null ? "" : trim(request.title());
        if (title.isEmpty() || title.length() > 200) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return title;
    }

    private String note(DailyItemRequest request) {
        String note = request == null ? "" : trim(request.note());
        if (note.length() > 1000) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return note;
    }

    private String trim(String value) {
        return value == null ? "" : value.trim();
    }
}
