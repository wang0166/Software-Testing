package com.pandora.log.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import com.pandora.log.common.*;
import com.pandora.log.security.CurrentUserContext;

@Component
public class AdminSupport {
    private final JdbcTemplate jdbc;
    private final CurrentUserContext context;

    public AdminSupport(JdbcTemplate jdbc, CurrentUserContext context) {
        this.jdbc = jdbc;
        this.context = context;
    }

    public CurrentUser require(String permission) {
        CurrentUser user = context.require();
        if (!"ADMIN".equals(user.roleCode()) || !user.hasPermission(permission)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        return user;
    }

    public void lock() {
        // 管理写入共用事务级锁，避免并发分配负责人或检查最后一个管理员时产生竞态。
        // 只读查询及移动端业务不获取此锁；调用方必须处于事务中。
        jdbc.execute("SELECT pg_advisory_xact_lock(20261029, 1)");
    }

    public boolean exists(String sql, Object... args) {
        return Boolean.TRUE.equals(jdbc.queryForObject(sql, Boolean.class, args));
    }

    public void audit(String action, String type, Long id) {
        jdbc.update("INSERT INTO operation_audits(operator_id, action, object_type, object_id, result) "
                + "VALUES (?, ?, ?, ?, 'SUCCESS')", context.require().id(), action, type, String.valueOf(id));
    }

    public static void invalid(String message) {
        throw new BusinessException(ErrorCode.VALIDATION_FAILED, message);
    }
}
