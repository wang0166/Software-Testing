package com.pandora.log;

import java.nio.file.*;
import java.security.SecureRandom;
import java.util.*;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.MapPropertySource;
import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;
import com.pandora.log.support.LocalMigrationCompatibility;

/** 仅在本机开发时使用已有测试依赖运行 PostgreSQL，不打进生产 JAR。 */
public final class LocalBackendLauncher {
    private LocalBackendLauncher() { }
    public static void main(String[] args) throws Exception {
        Path data = Path.of(args[0]).toAbsolutePath().normalize();
        int port = Integer.parseInt(args[1]);
        Path stop = data.resolve(".stop-request");
        if (Files.exists(stop)) throw new IllegalStateException("存在停止标记，请确认旧服务已停止后移除 .stop-request");
        Files.createDirectories(data);
        byte[] key = new byte[48]; new SecureRandom().nextBytes(key);
        try (EmbeddedPostgres postgres = EmbeddedPostgres.builder().setDataDirectory(data.toFile())
                .setCleanDataDirectory(false).setServerConfig("listen_addresses", "127.0.0.1").start()) {
            SpringApplication app = new SpringApplication(PandoraApplication.class);
            // 优先级高于已有环境变量，确保本地启动器绝不会连到外部业务数据库。
            Map<String,Object> properties = Map.of(
                    "spring.datasource.url", postgres.getJdbcUrl("postgres", "postgres"),
                    "spring.datasource.username", "postgres", "spring.datasource.password", "",
                    "server.address", "127.0.0.1", "server.port", port,
                    "spring.flyway.locations", LocalMigrationCompatibility.location(postgres.getPostgresDatabase(), data),
                    "app.jwt.secret", Base64.getEncoder().encodeToString(key),
                    "spring.autoconfigure.exclude", "org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration");
            app.addInitializers(context -> context.getEnvironment().getPropertySources()
                    .addFirst(new MapPropertySource("local-backend-only", properties)));
            try (ConfigurableApplicationContext context = app.run()) {
                System.out.println("LOCAL_BACKEND_READY port=" + port);
                while (!Files.exists(stop)) Thread.sleep(500);
                Files.delete(stop);
            }
        }
    }
}
