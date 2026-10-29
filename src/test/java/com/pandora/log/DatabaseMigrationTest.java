package com.pandora.log;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.Set;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.output.MigrateResult;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import com.pandora.log.support.EmbeddedPostgresSupport;

/**
 * 在真实 PostgreSQL 上验证 Flyway 迁移、种子数据与关键约束。
 */
class DatabaseMigrationTest extends EmbeddedPostgresSupport {

    private static final String DATABASE = "pandora_migration_test";

    private static String jdbcUrl;
    private static MigrateResult firstRun;

    @BeforeAll
    static void migrateEmptyDatabase() {
        jdbcUrl = createDatabase(DATABASE);
        firstRun = flyway(jdbcUrl).migrate();
    }

    @Test
    void migratesEmptyDatabaseToLatestVersion() {
        assertThat(firstRun.migrationsExecuted).isEqualTo(7);

        Flyway flyway = flyway(jdbcUrl);
        MigrationInfo current = flyway.info().current();
        assertThat(current).isNotNull();
        assertThat(current.getVersion().getVersion()).isEqualTo("7");
        assertThat(current.getState().isApplied()).isTrue();
        assertThat(flyway.info().pending()).isEmpty();
    }

    @Test
    void seedsRolesPermissionsAndSystemConfigs() {
        assertThat(count("roles")).isEqualTo(5);
        assertThat(count("permissions")).isEqualTo(15);
        assertThat(count("role_permissions")).isEqualTo(41);
        assertThat(count("system_configs")).isEqualTo(5);
        assertThat(count("users WHERE role_code IN "
                + "('FOUNDER', 'DEPT_MANAGER', 'TEAM_LEADER', 'EMPLOYEE')")).isEqualTo(4);

        assertThat(count("role_permissions WHERE role_code = 'ADMIN' AND permission_code LIKE 'task:%'"))
                .isZero();
        assertThat(count("role_permissions WHERE role_code = 'EMPLOYEE' AND permission_code = 'task:execute'"))
                .isEqualTo(1);
        assertThat(count("role_permissions WHERE role_code = 'TEAM_LEADER' AND permission_code = 'task:dispatch'"))
                .isEqualTo(1);
    }

    @Test
    void keepsMigrationsIdempotentOnRestart() {
        assertThat(flyway(jdbcUrl).migrate().migrationsExecuted).isZero();
    }

    @Test
    void upgradesVersionFiveWithoutInventingLegacyProfileOrMatterDates() throws SQLException {
        String upgradeUrl = createDatabase("pandora_admin_upgrade_test");
        Flyway.configure().dataSource(upgradeUrl, "postgres", "").target("5").load().migrate();
        String previousHash;
        try (Connection connection = DriverManager.getConnection(upgradeUrl);
                Statement statement = connection.createStatement()) {
            statement.execute("INSERT INTO company_matters(title,content,updated_by) SELECT '旧事项','保留内容',id FROM users WHERE role_code='FOUNDER' LIMIT 1");
            try (ResultSet rs = statement.executeQuery("SELECT password_hash FROM users WHERE username='employee'")) {
                rs.next(); previousHash = rs.getString(1);
            }
        }
        assertThat(flyway(upgradeUrl).migrate().migrationsExecuted).isEqualTo(2);
        try (Connection connection = DriverManager.getConnection(upgradeUrl);
                Statement statement = connection.createStatement()) {
            try (ResultSet rs = statement.executeQuery("SELECT password_hash,phone,auth_version FROM users WHERE username='employee'")) {
                rs.next(); assertThat(rs.getString(1)).isEqualTo(previousHash);
                assertThat(rs.getString(2)).isNull(); assertThat(rs.getInt(3)).isZero();
            }
            try (ResultSet rs = statement.executeQuery("SELECT start_date,deadline,content FROM company_matters")) {
                rs.next(); assertThat(rs.getObject(1)).isNull(); assertThat(rs.getObject(2)).isNull();
                assertThat(rs.getString(3)).isEqualTo("保留内容");
            }
            connection.setAutoCommit(false);
            assertThat(sqlStateOf(connection, "UPDATE company_matters SET start_date='2026-10-29 09:30+08', deadline='2026-10-29 18:00+08'"))
                    .isEqualTo("23514");
            connection.rollback();
        }
    }

