package com.pandora.log;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.*;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import com.fasterxml.jackson.databind.*;
import com.pandora.log.security.TokenHashService;
import com.pandora.log.service.LogDeadlineService;
import com.pandora.log.support.EmbeddedPostgresSupport;

/** 新移动端契约通过真实 PostgreSQL 与 MVC 安全链验证，时间边界使用可控时钟。 */
@SpringBootTest
@AutoConfigureMockMvc
class MobileBackendContractTest extends EmbeddedPostgresSupport {
    private static final String URL=createDatabase("pandora_mobile_redesign_test");
    private static final String PASSWORD="contract-pass-123";
    private static final ZoneId ZONE=ZoneId.of("Asia/Shanghai");
    @DynamicPropertySource static void database(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url",()->URL);r.add("spring.datasource.username",()->"postgres");r.add("spring.datasource.password",()->"");
        r.add("app.jwt.secret",()->"pandora-mobile-redesign-test-key-0123456789");
        r.add("app.admin.init-password",()->"");r.add("app.log-deadline-job.enabled",()->"false");
    }
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @Autowired PasswordEncoder passwords;
    @Autowired LogDeadlineService deadlines;
    @MockBean Clock clock;
    private volatile Instant instant;
    private LocalDate today;
    private long adminId, employeeId, leaderId, managerId, teamId, departmentId, otherId;
    private String admin,employee,leader,manager,other;

    @BeforeEach void fixtures() throws Exception {
        today=LocalDate.now(ZONE); at(today.atTime(21,59));
        when(clock.getZone()).thenReturn(ZONE);when(clock.instant()).thenAnswer(i->instant);
        when(clock.withZone(any(ZoneId.class))).thenAnswer(i->Clock.fixed(instant,i.getArgument(0)));
        jdbc.execute("TRUNCATE companies,users RESTART IDENTITY CASCADE");
        jdbc.execute("TRUNCATE operation_audits,password_request_limits RESTART IDENTITY");
        jdbc.update("UPDATE system_configs SET value='22:00' WHERE key='log_deadline'");
        adminId=user("admin","ADMIN",null,null);
        long company=jdbc.queryForObject("INSERT INTO companies(name) VALUES ('契约公司') RETURNING id",Long.class);
        departmentId=jdbc.queryForObject("INSERT INTO departments(name,company_id) VALUES ('研发部',?) RETURNING id",Long.class,company);
        teamId=jdbc.queryForObject("INSERT INTO teams(name,department_id) VALUES ('移动组',?) RETURNING id",Long.class,departmentId);
        leaderId=user("leader","TEAM_LEADER",departmentId,teamId);
        jdbc.update("UPDATE teams SET leader_id=? WHERE id=?",leaderId,teamId);
        managerId=user("manager","DEPT_MANAGER",departmentId,null);
        jdbc.update("UPDATE departments SET manager_id=? WHERE id=?",managerId,departmentId);
        employeeId=user("member","EMPLOYEE",departmentId,teamId);
        long otherDepartment=jdbc.queryForObject("INSERT INTO departments(name,company_id) VALUES ('其他部门',?) RETURNING id",Long.class,company);
        long otherTeam=jdbc.queryForObject("INSERT INTO teams(name,department_id) VALUES ('其他组',?) RETURNING id",Long.class,otherDepartment);
        otherId=user("other","EMPLOYEE",otherDepartment,otherTeam);
        admin=login("admin",PASSWORD).path("accessToken").asText();
        employee=login("member",PASSWORD).path("accessToken").asText();
        leader=login("leader",PASSWORD).path("accessToken").asText();
        manager=login("manager",PASSWORD).path("accessToken").asText();
        other=login("other",PASSWORD).path("accessToken").asText();
    }

