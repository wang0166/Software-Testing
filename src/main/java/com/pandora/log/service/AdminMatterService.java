package com.pandora.log.service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.pandora.log.common.*;
import com.pandora.log.dto.AdminDtos.*;
import com.pandora.log.security.CurrentUserContext;

@Service
public class AdminMatterService {
    private static final RowMapper<MatterDto> MAPPER = (rs, n) -> new MatterDto(rs.getLong("id"),
            rs.getString("title"), rs.getString("content"), rs.getInt("sort_order"),
            shanghai(rs.getObject("start_date", OffsetDateTime.class)),
            shanghai(rs.getObject("deadline", OffsetDateTime.class)),
            shanghai(rs.getObject("updated_at", OffsetDateTime.class)));
    private final JdbcTemplate jdbc;
    private final AdminSupport support;
    private final CurrentUserContext context;

    public AdminMatterService(JdbcTemplate jdbc, AdminSupport support, CurrentUserContext context) {
        this.jdbc = jdbc; this.support = support; this.context = context;
    }
    public PageResult<MatterDto> list(Integer page, Integer size) {
        if (!context.require().hasPermission("content:read")) throw new BusinessException(ErrorCode.FORBIDDEN);
        PageQuery pq = PageQuery.of(page, size);
        return new PageResult<>(jdbc.queryForObject("SELECT count(*) FROM company_matters", Long.class), pq.page(), pq.size(),
                jdbc.query("SELECT id,title,content,sort_order,start_date,deadline,updated_at FROM company_matters "
                        + "ORDER BY sort_order,id LIMIT ? OFFSET ?", MAPPER, pq.size(), pq.offset()));
    }
    @Transactional
    public IdDto create(MatterRequest request) {
        CurrentUser user = support.require("company-matter:manage"); support.lock(); validate(request);
        Long id = jdbc.queryForObject("INSERT INTO company_matters(title,content,sort_order,start_date,deadline,updated_by) "
                + "VALUES (?,?,?,?,?,?) RETURNING id", Long.class, request.title().trim(), request.content().trim(),
                request.sortOrder(), request.startDate(), request.deadline(), user.id());
        support.audit("创建公司事项", "COMPANY_MATTER", id); return new IdDto(id);
    }
    @Transactional
    public void update(Long id, MatterRequest request) {
        CurrentUser user = support.require("company-matter:manage"); support.lock(); validate(request);
        int changed = jdbc.update("UPDATE company_matters SET title=?,content=?,sort_order=?,start_date=?,deadline=?,"
                + "updated_by=?,updated_at=now() WHERE id=?", request.title().trim(), request.content().trim(),
                request.sortOrder(), request.startDate(), request.deadline(), user.id(), id);
        if (changed == 0) throw new BusinessException(ErrorCode.NOT_FOUND);
        support.audit("编辑公司事项", "COMPANY_MATTER", id);
    }
    private static void validate(MatterRequest r) {
        if (!hour(r.startDate()) || !hour(r.deadline())) AdminSupport.invalid("开始与截止时间必须为北京时间 +08:00 整点");
        if (r.deadline().isBefore(r.startDate())) AdminSupport.invalid("截止时间不得早于开始时间");
    }
    private static boolean hour(OffsetDateTime time) {
        return time != null && time.getOffset().equals(ZoneOffset.ofHours(8))
                && time.getMinute() == 0 && time.getSecond() == 0 && time.getNano() == 0;
    }
    private static OffsetDateTime shanghai(OffsetDateTime time) {
        return time == null ? null : time.withOffsetSameInstant(ZoneOffset.ofHours(8));
    }
}
