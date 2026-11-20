package com.pandora.log.support;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import javax.sql.DataSource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;

/** 兼容首次交付前在本机执行过的旧 V6；不修改已应用迁移、校验和或业务数据。 */
public final class LocalMigrationCompatibility {
    private LocalMigrationCompatibility() { }

    public static String location(DataSource source, Path dataDirectory) throws SQLException, IOException {
        try (Connection connection = source.getConnection(); var statement = connection.createStatement()) {
            try (var rs = statement.executeQuery("SELECT to_regclass('public.flyway_schema_history')")) {
                rs.next(); if (rs.getString(1) == null) return "classpath:db/migration";
            }
            try (var rs = statement.executeQuery("SELECT script FROM flyway_schema_history WHERE version='6' AND success=true")) {
                if (!rs.next() || !"V6__web_admin_management.sql".equals(rs.getString(1))) return "classpath:db/migration";
            }
        }
        // 本地旧库保留 V6 Web -> V7 完整性约束的原始执行顺序；服务器采用 V6 完整性 -> V7 Web。
        // Flyway 仍会校验历史文件，未知或已改动的旧脚本会失败，不使用 repair/忽略校验掩盖冲突。
        Path directory = dataDirectory.resolveSibling(dataDirectory.getFileName() + ".migration-compat");
        Files.createDirectories(directory);
        for (Resource resource : new PathMatchingResourcePatternResolver().getResources("classpath*:db/migration/V*__*.sql")) {
            String name = resource.getFilename();
            if ("V7__web_admin_management.sql".equals(name)) continue;
            if ("V6__enhance_data_integrity.sql".equals(name)) name = "V7__enhance_data_integrity.sql";
            try (var input = resource.getInputStream()) { Files.write(directory.resolve(name), input.readAllBytes()); }
        }
        try (var input = new ClassPathResource("local-web-legacy/V6__web_admin_management.sql").getInputStream()) {
            Files.write(directory.resolve("V6__web_admin_management.sql"), input.readAllBytes());
        }
        return "filesystem:" + directory.toAbsolutePath();
    }
}