    @Test
    void createsAllBusinessTables() {
        Set<String> tables = new HashSet<>();
        try (Connection connection = DriverManager.getConnection(jdbcUrl);
                PreparedStatement statement = connection.prepareStatement(
                        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
                ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                tables.add(resultSet.getString(1));
            }
        } catch (SQLException exception) {
            throw new IllegalStateException("无法读取表清单", exception);
        }

        assertThat(tables).contains(
                "roles", "permissions", "role_permissions", "system_configs",
                "companies", "departments", "teams", "users", "refresh_tokens",
                "work_logs", "log_comments", "operation_audits",
                "tasks", "task_assignments", "task_reviews",
                "personal_tasks", "company_matters", "company_important_tasks");
    }

    @Test
    void rejectsDuplicateOrganizationOwners() {
        inTransaction(connection -> {
            long firstFounder = insertUser(connection, "founder_1", "FOUNDER", null, null,
                    "ACTIVE", null, 0);
            insertCompany(connection, "甲公司", firstFounder);

            assertThat(sqlStateOf(connection, () -> insertCompany(connection, "乙公司", firstFounder)))
                    .isEqualTo("23505");
        });

        inTransaction(connection -> {
            long companyId = insertCompany(connection, "丙公司", null);
            long firstDepartment = insertDepartment(connection, companyId, "研发部", null);
            long secondDepartment = insertDepartment(connection, companyId, "测试部", null);
            long manager = insertUser(connection, "manager_1", "DEPT_MANAGER", firstDepartment, null,
                    "ACTIVE", null, 0);
            updateDepartmentManager(connection, firstDepartment, manager);

            assertThat(sqlStateOf(connection,
                    () -> updateDepartmentManager(connection, secondDepartment, manager)))
                    .isEqualTo("23505");
        });

        inTransaction(connection -> {
            long departmentId = insertDepartment(connection,
                    insertCompany(connection, "丁公司", null), "市场部", null);
            long firstTeam = insertTeam(connection, departmentId, "一组", null);
            long secondTeam = insertTeam(connection, departmentId, "二组", null);
            long leader = insertUser(connection, "leader_1", "TEAM_LEADER", departmentId, firstTeam,
                    "ACTIVE", null, 0);
            updateTeamLeader(connection, firstTeam, leader);

            assertThat(sqlStateOf(connection, () -> updateTeamLeader(connection, secondTeam, leader)))
                    .isEqualTo("23505");
        });
    }

    @Test
    void rejectsIllegalRoleOrganizationAlignment() {
        inTransaction(connection -> {
            long companyId = insertCompany(connection, "戊公司", null);
            long departmentId = insertDepartment(connection, companyId, "销售部", null);
            long teamId = insertTeam(connection, departmentId, "一组", null);

            assertThat(sqlStateOf(connection, () -> insertUser(connection, "employee_missing_team",
                    "EMPLOYEE", departmentId, null, "ACTIVE", null, 0))).isEqualTo("23514");
            assertThat(sqlStateOf(connection, () -> insertUser(connection, "manager_with_team",
                    "DEPT_MANAGER", departmentId, teamId, "ACTIVE", null, 0))).isEqualTo("23514");
        });

        inTransaction(connection -> {
            long departmentId = insertDepartment(connection,
                    insertCompany(connection, "己公司", null), "财务部", null);

            assertThat(sqlStateOf(connection, () -> insertUser(connection, "founder_with_department",
                    "FOUNDER", departmentId, null, "ACTIVE", null, 0))).isEqualTo("23514");
            assertThat(sqlStateOf(connection, () -> insertUser(connection, "admin_with_department",
                    "ADMIN", departmentId, null, "ACTIVE", null, 0))).isEqualTo("23514");
        });
    }

    @Test
    void rejectsDeletingOrganizationInUse() {
        inTransaction(connection -> {
            long companyId = insertCompany(connection, "庚公司", null);
            long departmentId = insertDepartment(connection, companyId, "运营部", null);
            long teamId = insertTeam(connection, departmentId, "一组", null);
            insertUser(connection, "employee_1", "EMPLOYEE", departmentId, teamId, "ACTIVE", null, 0);

            assertThat(sqlStateOf(connection, "DELETE FROM departments WHERE id = " + departmentId))
                    .isEqualTo("23503");
        });
    }

