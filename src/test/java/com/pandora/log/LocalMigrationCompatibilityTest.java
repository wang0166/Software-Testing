package com.pandora.log;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import java.nio.file.Files;
import java.nio.file.Path;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.FlywayException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import com.pandora.log.support.EmbeddedPostgresSupport;
import com.pandora.log.support.LocalMigrationCompatibility;

class LocalMigrationCompatibilityTest extends EmbeddedPostgresSupport {
    @TempDir Path directory;

    @Test void freshDatabaseUsesCanonicalMigrationOrder() throws Exception {
        var source = database("pandora_fresh_migration_test");
        String location = LocalMigrationCompatibility.location(source, directory.resolve("pgdata"));
        assertThat(location).isEqualTo("classpath:db/migration");
        assertThat(Flyway.configure().dataSource(source).locations(location).load().migrate().migrationsExecuted).isEqualTo(7);
    }

    @Test void serverVersionSixUpgradesByOneMigrationAndPreservesUsers() throws Exception {
        var source = database("pandora_server_v6_test");
        Flyway.configure().dataSource(source).target("6").load().migrate();
        JdbcTemplate jdbc = new JdbcTemplate(source);
        Long users = jdbc.queryForObject("SELECT count(*) FROM users", Long.class);
        String location = LocalMigrationCompatibility.location(source, directory.resolve("pgdata"));
        assertThat(location).isEqualTo("classpath:db/migration");
        assertThat(Flyway.configure().dataSource(source).locations(location).load().migrate().migrationsExecuted).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM users", Long.class)).isEqualTo(users);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM information_schema.columns WHERE table_name='users' AND column_name='phone'", Long.class)).isEqualTo(1);
    }

    @Test void legacyLocalVersionSixKeepsItsHistoryAndAppliesIntegrityWithoutRepair() throws Exception {
        var source = database("pandora_local_legacy_v6_test");
        legacyMigration(source, false);
        JdbcTemplate jdbc = new JdbcTemplate(source);
        var before = jdbc.queryForMap("SELECT script, checksum FROM flyway_schema_history WHERE version='6'");
        var users = jdbc.queryForList("SELECT id, username, password_hash FROM users ORDER BY id");
        String location = LocalMigrationCompatibility.location(source, directory.resolve("pgdata"));
        assertThat(location).startsWith("filesystem:");
        Flyway flyway = Flyway.configure().dataSource(source).locations(location).load();
        assertThat(flyway.migrate().migrationsExecuted).isEqualTo(1);
        assertThat(jdbc.queryForMap("SELECT script, checksum FROM flyway_schema_history WHERE version='6'")).isEqualTo(before);
        assertThat(jdbc.queryForList("SELECT id, username, password_hash FROM users ORDER BY id")).isEqualTo(users);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM pg_constraint WHERE conname='fk_users_team_department'", Long.class)).isEqualTo(1);
        assertThat(flyway.migrate().migrationsExecuted).isZero();
    }

    @Test void changedLegacyChecksumFailsBeforeApplyingNewConstraints() throws Exception {
        var source = database("pandora_changed_legacy_v6_test");
        legacyMigration(source, true);
        String location = LocalMigrationCompatibility.location(source, directory.resolve("pgdata"));
        assertThatThrownBy(() -> Flyway.configure().dataSource(source).locations(location).load().migrate()).isInstanceOf(FlywayException.class);
        JdbcTemplate jdbc = new JdbcTemplate(source);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM pg_constraint WHERE conname='fk_users_team_department'", Long.class)).isZero();
    }

    private DriverManagerDataSource database(String name) { return new DriverManagerDataSource(createDatabase(name), "postgres", ""); }

    private void legacyMigration(DriverManagerDataSource source, boolean changed) throws Exception {
        Path oldFiles = directory.resolve("legacy-input"); Files.createDirectories(oldFiles);
        for (var resource : new PathMatchingResourcePatternResolver().getResources("classpath*:db/migration/V*__*.sql")) {
            String name = resource.getFilename();
            if (name.startsWith("V6__") || name.startsWith("V7__")) continue;
            try (var input = resource.getInputStream()) { Files.write(oldFiles.resolve(name), input.readAllBytes()); }
        }
        String original = new ClassPathResource("local-web-legacy/V6__web_admin_management.sql").getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        Files.writeString(oldFiles.resolve("V6__web_admin_management.sql"), original + (changed ? "\nSELECT 1;\n" : ""));
        Flyway.configure().dataSource(source).locations("filesystem:" + oldFiles).load().migrate();
    }
}
