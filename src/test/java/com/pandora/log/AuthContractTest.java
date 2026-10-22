package com.pandora.log;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.entity.User;
import com.pandora.log.mapper.UserMapper;
import com.pandora.log.security.JwtService;
import com.pandora.log.support.EmbeddedPostgresSupport;

@SpringBootTest
@AutoConfigureMockMvc
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class AuthContractTest extends EmbeddedPostgresSupport {

    private static final String JDBC_URL = createDatabase("pandora_auth_test");

    private static final String ADMIN_PASSWORD = "test-admin-pass";
    private static final String EMPLOYEE_PASSWORD = "employee-pass";

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> JDBC_URL);
        registry.add("spring.datasource.username", () -> "postgres");
        registry.add("spring.datasource.password", () -> "");
        registry.add("app.jwt.secret", () -> "pandora-log-contract-test-secret-key-0123456789");
        registry.add("app.jwt.issuer", () -> "pandora-log-test");
        registry.add("app.admin.init-username", () -> "admin");
        registry.add("app.admin.init-password", () -> ADMIN_PASSWORD);
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private JwtService jwtService;

    private boolean adminCreatedOnStartup;
    private long departmentId;
    private long teamId;

    @BeforeAll
    void captureStartupAdmin() {
        Long adminCount = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users WHERE role_code = 'ADMIN'", Long.class);
        adminCreatedOnStartup = adminCount != null && adminCount > 0;
    }

    @BeforeEach
    void resetFixtures() {
        jdbcTemplate.update("UPDATE companies SET founder_id = NULL");
        jdbcTemplate.update("UPDATE departments SET manager_id = NULL");
        jdbcTemplate.update("UPDATE teams SET leader_id = NULL");
        jdbcTemplate.update("DELETE FROM refresh_tokens");
        jdbcTemplate.update("DELETE FROM users WHERE role_code <> 'ADMIN'");
        jdbcTemplate.update("DELETE FROM teams");
        jdbcTemplate.update("DELETE FROM departments");
        jdbcTemplate.update("DELETE FROM companies");
        jdbcTemplate.update("UPDATE users SET password_hash = ?, status = 'ACTIVE', "
                        + "failed_attempts = 0, locked_until = NULL WHERE role_code = 'ADMIN'",
                passwordEncoder.encode(ADMIN_PASSWORD));

        long companyId = jdbcTemplate.queryForObject(
                "INSERT INTO companies (name) VALUES ('Pandora') RETURNING id", Long.class);
        departmentId = jdbcTemplate.queryForObject(
                "INSERT INTO departments (company_id, name) VALUES (?, '研发部') RETURNING id",
                Long.class, companyId);
        teamId = jdbcTemplate.queryForObject(
                "INSERT INTO teams (department_id, name) VALUES (?, '一组') RETURNING id",
                Long.class, departmentId);

        insertUser("employee1", "EMPLOYEE", departmentId, teamId, "ACTIVE", null, 0,
                EMPLOYEE_PASSWORD);
        insertUser("disabled1", "EMPLOYEE", departmentId, teamId, "DISABLED", null, 0,
                EMPLOYEE_PASSWORD);
        insertUser("locked1", "EMPLOYEE", departmentId, teamId, "ACTIVE",
                OffsetDateTime.now().plusMinutes(10), 5, EMPLOYEE_PASSWORD);
    }

    @Test
    void createsInitialAdminOnStartup() {
        assertThat(adminCreatedOnStartup).isTrue();
    }

    @Test
    void logsInWithCredentialsAndReturnsTokenPayload() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("admin", ADMIN_PASSWORD)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.message").value("ok"))
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.data.expiresIn").value(7200))
                .andExpect(jsonPath("$.data.user.username").value("admin"))
                .andExpect(jsonPath("$.data.user.realName").value("系统管理员"))
                .andExpect(jsonPath("$.data.user.role").value("ADMIN"))
                .andExpect(jsonPath("$.data.user.departmentId").doesNotExist())
                .andExpect(jsonPath("$.data.user.teamId").doesNotExist());
    }

    @Test
    void rejectsWrongPassword() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("employee1", "wrong-password")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40101));
    }

    @Test
    void locksAccountAfterConfiguredFailures() throws Exception {
        for (int attempt = 1; attempt <= 4; attempt++) {
            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(loginBody("employee1", "wrong-password")))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.code").value(40101));
        }

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("employee1", "wrong-password")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40101));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("employee1", EMPLOYEE_PASSWORD)))
                .andExpect(status().isLocked())
                .andExpect(jsonPath("$.code").value(40103));
    }

    @Test
    void clearsFailureCounterAfterSuccessfulLogin() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginBody("employee1", "wrong-password")));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("employee1", EMPLOYEE_PASSWORD)))
                .andExpect(status().isOk());

        Integer failedAttempts = jdbcTemplate.queryForObject(
                "SELECT failed_attempts FROM users WHERE username = 'employee1'", Integer.class);
        assertThat(failedAttempts).isZero();
    }

    @Test
    void rejectsDisabledAccountAtLogin() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("disabled1", EMPLOYEE_PASSWORD)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40103));
    }

    @Test
    void rejectsLockedAccountAtLogin() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("locked1", EMPLOYEE_PASSWORD)))
                .andExpect(status().isLocked())
                .andExpect(jsonPath("$.code").value(40103));
    }

    @Test
    void rejectsInvalidAndExpiredAccessToken() throws Exception {
        mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40102));

        User admin = userMapper.findByUsername("admin");
        String expiredToken = jwtService.createAccessToken(admin, Duration.ofMinutes(-5));

        mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40102));
    }

    @Test
    void requiresAuthenticationForMeEndpoint() throws Exception {
        mockMvc.perform(get("/api/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40102));
    }

    @Test
    void returnsCurrentUserWithPermissions() throws Exception {
        String adminToken = loginToken("admin", ADMIN_PASSWORD);
        JsonNode admin = getJson("/api/auth/me", adminToken);

        assertThat(admin.path("code").asInt()).isZero();
        assertThat(admin.path("data").path("username").asText()).isEqualTo("admin");
        assertThat(admin.path("data").path("role").asText()).isEqualTo("ADMIN");
        List<String> adminPermissions = toList(admin.path("data").path("permissions"));
        assertThat(adminPermissions).contains("user:manage", "content:read");
        assertThat(adminPermissions).noneMatch(code -> code.startsWith("task:"));

        String employeeToken = loginToken("employee1", EMPLOYEE_PASSWORD);
        JsonNode employee = getJson("/api/auth/me", employeeToken);

        assertThat(employee.path("data").path("role").asText()).isEqualTo("EMPLOYEE");
        assertThat(employee.path("data").path("departmentId").asLong()).isEqualTo(departmentId);
        assertThat(employee.path("data").path("teamId").asLong()).isEqualTo(teamId);
        List<String> employeePermissions = toList(employee.path("data").path("permissions"));
        assertThat(employeePermissions)
                .contains("log:write", "task:execute", "task:self", "content:read")
                .doesNotContain("task:dispatch");
    }

    @Test
    void rotatesRefreshTokenAndRejectsReuse() throws Exception {
        String refreshToken = loginJson("employee1", EMPLOYEE_PASSWORD)
                .path("data").path("refreshToken").asText();

        MvcResult result = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshBody(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
                .andReturn();

        JsonNode refreshed = objectMapper.readTree(
                result.getResponse().getContentAsString(StandardCharsets.UTF_8));
        assertThat(refreshed.path("data").path("refreshToken").asText()).isNotEqualTo(refreshToken);

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshBody(refreshToken)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40102));
    }

    @Test
    void logoutIsIdempotentAndRevokesRefreshToken() throws Exception {
        String refreshToken = loginJson("employee1", EMPLOYEE_PASSWORD)
                .path("data").path("refreshToken").asText();

        mockMvc.perform(post("/api/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshBody(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));

        mockMvc.perform(post("/api/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshBody(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshBody(refreshToken)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40102));

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(refreshBody("unknown-refresh-token")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40102));
    }

    @Test
    void revokesExistingAccessTokenWhenAccountIsDisabled() throws Exception {
        String token = loginToken("employee1", EMPLOYEE_PASSWORD);
        assertThat(getJson("/api/auth/me", token).path("code").asInt()).isZero();

        jdbcTemplate.update("UPDATE users SET status = 'DISABLED' WHERE username = 'employee1'");

        mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40103));

        jdbcTemplate.update("UPDATE users SET status = 'ACTIVE' WHERE username = 'employee1'");

        assertThat(getJson("/api/auth/me", token).path("code").asInt()).isZero();
    }

    @Test
    void revokesExistingAccessTokenWhenAccountIsLocked() throws Exception {
        String token = loginToken("employee1", EMPLOYEE_PASSWORD);

        jdbcTemplate.update("UPDATE users SET failed_attempts = 5, "
                + "locked_until = now() + interval '10 minutes' WHERE username = 'employee1'");

        mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isLocked())
                .andExpect(jsonPath("$.code").value(40103));
    }

    @Test
    void hasNoRegistrationEndpoint() throws Exception {
        String token = loginToken("admin", ADMIN_PASSWORD);

        mockMvc.perform(post("/api/auth/register")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody("new-user", "password123")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(40400));
    }

    @Test
    void validatesLoginPayload() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"\",\"password\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(40001));
    }

    @Test
    void exposesHealthEndpointWithoutAuthentication() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    private void insertUser(String username, String roleCode, Long department, Long team, String status,
            OffsetDateTime lockedUntil, int failedAttempts, String rawPassword) {
        jdbcTemplate.update("INSERT INTO users (username, password_hash, real_name, role_code, "
                        + "department_id, team_id, status, failed_attempts, locked_until) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                username,
                passwordEncoder.encode(rawPassword),
                username,
                roleCode,
                department,
                team,
                status,
                failedAttempts,
                lockedUntil);
    }

    private String loginBody(String username, String password) throws Exception {
        return objectMapper.writeValueAsString(Map.of("username", username, "password", password));
    }

    private String refreshBody(String refreshToken) throws Exception {
        return objectMapper.writeValueAsString(Map.of("refreshToken", refreshToken));
    }

    private JsonNode loginJson(String username, String password) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody(username, password)))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private String loginToken(String username, String password) throws Exception {
        return loginJson(username, password).path("data").path("accessToken").asText();
    }

    private JsonNode getJson(String path, String token) throws Exception {
        MvcResult result = mockMvc.perform(get(path).header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private List<String> toList(JsonNode node) {
        return objectMapper.convertValue(node, objectMapper.getTypeFactory()
                .constructCollectionType(List.class, String.class));
    }
}