    @Test
    void enforcesLogConstraints() {
        inTransaction(connection -> {
            long departmentId = insertDepartment(connection,
                    insertCompany(connection, "辛公司", null), "产品部", null);
            long teamId = insertTeam(connection, departmentId, "一组", null);
            long authorId = insertUser(connection, "employee_log", "EMPLOYEE", departmentId, teamId,
                    "ACTIVE", null, 0);

            insertWorkLog(connection, authorId, LocalDate.of(2026, 10, 18), "今日完成登录纵切");

            assertThat(sqlStateOf(connection, () -> insertWorkLog(connection, authorId,
                    LocalDate.of(2026, 10, 18), "重复日报"))).isEqualTo("23505");
            assertThat(sqlStateOf(connection, () -> insertWorkLog(connection, authorId,
                    LocalDate.of(2026, 10, 19), "   "))).isEqualTo("23514");
        });
    }

    @Test
    void enforcesTaskConstraints() {
        inTransaction(connection -> {
            long departmentId = insertDepartment(connection,
                    insertCompany(connection, "壬公司", null), "技术部", null);
            long teamId = insertTeam(connection, departmentId, "一组", null);
            long senderId = insertUser(connection, "leader_task", "TEAM_LEADER", departmentId, teamId,
                    "ACTIVE", null, 0);
            long assigneeId = insertUser(connection, "employee_task", "EMPLOYEE", departmentId, teamId,
                    "ACTIVE", null, 0);

            assertThat(sqlStateOf(connection, () -> insertTask(connection, senderId, "非法日期任务",
                    LocalDate.of(2026, 10, 20), LocalDate.of(2026, 10, 18)))).isEqualTo("23514");

            long taskId = insertTask(connection, senderId, "合法任务",
                    LocalDate.of(2026, 10, 18), LocalDate.of(2026, 10, 25));
            insertTaskAssignment(connection, taskId, assigneeId);

            assertThat(sqlStateOf(connection, () -> insertTaskAssignment(connection, taskId, assigneeId)))
                    .isEqualTo("23505");
        });
    }

    @Test
    void enforcesRefreshTokenUniqueness() {
        inTransaction(connection -> {
            long adminId = insertUser(connection, "admin_refresh", "ADMIN", null, null,
                    "ACTIVE", null, 0);
            String tokenHash = "a".repeat(64);
            insertRefreshToken(connection, adminId, tokenHash);

            assertThat(sqlStateOf(connection, () -> insertRefreshToken(connection, adminId, tokenHash)))
                    .isEqualTo("23505");
        });
    }

    private static Flyway flyway(String url) {
        return Flyway.configure()
                .dataSource(url, "postgres", "")
                .locations("classpath:db/migration")
                .load();
    }

    private static long count(String tableOrCondition) {
        try (Connection connection = DriverManager.getConnection(jdbcUrl);
                Statement statement = connection.createStatement();
                ResultSet resultSet = statement.executeQuery(
                        "SELECT COUNT(*) FROM " + tableOrCondition)) {
            resultSet.next();
            return resultSet.getLong(1);
        } catch (SQLException exception) {
            throw new IllegalStateException("无法统计 " + tableOrCondition, exception);
        }
    }

    private static void inTransaction(TransactionalAction action) {
        try (Connection connection = DriverManager.getConnection(jdbcUrl)) {
            connection.setAutoCommit(false);
            try {
                action.run(connection);
            } finally {
                connection.rollback();
            }
        } catch (SQLException exception) {
            throw new IllegalStateException("测试事务执行失败", exception);
        }
    }

    private static String sqlStateOf(Connection connection, SqlAction action) {
        try (Statement statement = connection.createStatement()) {
            statement.execute("SAVEPOINT sp_assertion");
        } catch (SQLException exception) {
            throw new IllegalStateException("无法创建保存点", exception);
        }
        try {
            action.run();
            return null;
        } catch (SQLException exception) {
            try (Statement statement = connection.createStatement()) {
                statement.execute("ROLLBACK TO SAVEPOINT sp_assertion");
            } catch (SQLException rollbackFailure) {
                exception.addSuppressed(rollbackFailure);
            }
            return exception.getSQLState();
        } finally {
            try (Statement statement = connection.createStatement()) {
                statement.execute("RELEASE SAVEPOINT sp_assertion");
            } catch (SQLException ignored) {
                // 事务已整体回滚时保存点可能已不存在
            }
        }
    }

