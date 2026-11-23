package com.pandora.log.service;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Set;

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

    private static final long DEFAULT_COLOR = 4294957543L;
    private static final Set<Long> ALLOWED_COLORS = Set.of(
            4294957543L, 4294959826L, 4294963398L,
            4292408293L, 4292406271L, 4293517055L);

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
                    "SELECT id, item_date, title, note, completed, color_value, start_time, end_time, sort_order, updated_at FROM daily_items "
                            + "WHERE user_id = ? AND item_date BETWEEN ? AND ? "
                            + "ORDER BY item_date DESC, sort_order, id",
                    (rs, index) -> toDto(rs), currentUser.id(), from, to);
        }
        if (from != null) {
            return jdbcTemplate.query(
                    "SELECT id, item_date, title, note, completed, color_value, start_time, end_time, sort_order, updated_at FROM daily_items "
                            + "WHERE user_id = ? AND item_date >= ? "
                            + "ORDER BY item_date DESC, sort_order, id",
                    (rs, index) -> toDto(rs), currentUser.id(), from);
        }
        if (to != null) {
            return jdbcTemplate.query(
                    "SELECT id, item_date, title, note, completed, color_value, start_time, end_time, sort_order, updated_at FROM daily_items "
                            + "WHERE user_id = ? AND item_date <= ? "
                            + "ORDER BY item_date DESC, sort_order, id",
                    (rs, index) -> toDto(rs), currentUser.id(), to);
        }
        return jdbcTemplate.query(
                "SELECT id, item_date, title, note, completed, color_value, start_time, end_time, sort_order, updated_at FROM daily_items "
                        + "WHERE user_id = ? ORDER BY item_date DESC, sort_order, id",
                (rs, index) -> toDto(rs), currentUser.id());
    }

    @Transactional
    public DailyItemDto create(DailyItemRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        LocalDate date = requireDate(request);
        String title = requireTitle(request);
        String note = note(request);
        boolean completed = request != null && Boolean.TRUE.equals(request.completed());
        long colorValue = colorValue(request == null ? null : request.colorValue(), DEFAULT_COLOR);
        TimeRange time = timeRange(request == null ? null : request.startTime(),
                request == null ? null : request.endTime(), null, null);
        int sortOrder = sortOrder(request == null ? null : request.sortOrder(), 0);
        Long id = jdbcTemplate.queryForObject(
                "INSERT INTO daily_items (user_id, item_date, title, note, completed, color_value, start_time, end_time, sort_order) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                Long.class, currentUser.id(), date, title, note, completed,
                colorValue, time.start(), time.end(), sortOrder);
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
        long colorValue = colorValue(request == null ? null : request.colorValue(), existing.colorValue());
        TimeRange time = timeRange(request == null ? null : request.startTime(),
                request == null ? null : request.endTime(),
                parseStoredTime(existing.startTime()), parseStoredTime(existing.endTime()));
        int sortOrder = sortOrder(request == null ? null : request.sortOrder(), existing.sortOrder());
        jdbcTemplate.update(
                "UPDATE daily_items SET item_date = ?, title = ?, note = ?, completed = ?, "
                        + "color_value = ?, start_time = ?, end_time = ?, sort_order = ?, "
                        + "updated_at = now() WHERE id = ? AND user_id = ?",
                date, title, note, completed, colorValue, time.start(), time.end(), sortOrder,
                id, currentUser.id());
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
                "SELECT id, item_date, title, note, completed, color_value, start_time, end_time, sort_order, updated_at "
                        + "FROM daily_items WHERE id = ?",
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
                rs.getLong("color_value"),
                formatTime(rs.getObject("start_time", LocalTime.class)),
                formatTime(rs.getObject("end_time", LocalTime.class)),
                rs.getInt("sort_order"),
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

    private long colorValue(Long requested, long fallback) {
        long value = requested == null ? fallback : requested;
        if (!ALLOWED_COLORS.contains(value)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return value;
    }

    private int sortOrder(Integer requested, int fallback) {
        int value = requested == null ? fallback : requested;
        if (value < 0 || value > 10_000) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return value;
    }

    private TimeRange timeRange(String requestedStart, String requestedEnd,
            LocalTime fallbackStart, LocalTime fallbackEnd) {
        if (requestedStart == null && requestedEnd == null) {
            return new TimeRange(fallbackStart, fallbackEnd);
        }
        String startText = trim(requestedStart);
        String endText = trim(requestedEnd);
        if (startText.isEmpty() && endText.isEmpty()) {
            return new TimeRange(null, null);
        }
        try {
            LocalTime start = LocalTime.parse(startText);
            LocalTime end = LocalTime.parse(endText);
            if (!end.isAfter(start)) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            }
            return new TimeRange(start, end);
        } catch (java.time.format.DateTimeParseException ex) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }

    private LocalTime parseStoredTime(String value) {
        return value == null ? null : LocalTime.parse(value);
    }

    private String formatTime(LocalTime value) {
        return value == null ? null : String.format("%02d:%02d", value.getHour(), value.getMinute());
    }

    private record TimeRange(LocalTime start, LocalTime end) {
    }
}
