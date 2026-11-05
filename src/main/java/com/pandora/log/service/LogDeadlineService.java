package com.pandora.log.service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.time.ZoneId;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 按日志所属日期结算；服务重启后也补处理历史草稿，重复执行不会重复提交。 */
@Service
public class LogDeadlineService {
    private static final ZoneId ZONE = ZoneId.of("Asia/Shanghai");
    private final JdbcTemplate jdbc;
    private final SystemConfigService config;
    private final Clock clock;

    public LogDeadlineService(JdbcTemplate jdbc, SystemConfigService config, Clock clock) {
        this.jdbc = jdbc; this.config = config; this.clock = clock;
    }

    @Transactional
    public int settle() {
        ZonedDateTime now = ZonedDateTime.now(clock).withZoneSameInstant(ZONE);
        LocalDate date = now.toLocalDate();
        boolean reached = !now.toLocalTime().isBefore(config.logDeadline());
        // submitted_at 记录实际处理时刻；不伪造为系统停机期间的截止时刻。
        return jdbc.update("UPDATE work_logs SET status='SUBMITTED',submitted_at=?,updated_at=? "
                + "WHERE status='DRAFT' AND (log_date<? OR (log_date=? AND ?))",
                now.toOffsetDateTime(), now.toOffsetDateTime(), date, date, reached);
    }
}
