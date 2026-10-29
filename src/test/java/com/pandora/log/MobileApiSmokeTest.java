package com.pandora.log;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.support.EmbeddedPostgresSupport;

/**
 * 移动端业务接口冒烟测试：覆盖日志、统计、任务、自建任务、公司展示与日历的真实 SQL 与契约。
 */
@SpringBootTest
@AutoConfigureMockMvc
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class MobileApiSmokeTest extends EmbeddedPostgresSupport {

    private static final String JDBC_URL = createDatabase("pandora_mobile_api_test");

    private static final String ADMIN_PASSWORD = "test-admin-pass";
    private static final String PASSWORD = "member-pass";

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("app.log-deadline-job.enabled", () -> "false");
        registry.add("spring.datasource.url", () -> JDBC_URL);
        registry.add("spring.datasource.username", () -> "postgres");
        registry.add("spring.datasource.password", () -> "");
        registry.add("app.jwt.secret", () -> "pandora-log-mobile-test-secret-key-0123456789");
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

    private long founderId;
    private long departmentId;
    private long deptManagerId;
    private long teamId;
    private long teamLeaderId;
    private long employeeId;

    @BeforeEach
    void resetFixtures() {
        jdbcTemplate.update("DELETE FROM task_reviews");
        jdbcTemplate.update("DELETE FROM task_assignments");
        jdbcTemplate.update("DELETE FROM tasks");
        jdbcTemplate.update("DELETE FROM personal_tasks");
        jdbcTemplate.update("DELETE FROM log_comments");
        jdbcTemplate.update("DELETE FROM work_logs");
        jdbcTemplate.update("DELETE FROM company_important_tasks");
        jdbcTemplate.update("DELETE FROM company_matters");
        jdbcTemplate.update("DELETE FROM refresh_tokens");
        jdbcTemplate.update("UPDATE companies SET founder_id = NULL");
        jdbcTemplate.update("UPDATE departments SET manager_id = NULL");
        jdbcTemplate.update("UPDATE teams SET leader_id = NULL");
        jdbcTemplate.update("DELETE FROM users WHERE role_code <> 'ADMIN'");
        jdbcTemplate.update("DELETE FROM teams");
        jdbcTemplate.update("DELETE FROM departments");
        jdbcTemplate.update("DELETE FROM companies");
        jdbcTemplate.update("UPDATE system_configs SET value = '23:59' WHERE key = 'log_deadline'");

        long companyId = jdbcTemplate.queryForObject(
                "INSERT INTO companies (name) VALUES ('Pandora') RETURNING id", Long.class);
        founderId = insertUser("founder", "FOUNDER", null, null);
        jdbcTemplate.update("UPDATE companies SET founder_id = ? WHERE id = ?", founderId, companyId);

        departmentId = jdbcTemplate.queryForObject(
                "INSERT INTO departments (company_id, name) VALUES (?, '研发部') RETURNING id",
                Long.class, companyId);
        deptManagerId = insertUser("deptmgr", "DEPT_MANAGER", departmentId, null);
        jdbcTemplate.update("UPDATE departments SET manager_id = ? WHERE id = ?", deptManagerId, departmentId);

        teamId = jdbcTemplate.queryForObject(
                "INSERT INTO teams (department_id, name) VALUES (?, '一组') RETURNING id",
                Long.class, departmentId);
        teamLeaderId = insertUser("teamlead", "TEAM_LEADER", departmentId, teamId);
        jdbcTemplate.update("UPDATE teams SET leader_id = ? WHERE id = ?", teamLeaderId, teamId);

        employeeId = insertUser("employee1", "EMPLOYEE", departmentId, teamId);
    }

    @Test
    void loginReturnsPermissionsInContractShape() throws Exception {
        JsonNode founder = loginJson("founder");
        JsonNode permissions = founder.path("data").path("user").path("permissions");

        assertThat(permissions.isArray()).isTrue();
        List<String> codes = toList(permissions);
        assertThat(codes).contains("log:write", "task:dispatch", "company-task:manage");
    }

    @Test
    void logLifecycleAndStatsWork() throws Exception {
        String employeeToken = loginToken("employee1");
        String leaderToken = loginToken("teamlead");

        JsonNode created = call(post("/api/logs").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("content", "完成登录接口联调"))), employeeToken);
        long logId = created.path("data").path("id").asLong();
        assertThat(created.path("data").path("status").asText()).isEqualTo("DRAFT");
        assertThat(created.path("data").path("authorId").asLong()).isEqualTo(employeeId);

        JsonNode updated = call(put("/api/logs/" + logId).contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("content", "完成登录接口联调与自测"))), employeeToken);
        assertThat(updated.path("data").path("content").asText()).isEqualTo("完成登录接口联调与自测");

        JsonNode submitted = call(post("/api/logs/" + logId + "/submit"), employeeToken);
        assertThat(submitted.path("data").path("status").asText()).isEqualTo("SUBMITTED");
        assertThat(submitted.path("data").path("submittedAt").asText()).isNotBlank();

        expectError(post("/api/logs").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("content", "重复提交"))), employeeToken, 409, 40901);

        JsonNode list = call(get("/api/logs"), leaderToken);
        assertThat(list.path("data").path("total").asInt()).isEqualTo(1);
        assertThat(list.path("data").path("items").get(0).path("authorName").asText()).isEqualTo("employee1");

        JsonNode detail = call(get("/api/logs/" + logId), employeeToken);
        assertThat(detail.path("data").path("logDate").asText()).isEqualTo(LocalDate.now().toString());

        JsonNode comment = call(post("/api/logs/" + logId + "/comments")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("content", "继续保持"))), leaderToken);
        assertThat(comment.path("data").path("authorName").asText()).isEqualTo("teamlead");

        JsonNode comments = call(get("/api/logs/" + logId + "/comments"), employeeToken);
        assertThat(comments.path("data").size()).isEqualTo(1);

        JsonNode overview = call(get("/api/stats/overview"), leaderToken);
        assertThat(overview.path("data").path("expected").asInt()).isEqualTo(2);
        assertThat(overview.path("data").path("submitted").asInt()).isEqualTo(1);
        assertThat(overview.path("data").path("unsubmitted").asInt()).isEqualTo(1);
        assertThat(overview.path("data").path("rate").asDouble()).isEqualTo(50.0);

        JsonNode trend = call(get("/api/stats/trend?days=7"), leaderToken);
        JsonNode days = trend.path("data").path("days");
        assertThat(days.size()).isEqualTo(7);
        assertThat(days.get(6).path("count").asInt()).isEqualTo(1);

        JsonNode unsubmitted = call(get("/api/stats/unsubmitted"), leaderToken);
        assertThat(unsubmitted.path("data").path("items").size()).isEqualTo(1);
        assertThat(unsubmitted.path("data").path("items").get(0).path("username").asText())
                .isEqualTo("teamlead");
    }

    @Test
    void taskDispatchAndReviewFlowWorks() throws Exception {
        String founderToken = loginToken("founder");
        String managerToken = loginToken("deptmgr");

        JsonNode recipients = call(get("/api/tasks/recipients"), founderToken);
        List<String> recipientNames = toListOfField(recipients.path("data").path("items"), "username");
        assertThat(recipientNames).containsExactly("deptmgr");

        LocalDate today = LocalDate.now();
        JsonNode dispatched = call(post("/api/tasks").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of(
                        "name", "季度复盘",
                        "details", "整理季度目标达成情况",
                        "startDate", today.minusDays(1).toString(),
                        "deadline", today.plusDays(2).toString(),
                        "urgency", "URGENT",
                        "assigneeIds", List.of(deptManagerId)))), founderToken);
        long taskId = dispatched.path("data").path("taskId").asLong();
        assertThat(dispatched.path("data").path("assigneeCount").asInt()).isEqualTo(1);

        JsonNode dispatchedList = call(get("/api/tasks/dispatched"), founderToken);
        assertThat(dispatchedList.path("data").path("total").asInt()).isEqualTo(1);
        assertThat(dispatchedList.path("data").path("items").get(0).path("assigneeCount").asInt())
                .isEqualTo(1);

        JsonNode taskDetail = call(get("/api/tasks/" + taskId), founderToken);
        long assignmentId = taskDetail.path("data").path("assignments").get(0).path("assignmentId").asLong();
        assertThat(taskDetail.path("data").path("assignments").size()).isEqualTo(1);

        JsonNode received = call(get("/api/tasks/received"), managerToken);
        assertThat(received.path("data").path("total").asInt()).isEqualTo(1);
        assertThat(received.path("data").path("items").get(0).path("sender").path("id").asLong())
                .isEqualTo(founderId);

        JsonNode inProgress = call(patch("/api/tasks/assignments/" + assignmentId + "/progress")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("status", "IN_PROGRESS"))), managerToken);
        assertThat(inProgress.path("data").path("executionStatus").asText()).isEqualTo("IN_PROGRESS");

        call(patch("/api/tasks/assignments/" + assignmentId + "/progress")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("status", "COMPLETED"))), managerToken);

        JsonNode invited = call(post("/api/tasks/assignments/" + assignmentId + "/review-invitations"),
                managerToken);
        assertThat(invited.path("data").path("reviewStatus").asText()).isEqualTo("PENDING");

        JsonNode reviewed = call(post("/api/tasks/assignments/" + assignmentId + "/review")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("result", "APPROVED", "comment", "完成质量高"))), founderToken);
        assertThat(reviewed.path("data").path("reviewStatus").asText()).isEqualTo("APPROVED");

        JsonNode approved = call(get("/api/tasks/received?reviewStatus=APPROVED"), managerToken);
        assertThat(approved.path("data").path("total").asInt()).isEqualTo(1);

        JsonNode assignmentDetail = call(
                get("/api/tasks/assignments/" + assignmentId), managerToken);
        assertThat(assignmentDetail.path("data").path("reviews").size()).isEqualTo(2);
        assertThat(assignmentDetail.path("data").path("reviews").get(1).path("action").asText())
                .isEqualTo("APPROVED");

        expectError(patch("/api/tasks/assignments/" + assignmentId + "/progress")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("status", "IN_PROGRESS"))), managerToken, 409, 40910);

        expectError(get("/api/tasks/dispatched"), loginToken("employee1"), 403, 40310);
    }

    @Test
    void personalTaskAndTaskMapWork() throws Exception {
        String employeeToken = loginToken("employee1");

        JsonNode created = call(post("/api/personal-tasks").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("name", "整理会议纪要", "details", "输出本周结论"))), employeeToken);
        long personalTaskId = created.path("data").path("id").asLong();
        assertThat(created.path("data").path("ownerId").asLong()).isEqualTo(employeeId);
        assertThat(created.path("data").path("status").asText()).isEqualTo("NOT_STARTED");

        JsonNode updated = call(put("/api/personal-tasks/" + personalTaskId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("name", "整理会议纪要", "details", "输出本周结论",
                        "status", "IN_PROGRESS"))), employeeToken);
        assertThat(updated.path("data").path("status").asText()).isEqualTo("IN_PROGRESS");

        JsonNode list = call(get("/api/personal-tasks"), employeeToken);
        assertThat(list.path("data").path("total").asInt()).isEqualTo(1);

        JsonNode taskMap = call(get("/api/task-map"), employeeToken);
        assertThat(taskMap.path("data").path("total").asInt()).isEqualTo(1);
        assertThat(taskMap.path("data").path("items").get(0).path("source").asText()).isEqualTo("PERSONAL");
        assertThat(taskMap.path("data").path("items").get(0).path("personalTaskId").asLong())
                .isEqualTo(personalTaskId);
    }

    @Test
    void calendarAndCompanyContentWorkWithScopedPermissions() throws Exception {
        jdbcTemplate.update("INSERT INTO company_matters (title, content, sort_order, updated_by) "
                + "VALUES ('客户第一', '把客户价值放在首位', 1, ?)", founderId);

        String employeeToken = loginToken("employee1");
        String founderToken = loginToken("founder");
        String managerToken = loginToken("deptmgr");

        JsonNode matters = call(get("/api/company-matters"), employeeToken);
        assertThat(matters.path("data").path("total").asInt()).isEqualTo(1);
        assertThat(matters.path("data").path("items").get(0).path("title").asText()).isEqualTo("客户第一");

        JsonNode importantTasks = call(get("/api/company-important-tasks"), employeeToken);
        assertThat(importantTasks.path("data").path("total").asInt()).isEqualTo(0);

        LocalDate today = LocalDate.now();
        JsonNode dispatched = call(post("/api/tasks").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of(
                        "name", "客户回访",
                        "details", "覆盖重点客户",
                        "startDate", today.minusDays(1).toString(),
                        "deadline", today.plusDays(1).toString(),
                        "urgency", "NOT_URGENT",
                        "assigneeIds", List.of(deptManagerId)))), founderToken);
        long taskId = dispatched.path("data").path("taskId").asLong();
        assertThat(taskId).isPositive();

        JsonNode calendar = call(get("/api/calendar?from=" + today.minusDays(1) + "&to=" + today.plusDays(3)),
                managerToken);
        JsonNode days = calendar.path("data").path("days");
        assertThat(days.size()).isEqualTo(5);
        assertThat(days.get(0).path("date").asText()).isEqualTo(today.minusDays(1).toString());
        assertThat(days.get(0).path("taskCount").asInt()).isEqualTo(1);
        assertThat(days.get(0).path("mark").asText()).isEqualTo("GREEN");
        assertThat(days.get(4).path("mark").asText()).isEqualTo("NONE");

        expectError(get("/api/calendar?from=" + today + "&to=" + today.plusDays(3)),
                loginToken("admin"), 403, 40310);
    }

    private long insertUser(String username, String roleCode, Long department, Long team) {
        return jdbcTemplate.queryForObject(
                "INSERT INTO users (username, password_hash, real_name, role_code, department_id, team_id, status) "
                        + "VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE') RETURNING id",
                Long.class,
                username,
                passwordEncoder.encode(PASSWORD),
                username,
                roleCode,
                department,
                team);
    }

    private JsonNode call(MockHttpServletRequestBuilder request, String token) throws Exception {
        MvcResult result = mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private void expectError(MockHttpServletRequestBuilder request, String token, int httpStatus, int code)
            throws Exception {
        MvcResult result = mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().is(httpStatus))
                .andReturn();
        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
        assertThat(body.path("code").asInt()).isEqualTo(code);
    }

    private JsonNode loginJson(String username) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("username", username, "password", PASSWORD))))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private String loginToken(String username) throws Exception {
        if ("admin".equals(username)) {
            MvcResult result = mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json(Map.of("username", username, "password", ADMIN_PASSWORD))))
                    .andExpect(status().isOk())
                    .andReturn();
            return objectMapper.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8))
                    .path("data").path("accessToken").asText();
        }
        return loginJson(username).path("data").path("accessToken").asText();
    }

    private String json(Object value) throws Exception {
        return objectMapper.writeValueAsString(value);
    }

    private List<String> toList(JsonNode node) {
        return objectMapper.convertValue(node, objectMapper.getTypeFactory()
                .constructCollectionType(List.class, String.class));
    }

    private List<String> toListOfField(JsonNode array, String field) {
        List<String> values = new java.util.ArrayList<>();
        array.forEach(item -> values.add(item.path(field).asText()));
        return values;
    }
}