    private static String sqlStateOf(Connection connection, String sql) {
        return sqlStateOf(connection, () -> execute(connection, sql));
    }

    private static long insertCompany(Connection connection, String name, Long founderId) throws SQLException {
        return insertReturningId(connection,
                "INSERT INTO companies (name, founder_id) VALUES (?, ?) RETURNING id",
                name, founderId);
    }

    private static long insertDepartment(Connection connection, long companyId, String name, Long managerId)
            throws SQLException {
        return insertReturningId(connection,
                "INSERT INTO departments (company_id, name, manager_id) VALUES (?, ?, ?) RETURNING id",
                companyId, name, managerId);
    }

    private static long insertTeam(Connection connection, long departmentId, String name, Long leaderId)
            throws SQLException {
        return insertReturningId(connection,
                "INSERT INTO teams (department_id, name, leader_id) VALUES (?, ?, ?) RETURNING id",
                departmentId, name, leaderId);
    }

    private static void updateDepartmentManager(Connection connection, long departmentId, long managerId)
            throws SQLException {
        execute(connection, "UPDATE departments SET manager_id = " + managerId + " WHERE id = " + departmentId);
    }

    private static void updateTeamLeader(Connection connection, long teamId, long leaderId) throws SQLException {
        execute(connection, "UPDATE teams SET leader_id = " + leaderId + " WHERE id = " + teamId);
    }

    private static long insertUser(Connection connection, String username, String roleCode, Long departmentId,
            Long teamId, String status, OffsetDateTime lockedUntil, int failedAttempts) throws SQLException {
        return insertReturningId(connection,
                "INSERT INTO users (username, password_hash, real_name, role_code, department_id, team_id, "
                        + "status, failed_attempts, locked_until) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                username, "$2a$10$012345678901234567890u0123456789012345678901234567890", username,
                roleCode, departmentId, teamId, status, failedAttempts, lockedUntil);
    }

    private static void insertWorkLog(Connection connection, long authorId, LocalDate logDate, String content)
            throws SQLException {
        insertReturningId(connection,
                "INSERT INTO work_logs (author_id, log_date, content, status) "
                        + "VALUES (?, ?, ?, 'DRAFT') RETURNING id",
                authorId, logDate, content);
    }

    private static long insertTask(Connection connection, long senderId, String name, LocalDate startDate,
            LocalDate deadline) throws SQLException {
        return insertReturningId(connection,
                "INSERT INTO tasks (sender_id, name, details, start_date, deadline, urgency) "
                        + "VALUES (?, ?, ?, ?, ?, 'URGENT') RETURNING id",
                senderId, name, "任务详情", startDate, deadline);
    }

    private static void insertTaskAssignment(Connection connection, long taskId, long assigneeId)
            throws SQLException {
        insertReturningId(connection,
                "INSERT INTO task_assignments (task_id, assignee_id) VALUES (?, ?) RETURNING id",
                taskId, assigneeId);
    }

    private static void insertRefreshToken(Connection connection, long userId, String tokenHash)
            throws SQLException {
        insertReturningId(connection,
                "INSERT INTO refresh_tokens (user_id, token_hash, expires_at) "
                        + "VALUES (?, ?, now() + interval '7 days') RETURNING id",
                userId, tokenHash);
    }

    private static void execute(Connection connection, String sql) throws SQLException {
        try (Statement statement = connection.createStatement()) {
            statement.execute(sql);
        }
    }

    private static long insertReturningId(Connection connection, String sql, Object... parameters)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            for (int index = 0; index < parameters.length; index++) {
                statement.setObject(index + 1, parameters[index]);
            }
            try (ResultSet resultSet = statement.executeQuery()) {
                resultSet.next();
                return resultSet.getLong(1);
            }
        }
    }

    @FunctionalInterface
    private interface TransactionalAction {
        void run(Connection connection) throws SQLException;
    }

    @FunctionalInterface
    private interface SqlAction {
        void run() throws SQLException;
    }
}