    @Test void minuteTaskRoundTripsThroughAllReadViews() throws Exception {
        long id=ok(post("/api/tasks"),leader,task("2026-10-29T09:30:00","2026-10-29T17:45:00",employeeId)).path("taskId").asLong();
        assertThat(jdbc.queryForObject("SELECT start_date FROM tasks WHERE id=?",LocalDateTime.class,id)).isEqualTo(LocalDateTime.of(2026,10,29,9,30));
        for (String route:List.of("/api/tasks/dispatched","/api/tasks/"+id,"/api/tasks/received","/api/task-map")) {
            JsonNode data=ok(get(route),route.contains("received")||route.contains("task-map")?employee:leader,null);
            JsonNode item=data.has("items")?data.path("items").get(0):data;
            assertThat(item.path("startDate").asText()).startsWith("2026-10-29T09:30");
            assertThat(item.path("deadline").asText()).startsWith("2026-10-29T17:45");
        }
        JsonNode day=ok(get("/api/calendar?from=2026-10-29&to=2026-10-29"),employee,null).path("days").get(0);
        assertThat(day.path("taskCount").asInt()).isEqualTo(1);
    }
    @Test void invalidMinutesAndForeignRecipientsAreRejected() throws Exception {
        for (String end:List.of("2026-10-29T09:30:00","2026-10-29T08:30:00","2026-10-29T10:30:01","2026-02-30T10:30:00","2026-10-29T10:30:00+08:00")) {
            response(post("/api/tasks"),leader,task("2026-10-29T09:30:00",end,employeeId),400);
        }
        // 同公司跨部门允许派发；跨公司仍拒绝
        long foreignCompany=jdbc.queryForObject(
                "INSERT INTO companies(name) VALUES ('外部公司') RETURNING id",Long.class);
        long foreignDepartment=jdbc.queryForObject(
                "INSERT INTO departments(name,company_id) VALUES ('外部部门',?) RETURNING id",
                Long.class,foreignCompany);
        long foreignTeam=jdbc.queryForObject(
                "INSERT INTO teams(name,department_id) VALUES ('外部团队',?) RETURNING id",
                Long.class,foreignDepartment);
        long foreignId=user("outsider","EMPLOYEE",foreignDepartment,foreignTeam);
        response(post("/api/tasks"),leader,task("2026-10-29T09:30:00","2026-10-29T10:30:00",foreignId),403);
        // 派发给上级不能走直接派发，必须提交派发申请
        response(post("/api/tasks"),leader,task("2026-10-29T09:30:00","2026-10-29T10:30:00",managerId),409);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM tasks",Long.class)).isZero();
    }
    @Test void legacyDateRequestsStillCoverTheWholeDay() throws Exception {
        long id=ok(post("/api/tasks"),leader,task("2026-10-29","2026-10-29",employeeId)).path("taskId").asLong();
        assertThat(jdbc.queryForObject("SELECT deadline FROM tasks WHERE id=?",LocalDateTime.class,id)).isEqualTo(LocalDateTime.of(2026,10,29,23,59));
    }
    @Test void logMetadataAndCommentRolesAreEnforcedByServer() throws Exception {
        long id=ok(post("/api/logs"),employee,Map.of("content","真实日志")).path("id").asLong();
        JsonNode item=ok(get("/api/logs"),leader,null).path("items").get(0);
        assertThat(item.path("authorRole").asText()).isEqualTo("EMPLOYEE");
        assertThat(item.path("departmentId").asLong()).isEqualTo(departmentId);
        assertThat(item.path("departmentName").asText()).isEqualTo("研发部");
        assertThat(item.path("teamId").asLong()).isEqualTo(teamId);
        assertThat(item.path("teamName").asText()).isEqualTo("移动组");
        assertThat(ok(get("/api/logs"),other,null).path("total").asLong()).isZero();
        response(post("/api/logs/"+id+"/comments"),employee,Map.of("content","不能自行发起"),400);
        long comment=ok(post("/api/logs/"+id+"/comments"),leader,Map.of("content","上级点评")).path("id").asLong();
        long reply=ok(post("/api/logs/"+id+"/comments"),employee,Map.of("content","作者回复","parentId",comment)).path("id").asLong();
        response(post("/api/logs/"+id+"/comments"),employee,Map.of("content","不能回复自己","parentId",reply),400);
        response(post("/api/logs/"+id+"/comments"),leader,Map.of("content","上级只能发起","parentId",comment),400);
        response(get("/api/logs/"+id+"/comments"),other,null,403);
        response(get("/api/logs/"+id+"/comments"),admin,null,403);
    }
    @Test void deadlineIsInclusiveAndSettlementIsIdempotent() throws Exception {
        long id=ok(post("/api/logs"),employee,Map.of("content","截止前草稿")).path("id").asLong();
        at(today.atTime(22,0));
        for (var route:List.of(put("/api/logs/"+id),post("/api/logs/"+id+"/submit"))) response(route,employee,Map.of("content","过期修改"),409);
        response(post("/api/logs"),other,Map.of("content","截止后新建"),409);
        assertThat(deadlines.settle()).isEqualTo(1);assertThat(deadlines.settle()).isZero();
        assertThat(jdbc.queryForObject("SELECT status FROM work_logs WHERE id=?",String.class,id)).isEqualTo("SUBMITTED");
        assertThat(ok(get("/api/stats/overview"),leader,null).path("submitted").asInt()).isEqualTo(1);
    }
    @Test void oldDraftCannotBeChangedAndRestartCatchesItUp() throws Exception {
        long old=jdbc.queryForObject("INSERT INTO work_logs(author_id,log_date,content) VALUES (?,?,'历史草稿') RETURNING id",Long.class,employeeId,today.minusDays(1));
        response(put("/api/logs/"+old),employee,Map.of("content","次日修改"),409);
        response(post("/api/logs/"+old+"/submit"),employee,Map.of(),409);
        long current=ok(post("/api/logs"),other,Map.of("content","今日草稿")).path("id").asLong();
        assertThat(deadlines.settle()).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT status FROM work_logs WHERE id=?",String.class,current)).isEqualTo("DRAFT");
    }
    @Test void approvedChangeIsSingleUseAndRevokesAllSessions() throws Exception {
        String refresh=login("member",PASSWORD).path("refreshToken").asText();
        response(post("/api/account/password-change"),employee,Map.of("newPassword","new-member-pass"),403);
        long id=changeRequest();
        response(post("/api/account/password-change-requests"),employee,Map.of(),409);
        response(get("/api/password-requests"),employee,null,403);
        response(post("/api/password-requests/"+id+"/review"),employee,review("APPROVED"),403);
        ok(post("/api/password-requests/"+id+"/review"),admin,review("APPROVED"));
        assertThat(ok(get("/api/account/password-change-requests/me"),employee,null).path("status").asText()).isEqualTo("APPROVED");
        response(post("/api/account/password-change"),employee,Map.of("newPassword","密".repeat(30)),400);
        ok(post("/api/account/password-change"),employee,Map.of("newPassword","new-member-pass"));
        response(get("/api/auth/me"),employee,null,401);
        response(post("/api/auth/refresh"),null,Map.of("refreshToken",refresh),401);
        String fresh=login("member","new-member-pass").path("accessToken").asText();
        response(post("/api/account/password-change"),fresh,Map.of("newPassword","another-pass"),403);
        assertThat(ok(get("/api/account/password-change-requests/me"),fresh,null).path("status").asText()).isEqualTo("NONE");
        assertThat(jdbc.queryForObject("SELECT status FROM password_requests WHERE id=?",String.class,id)).isEqualTo("CONSUMED");
        assertNoSecretInAudit("new-member-pass",refresh);
    }
    @Test void reviewsRequireIdentityCheckReauthenticationAndDifferentAdmin() throws Exception {
        long id=changeRequest();
        response(post("/api/password-requests/"+id+"/review"),admin,Map.of("decision","APPROVED","currentPassword",PASSWORD),400);
        response(post("/api/password-requests/"+id+"/review"),admin,Map.of("decision","APPROVED","identityVerified",true,"currentPassword","x".repeat(73)),400);
        response(post("/api/password-requests/"+id+"/review"),admin,Map.of("decision","APPROVED","identityVerified",true,"currentPassword","wrong-password"),401);
        ok(post("/api/account/password-change-requests"),admin,Map.of());
        long self=jdbc.queryForObject("SELECT id FROM password_requests WHERE user_id=?",Long.class,adminId);
        response(post("/api/password-requests/"+self+"/review"),admin,review("APPROVED"),403);
        assertNoSecretInAudit(PASSWORD,"wrong-password");
    }
    @Test void rejectedAndExpiredApplicationsCanBeRequestedAgain() throws Exception {
        long id=changeRequest();ok(post("/api/password-requests/"+id+"/review"),admin,review("REJECTED"));
        assertThat(ok(get("/api/account/password-change-requests/me"),employee,null).path("status").asText()).isEqualTo("REJECTED");
        long next=changeRequest();at(today.plusDays(2).atTime(9,0));
        assertThat(ok(get("/api/account/password-change-requests/me"),employee,null).path("status").asText()).isEqualTo("NONE");
        response(post("/api/password-requests/"+next+"/review"),admin,review("APPROVED"),409);
        changeRequest();
    }
    @Test void approvedApplicationExpiresAfterFifteenMinutes() throws Exception {
        long id=changeRequest();ok(post("/api/password-requests/"+id+"/review"),admin,review("APPROVED"));
        at(today.atTime(22,15));
        response(post("/api/account/password-change"),employee,Map.of("newPassword","new-member-pass"),403);
        assertThat(ok(get("/api/password-requests?status=EXPIRED"),admin,null).path("total").asLong()).isEqualTo(1);
    }
    @Test void anonymousResetResponseIsUniformAndRequestsAreLimited() throws Exception {
        JsonNode expected=response(post("/api/auth/password-reset-requests"),null,Map.of("username","missing-account"),200);
        for(int i=0;i<9;i++) assertThat(response(post("/api/auth/password-reset-requests"),null,Map.of("username","member"),200)).isEqualTo(expected);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM password_requests",Long.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT max(attempts) FROM password_request_limits",Integer.class)).isGreaterThan(5);
        assertThat(jdbc.queryForList("SELECT bucket_key FROM password_request_limits",String.class)).allMatch(v->v.matches("[a-f0-9]{64}"));
        assertThat(login("member",PASSWORD).path("accessToken").asText()).isNotBlank();
    }
    @Test void recoveryTokenIsHashedSingleUseAndDoesNotAppearInListsOrAudit() throws Exception {
        long id=resetRequest();
        JsonNode approval=ok(post("/api/password-requests/"+id+"/review"),admin,review("APPROVED"));
        String token=approval.path("recoveryToken").asText();assertThat(token).hasSize(43);
        assertThat(jdbc.queryForObject("SELECT token_hash FROM password_requests WHERE id=?",String.class,id)).isEqualTo(TokenHashService.sha256(token));
        assertThat(ok(get("/api/password-requests"),admin,null).toString()).doesNotContain(token);
        ok(post("/api/auth/password-reset"),null,Map.of("token",token,"newPassword","recovered-pass"));
        response(post("/api/auth/password-reset"),null,Map.of("token",token,"newPassword","recovered-pass"),400);
        response(get("/api/auth/me"),employee,null,401);login("member","recovered-pass");
        assertNoSecretInAudit(token,"recovered-pass");
    }
    @Test void oldRecoveryApprovalDiesWhenAdministratorResetsPassword() throws Exception {
        long id=resetRequest();String token=ok(post("/api/password-requests/"+id+"/review"),admin,review("APPROVED")).path("recoveryToken").asText();
        ok(put("/api/users/"+employeeId+"/password"),admin,Map.of("password","admin-replacement"));
        response(post("/api/auth/password-reset"),null,Map.of("token",token,"newPassword","not-authorized"),400);
        login("member","admin-replacement");
    }
    @Test void simultaneousApprovalsAndRecoveriesHaveOnlyOneWinner() throws Exception {
        long id=resetRequest();
        var pool=Executors.newFixedThreadPool(2);
        try {
            var approvals=pool.invokeAll(List.<Callable<JsonNode>>of(
                    ()->response(post("/api/password-requests/"+id+"/review"),admin,review("APPROVED"),0),
                    ()->response(post("/api/password-requests/"+id+"/review"),admin,review("APPROVED"),0)));
            List<JsonNode> values=List.of(approvals.get(0).get(),approvals.get(1).get());
            assertThat(values.stream().filter(n->n.path("code").asInt()==0).count()).isEqualTo(1);
            String token=values.stream().filter(n->n.path("code").asInt()==0).findFirst().orElseThrow().path("data").path("recoveryToken").asText();
            var completions=pool.invokeAll(List.<Callable<JsonNode>>of(
                    ()->response(post("/api/auth/password-reset"),null,Map.of("token",token,"newPassword","concurrent-pass"),0),
                    ()->response(post("/api/auth/password-reset"),null,Map.of("token",token,"newPassword","concurrent-pass"),0)));
            assertThat(List.of(completions.get(0).get(),completions.get(1).get()).stream().filter(n->n.path("code").asInt()==0).count()).isEqualTo(1);
        } finally {pool.shutdownNow();}
    }

    @Test void failedRecoveryAttemptsRemainLimitedAfterBusinessRollback() throws Exception {
        for(int i=0;i<5;i++) response(post("/api/auth/password-reset"),null,Map.of("token","unknown-token","newPassword","valid-new-pass"),400);
        response(post("/api/auth/password-reset"),null,Map.of("token","unknown-token","newPassword","valid-new-pass"),429);
        assertThat(jdbc.queryForObject("SELECT max(attempts) FROM password_request_limits",Integer.class)).isEqualTo(6);
    }

    @Test void recoveryCredentialExpiresAndDisabledAccountsReceiveUniformAcknowledgment() throws Exception {
        long id=resetRequest();
        String token=ok(post("/api/password-requests/"+id+"/review"),admin,review("APPROVED")).path("recoveryToken").asText();
        at(today.atTime(22,15));
        response(post("/api/auth/password-reset"),null,Map.of("token",token,"newPassword","not-usable-pass"),400);
        jdbc.update("UPDATE users SET status='DISABLED' WHERE id=?",otherId);
        JsonNode disabled=response(post("/api/auth/password-reset-requests"),null,Map.of("username","other"),200);
        JsonNode missing=response(post("/api/auth/password-reset-requests"),null,Map.of("username","does-not-exist"),200);
        assertThat(disabled).isEqualTo(missing);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM password_requests WHERE user_id=?",Long.class,otherId)).isZero();
    }

    @Test void crossDayTasksKeepMinutesAndCommentsCannotReplyAcrossLogs() throws Exception {
        ok(post("/api/tasks"),leader,task("2026-10-29T23:45:00","2026-10-30T00:15:00",employeeId));
        JsonNode days=ok(get("/api/calendar?from=2026-10-29&to=2026-10-30"),employee,null).path("days");
        assertThat(days.get(0).path("taskCount").asInt()).isEqualTo(1);
        assertThat(days.get(1).path("taskCount").asInt()).isEqualTo(1);
        long first=ok(post("/api/logs"),employee,Map.of("content","今天日志")).path("id").asLong();
        long old=jdbc.queryForObject("INSERT INTO work_logs(author_id,log_date,content) VALUES (?,?,'昨天日志') RETURNING id",Long.class,employeeId,today.minusDays(1));
        long comment=ok(post("/api/logs/"+old+"/comments"),leader,Map.of("content","昨日点评")).path("id").asLong();
        response(post("/api/logs/"+first+"/comments"),employee,Map.of("content","不能跨日志回复","parentId",comment),400);
    }

    @Test void subordinateOverviewAndDispatchRequestRestoreCompanyModule() throws Exception {
        // 派发给下级不需要审核，直接生成任务
        JsonNode direct=ok(post("/api/tasks/dispatch-requests"),leader,Map.of(
                "name","派发申请任务","details","完整说明","startDate","2026-10-29T09:30:00",
                "deadline","2026-10-29T17:45:00","urgency","NOT_URGENT","taskType","GENERAL",
                "assigneeIds",List.of(employeeId)));
        assertThat(direct.path("status").asText()).isEqualTo("APPROVED");
        assertThat(direct.path("requestId").isNull()).isTrue();
        long taskId=direct.path("taskId").asLong();
        assertThat(taskId).isPositive();
        assertThat(ok(get("/api/tasks/dispatch-requests/mine"),leader,null).path("items").size()).isZero();

        // 派发给上级必须审核，由接收人的上级（部门负责人）审批
        JsonNode request=ok(post("/api/tasks/dispatch-requests"),leader,Map.of(
                "name","向上派发任务","details","需要上级确认","startDate","2026-10-29T09:30:00",
                "deadline","2026-10-29T17:45:00","urgency","NOT_URGENT","taskType","GENERAL",
                "assigneeIds",List.of(managerId)));
        assertThat(request.path("status").asText()).isEqualTo("PENDING");
        assertThat(request.path("taskId").isNull()).isTrue();
        long requestId=request.path("requestId").asLong();
        assertThat(ok(get("/api/tasks/dispatch-requests/mine"),leader,null)
                .path("items").get(0).path("status").asText()).isEqualTo("PENDING");
        assertThat(ok(get("/api/tasks/dispatch-requests/reviewable"),manager,null)
                .path("items").get(0).path("requestId").asLong()).isEqualTo(requestId);

        JsonNode approved=ok(post("/api/tasks/dispatch-requests/"+requestId+"/approve"),manager,
                Map.of("comment","同意派发"));
        assertThat(approved.path("status").asText()).isEqualTo("APPROVED");
        assertThat(approved.path("taskId").asLong()).isPositive();
        assertThat(ok(get("/api/tasks/dispatch-requests/mine"),leader,null)
                .path("items").get(0).path("status").asText()).isEqualTo("APPROVED");

        JsonNode recipients=ok(get("/api/tasks/recipients/all"),leader,null);
        assertThat(recipients.path("items").size()).isEqualTo(3);
        assertThat(recipients.path("items").get(0).path("id").asLong()).isEqualTo(managerId);
        assertThat(recipients.path("items").get(0).path("realName").asText()).isEqualTo("manager");
        assertThat(recipients.path("items").get(1).path("id").asLong()).isEqualTo(employeeId);
        assertThat(recipients.path("items").get(2).path("id").asLong()).isEqualTo(otherId);

        JsonNode overview=ok(get("/api/tasks/subordinates/overview"),leader,null);
        assertThat(overview.path("total").asInt()).isEqualTo(1);
        JsonNode summary=overview.path("items").get(0);
        assertThat(summary.path("userId").asLong()).isEqualTo(employeeId);
        assertThat(summary.path("departmentId").asLong()).isEqualTo(departmentId);
        assertThat(summary.path("departmentName").asText()).isEqualTo("研发部");
        assertThat(summary.path("teamName").asText()).isEqualTo("移动组");
        assertThat(summary.path("total").asInt()).isEqualTo(1);
        JsonNode assignment=summary.path("tasks").get(0);
        assertThat(assignment.path("taskId").asLong()).isEqualTo(taskId);
        assertThat(assignment.path("assignmentId").asLong()).isPositive();
        assertThat(assignment.path("executionStatus").asText()).isEqualTo("NOT_STARTED");
        assertThat(assignment.path("sender").path("id").asLong()).isEqualTo(leaderId);
        assertThat(assignment.path("assignee").path("realName").asText()).isEqualTo("member");

        assertThat(ok(get("/api/tasks/subordinates/overview"),employee,null).path("total").asInt()).isZero();
        response(get("/api/tasks/recipients/all"),employee,null,403);
        assertThat(ok(get("/api/tasks/received"),employee,null).path("items").size()).isEqualTo(1);
    }

    @Test void progressHistoryAndChangeRequestApprovalWorkOnCloudDatabase() throws Exception {
        long taskId=ok(post("/api/tasks"),leader,task("2026-10-29T09:30:00","2026-10-29T17:45:00",employeeId)).path("taskId").asLong();
        long assignmentId=ok(get("/api/tasks/received"),employee,null).path("items").get(0).path("assignmentId").asLong();

        JsonNode progress=ok(post("/api/tasks/assignments/"+assignmentId+"/progress-updates"),employee,
                Map.of("status","IN_PROGRESS","progressPercent",40,"note","已开始处理"));
        assertThat(progress.path("progressPercent").asInt()).isEqualTo(40);
        assertThat(progress.path("authorName").asText()).isEqualTo("member");
        assertThat(progress.path("createdAt").asText()).isNotBlank();

        response(post("/api/tasks/assignments/"+assignmentId+"/progress-updates"),employee,
                Map.of("status","IN_PROGRESS","progressPercent",20,"note","不允许倒退"),409);
        response(post("/api/tasks/assignments/"+assignmentId+"/progress-updates"),employee,
                Map.of("status","BLOCKED","progressPercent",50),400);

        JsonNode history=ok(get("/api/tasks/assignments/"+assignmentId+"/progress-updates"),employee,null);
        assertThat(history.path("items").size()).isEqualTo(1);
        assertThat(history.path("items").get(0).path("note").asText()).isEqualTo("已开始处理");
        assertThat(ok(get("/api/tasks/subordinates/"+employeeId+"/assignments/"+assignmentId+"/progress-updates"),leader,null)
                .path("items").size()).isEqualTo(1);
        response(get("/api/tasks/subordinates/"+employeeId+"/assignments/"+assignmentId+"/progress-updates"),other,null,403);
        assertThat(ok(get("/api/tasks/received"),employee,null).path("items").get(0).path("progressPercent").asInt())
                .isEqualTo(40);

        JsonNode change=ok(post("/api/tasks/"+taskId+"/change-requests"),leader,Map.of(
                "action","UPDATE","name","改名后的任务","details","更新后的完整说明",
                "startDate","2026-10-29T10:00:00","deadline","2026-10-29T18:00:00",
                "urgency","URGENT","taskType","DEVELOPMENT","assigneeIds",List.of(employeeId)));
        assertThat(change.path("status").asText()).isEqualTo("PENDING");
        assertThat(ok(get("/api/tasks/dispatched"),leader,null).path("items").get(0).path("changePending").asBoolean())
                .isTrue();
        assertThat(ok(get("/api/tasks/change-requests/reviewable"),manager,null)
                .path("items").get(0).path("id").asLong()).isEqualTo(change.path("id").asLong());

        JsonNode approved=ok(post("/api/tasks/change-requests/"+change.path("id").asLong()+"/approve"),manager,
                Map.of("comment","同意修改"));
        assertThat(approved.path("status").asText()).isEqualTo("APPROVED");
        JsonNode detail=ok(get("/api/tasks/"+taskId),leader,null);
        assertThat(detail.path("name").asText()).isEqualTo("改名后的任务");
        assertThat(detail.path("taskType").asText()).isEqualTo("DEVELOPMENT");
        assertThat(detail.path("assignments").get(0).path("progressPercent").asInt()).isEqualTo(40);
    }

    @Test void deleteChangeRequestRequiresApprovalAndDailyItemsSyncPerUser() throws Exception {
        long taskId=ok(post("/api/tasks"),leader,task("2026-10-29T09:30:00","2026-10-29T17:45:00",employeeId)).path("taskId").asLong();
        JsonNode change=ok(post("/api/tasks/"+taskId+"/change-requests"),leader,Map.of("action","DELETE"));
        assertThat(change.path("status").asText()).isEqualTo("PENDING");
        assertThat(ok(get("/api/tasks/"+taskId),leader,null).path("name").asText()).isEqualTo("分钟任务");

        JsonNode rejected=ok(post("/api/tasks/change-requests/"+change.path("id").asLong()+"/reject"),manager,
                Map.of("comment","暂不删除"));
        assertThat(rejected.path("status").asText()).isEqualTo("REJECTED");
        assertThat(ok(get("/api/tasks/"+taskId),leader,null).path("name").asText()).isEqualTo("分钟任务");

        JsonNode second=ok(post("/api/tasks/"+taskId+"/change-requests"),leader,Map.of("action","DELETE"));
        ok(post("/api/tasks/change-requests/"+second.path("id").asLong()+"/approve"),manager,Map.of());
        response(get("/api/tasks/"+taskId),leader,null,404);

        JsonNode daily=ok(post("/api/daily-items"),employee,Map.of(
                "date",today.toString(),"title","整理移动端验收截图","note","下班前完成"));
        assertThat(daily.path("completed").asBoolean()).isFalse();
        assertThat(ok(get("/api/daily-items"),employee,null).path("items").get(0).path("title").asText())
                .isEqualTo("整理移动端验收截图");
        assertThat(ok(get("/api/daily-items"),leader,null).path("items").size()).isZero();
        JsonNode updated=ok(put("/api/daily-items/"+daily.path("id").asLong()),employee,
                Map.of("completed",true));
        assertThat(updated.path("completed").asBoolean()).isTrue();
        ok(delete("/api/daily-items/"+daily.path("id").asLong()),employee,null);
        assertThat(ok(get("/api/daily-items"),employee,null).path("items").size()).isZero();
    }

    private void at(LocalDateTime time) { instant=time.atZone(ZONE).toInstant(); }
    private long user(String name,String role,Long department,Long team) {
        return jdbc.queryForObject("INSERT INTO users(username,password_hash,real_name,role_code,department_id,team_id) VALUES (?,?,?,?,?,?) RETURNING id",
                Long.class,name,passwords.encode(PASSWORD),name,role,department,team);
    }
    private Map<String,Object> task(String start,String end,long user) {return Map.of("name","分钟任务","details","完整说明","startDate",start,"deadline",end,"urgency","NOT_URGENT","assigneeIds",List.of(user));}
    private Map<String,Object> review(String decision) {return Map.of("decision",decision,"identityVerified",true,"currentPassword",PASSWORD);}
    private long changeRequest() throws Exception {
        ok(post("/api/account/password-change-requests"),employee,Map.of());
        return jdbc.queryForObject("SELECT max(id) FROM password_requests WHERE user_id=? AND kind='CHANGE'",Long.class,employeeId);
    }
    private long resetRequest() throws Exception {
        ok(post("/api/auth/password-reset-requests"),null,Map.of("username","member"));
        return jdbc.queryForObject("SELECT max(id) FROM password_requests WHERE user_id=? AND kind='RESET'",Long.class,employeeId);
    }
    private JsonNode login(String name,String pass) throws Exception {return ok(post("/api/auth/login"),null,Map.of("username",name,"password",pass));}
    private JsonNode ok(MockHttpServletRequestBuilder request,String token,Object body) throws Exception {return response(request,token,body,200).path("data");}
    private JsonNode response(MockHttpServletRequestBuilder request,String token,Object body,int expected) throws Exception {
        if(token!=null) request.header("Authorization","Bearer "+token);
        if(body!=null) request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        var result=mvc.perform(request).andReturn();
        if(expected!=0) assertThat(result.getResponse().getStatus()).as("HTTP 状态").isEqualTo(expected);
        JsonNode value=json.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
        assertThat(value.has("code") && value.path("code").isIntegralNumber()).isTrue();
        return value;
    }
    private void assertNoSecretInAudit(String... secrets) {
        String audit=jdbc.queryForList("SELECT action,object_type,object_id,detail FROM operation_audits").toString();
        for(String secret:secrets) assertThat(audit).doesNotContain(secret);
    }
}
