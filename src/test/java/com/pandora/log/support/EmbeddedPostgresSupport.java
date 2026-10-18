package com.pandora.log.support;

import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;

/**
 * 集成测试共享的嵌入式 PostgreSQL 实例。
 */
public abstract class EmbeddedPostgresSupport {

    private static final EmbeddedPostgres POSTGRES = startPostgres();

    private static EmbeddedPostgres startPostgres() {
        try {
            return EmbeddedPostgres.builder().start();
        } catch (IOException exception) {
            throw new IllegalStateException("无法启动嵌入式 PostgreSQL", exception);
        }
    }

    protected static String createDatabase(String databaseName) {
        try (Connection connection = POSTGRES.getPostgresDatabase().getConnection();
                Statement statement = connection.createStatement()) {
            statement.execute("DROP DATABASE IF EXISTS " + databaseName + " WITH (FORCE)");
            statement.execute("CREATE DATABASE " + databaseName);
        } catch (SQLException exception) {
            throw new IllegalStateException("无法创建测试数据库 " + databaseName, exception);
        }
        return POSTGRES.getJdbcUrl("postgres", databaseName);
    }
}
