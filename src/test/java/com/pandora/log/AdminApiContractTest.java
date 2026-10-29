package com.pandora.log;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.*;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import com.fasterxml.jackson.databind.*;
import com.pandora.log.support.EmbeddedPostgresSupport;

/** 在独立 PostgreSQL 数据库内验证 SQL、事务、权限与前端契约，不接触业务数据库。 */
@SpringBootTest
@AutoConfigureMockMvc
class AdminApiContractTest extends EmbeddedPostgresSupport {
    private static final String URL = createDatabase("pandora_admin_api_test");
    private static final String PASSWORD = "test-initial-pass";
    @DynamicPropertySource static void database(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", () -> URL);
        r.add("spring.datasource.username", () -> "postgres"); r.add("spring.datasource.password", () -> "");
        r.add("app.jwt.secret", () -> "pandora-admin-test-secret-key-01234567890");
        r.add("app.admin.init-password", () -> "");
    }
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @Autowired PasswordEncoder passwords;
    private long admin, company, department, otherDepartment, team, otherTeam;
    private String token;

    @BeforeEach void fixtures() throws Exception {
        // URL 是本测试类创建的专用库；级联清理仅用于隔离用例，不用于开发/生产启动。
        jdbc.execute("TRUNCATE companies,users RESTART IDENTITY CASCADE");
        jdbc.execute("TRUNCATE operation_audits RESTART IDENTITY");
        jdbc.execute("ALTER SEQUENCE companies_id_seq RESTART WITH 41");
        admin = jdbc.queryForObject("INSERT INTO users(username,password_hash,real_name,role_code) VALUES ('admin',?,'验收管理员','ADMIN') RETURNING id", Long.class, passwords.encode(PASSWORD));
        company = jdbc.queryForObject("INSERT INTO companies(name) VALUES ('验收公司') RETURNING id", Long.class);
        department = jdbc.queryForObject("INSERT INTO departments(name,company_id) VALUES ('研发部',?) RETURNING id", Long.class, company);
        otherDepartment = jdbc.queryForObject("INSERT INTO departments(name,company_id) VALUES ('产品部',?) RETURNING id", Long.class, company);
        team = jdbc.queryForObject("INSERT INTO teams(name,department_id) VALUES ('同名团队',?) RETURNING id", Long.class, department);
        otherTeam = jdbc.queryForObject("INSERT INTO teams(name,department_id) VALUES ('同名团队',?) RETURNING id", Long.class, otherDepartment);
        token = login("admin", PASSWORD).path("data").path("accessToken").asText();
    }

    @Test void persistsPhoneIndependentUsernameAndPasswordHashWithoutCredentialResponses() throws Exception {
        Map<String,Object> body = user("custom_account", "EMPLOYEE", department, team);
        body.put("gender", "女"); body.put("idNumber", "110101200001010019");
        long id = ok(post("/api/users"), body).path("data").path("id").asLong();
        String hash = jdbc.queryForObject("SELECT password_hash FROM users WHERE id=?", String.class, id);
        assertThat(hash).isNotEqualTo(PASSWORD); assertThat(passwords.matches(PASSWORD, hash)).isTrue();
        JsonNode profile = ok(get("/api/users/" + id), null).path("data");
        assertThat(profile.path("username").asText()).isEqualTo("custom_account");
        assertThat(profile.path("phone").asText()).isEqualTo("13000000001");
        assertThat(profile.path("gender").asText()).isEqualTo("女");
        assertThat(profile.path("idNumber").asText()).isEqualTo("110101200001010019");
        assertThat(profile.has("password")).isFalse(); assertThat(profile.has("passwordHash")).isFalse();
        assertThat(login("custom_account", PASSWORD).path("code").asInt()).isZero();
        assertThat(login("13000000001", PASSWORD).path("code").asInt()).isEqualTo(40101);
        assertStatus(post("/api/users"), body, token, 409, 40906);
    }

    @Test void filtersAndPaginatesTeamMembersOnServerByStableId() throws Exception {
        String hash = passwords.encode(PASSWORD);
        for (int i=0; i<25; i++) jdbc.update("INSERT INTO users(username,password_hash,real_name,role_code,department_id,team_id) VALUES (?,?,?,'EMPLOYEE',?,?)",
                "member_"+i, hash, "成员"+i, department, team);
        ok(post("/api/users"), user("other_team", "EMPLOYEE", otherDepartment, otherTeam));
        JsonNode page = ok(get("/api/users").param("teamId", ""+team).param("page","3").param("size","10"), null).path("data");
        assertThat(page.path("total").asInt()).isEqualTo(25); assertThat(page.path("items").size()).isEqualTo(5);
        for (JsonNode row : page.path("items")) assertThat(row.path("teamId").asLong()).isEqualTo(team);
        assertThat(ok(get("/api/users").param("keyword","member_24"), null).path("data").path("total").asInt()).isEqualTo(1);
        assertThat(ok(get("/api/users").param("keyword","%"), null).path("data").path("total").asInt()).isZero();
        assertStatus(get("/api/users").param("role","UNKNOWN"), null, token, 400,40001);
        assertStatus(get("/api/users").param("page","abc"), null, token,400,40001);
    }

    @Test void rejectsNonAdminAndUnauthenticatedAccess() throws Exception {
        long id = ok(post("/api/users"), user("employee_a","EMPLOYEE",department,team)).path("data").path("id").asLong();
        String employee = login("employee_a",PASSWORD).path("data").path("accessToken").asText();
        for (String path : List.of("/api/users","/api/departments","/api/teams","/api/companies","/api/audits","/api/users/"+id)) {
            assertStatus(get(path),null,employee,403,40301);
            assertStatus(get(path),null,null,401,40102);
        }
        assertStatus(post("/api/users"),user("blocked","EMPLOYEE",department,team),employee,403,40301);
        assertStatus(post("/api/company-matters"),matter("09","18"),employee,403,40301);
        assertStatus(delete("/api/teams/"+team),null,employee,403,40301);
        assertThat(request(get("/api/company-matters"),null,employee).getResponse().getStatus()).isEqualTo(200);
    }

    @Test void validatesRoleOwnershipAndSynchronizesOwnerPointers() throws Exception {
        assertStatus(post("/api/users"),user("invalid_org","EMPLOYEE",department,otherTeam),token,400,40001);
        assertStatus(post("/api/users"),user("invalid_role","FOUNDER",department,null),token,400,40001);
        long leader = ok(post("/api/users"),user("leader_a","TEAM_LEADER",department,team)).path("data").path("id").asLong();
        assertThat(jdbc.queryForObject("SELECT leader_id FROM teams WHERE id=?",Long.class,team)).isEqualTo(leader);
        assertStatus(post("/api/users"),user("leader_b","TEAM_LEADER",department,team),token,409,40905);
        ok(put("/api/users/"+leader),Map.of("realName","原负责人","role","EMPLOYEE","departmentId",department,"teamId",team));
        assertThat(jdbc.queryForObject("SELECT leader_id FROM teams WHERE id=?",Long.class,team)).isNull();
        long manager = ok(post("/api/users"),user("manager_a","DEPT_MANAGER",department,null)).path("data").path("id").asLong();
        assertThat(jdbc.queryForObject("SELECT manager_id FROM departments WHERE id=?",Long.class,department)).isEqualTo(manager);
        assertStatus(post("/api/users"),user("manager_b","DEPT_MANAGER",department,null),token,409,40905);
        long founder = ok(post("/api/users"),user("founder_a","FOUNDER",null,null)).path("data").path("id").asLong();
        assertThat(jdbc.queryForObject("SELECT founder_id FROM companies WHERE id=?",Long.class,company)).isEqualTo(founder);
        assertStatus(post("/api/users"),user("founder_b","FOUNDER",null,null),token,409,40905);
    }

    @Test void replacesTeamLeaderAtomicallyAndPreventsConcurrentDuplicateOwners() throws Exception {
        long old = ok(post("/api/users"),user("old_leader","TEAM_LEADER",department,team)).path("data").path("id").asLong();
        long next = ok(post("/api/users"),user("new_leader","EMPLOYEE",department,team)).path("data").path("id").asLong();
        ok(put("/api/teams/"+team),Map.of("name","换负责人团队","departmentId",department,"leaderId",next));
        assertThat(ok(get("/api/users/"+old),null).path("data").path("role").asText()).isEqualTo("EMPLOYEE");
        assertThat(jdbc.queryForObject("SELECT leader_id FROM teams WHERE id=?",Long.class,team)).isEqualTo(next);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2), go = new CountDownLatch(1);
        try {
            List<Future<Integer>> futures = new ArrayList<>();
            for (String name : List.of("race_leader_a","race_leader_b")) futures.add(pool.submit(() -> {
                ready.countDown(); go.await(); return request(post("/api/users"),user(name,"TEAM_LEADER",otherDepartment,otherTeam),token).getResponse().getStatus();
            }));
            assertThat(ready.await(3,TimeUnit.SECONDS)).isTrue(); go.countDown();
            List<Integer> results = List.of(futures.get(0).get(10,TimeUnit.SECONDS),futures.get(1).get(10,TimeUnit.SECONDS));
            assertThat(results).containsExactlyInAnyOrder(200,409);
            assertThat(jdbc.queryForObject("SELECT count(*) FROM users WHERE role_code='TEAM_LEADER' AND team_id=?",Long.class,otherTeam)).isEqualTo(1);
        } finally { pool.shutdownNow(); }
    }

    @Test void resetsPasswordAndRevokesAccessAndRefreshSessions() throws Exception {
        long id = ok(post("/api/users"),user("reset_target","EMPLOYEE",department,team)).path("data").path("id").asLong();
        JsonNode session = login("reset_target",PASSWORD).path("data");
        ok(put("/api/users/"+id+"/password"),Map.of("password","replacement-pass"));
        assertStatus(get("/api/auth/me"),null,session.path("accessToken").asText(),401,40102);
        assertStatus(post("/api/auth/refresh"),Map.of("refreshToken",session.path("refreshToken").asText()),null,401,40102);
        assertThat(login("reset_target",PASSWORD).path("code").asInt()).isEqualTo(40101);
        assertThat(login("reset_target","replacement-pass").path("code").asInt()).isZero();
        assertStatus(put("/api/users/"+id+"/password"),Map.of("password","密".repeat(25)),token,400,40001);
    }

    @Test void disablesImmediatelyAndDoesNotResurrectOldTokensOnReenable() throws Exception {
        long id = ok(post("/api/users"),user("status_target","EMPLOYEE",department,team)).path("data").path("id").asLong();
        String old = login("status_target",PASSWORD).path("data").path("accessToken").asText();
        ok(patch("/api/users/"+id+"/status"),Map.of("status",0));
        assertStatus(get("/api/auth/me"),null,old,401,40104);
        assertThat(login("status_target",PASSWORD).path("code").asInt()).isEqualTo(40104);
        assertThat(ok(get("/api/users").param("status","0"),null).path("data").path("total").asInt()).isEqualTo(1);
        ok(patch("/api/users/"+id+"/status"),Map.of("status",1));
        assertStatus(get("/api/auth/me"),null,old,401,40102);
        assertThat(login("status_target",PASSWORD).path("code").asInt()).isZero();
    }

    @Test void protectsLastAdminAndRejectsImmutableOrUnknownFields() throws Exception {
        assertStatus(patch("/api/users/"+admin+"/status"),Map.of("status",0),token,409,40908);
        assertStatus(put("/api/users/"+admin),Map.of("realName","管理员","role","FOUNDER"),token,409,40908);
        assertStatus(put("/api/users/"+admin),Map.of("realName","管理员","role","ADMIN","username","changed"),token,400,40001);
        assertStatus(post("/api/users"),user("BadName","EMPLOYEE",department,team),token,400,40001);
        assertStatus(patch("/api/users/"+admin+"/status"),Map.of("status",1.5),token,400,40001);
        Map<String,Object> malformed=user("float_id","EMPLOYEE",department,team);
        malformed.put("teamId",team+0.5); assertStatus(post("/api/users"),malformed,token,400,40001);
        assertStatus(get("/api/users/999999"),null,token,404,40400);
    }

    @Test void maintainsOrganizationsAndRefusesDeletingOrMovingPopulatedUnits() throws Exception {
        assertThat(ok(get("/api/companies"),null).path("data").get(0).path("id").asLong()).isEqualTo(41);
        ok(put("/api/companies/"+company),Map.of("name","更新公司名"));
        assertThat(ok(get("/api/companies/"+company),null).path("data").path("name").asText()).isEqualTo("更新公司名");
        long d = ok(post("/api/departments"),Map.of("name","新部门","companyId",company,"description","部门介绍")).path("data").path("id").asLong();
        long t = ok(post("/api/teams"),Map.of("name","新团队","departmentId",d,"description","团队介绍")).path("data").path("id").asLong();
        assertThat(ok(get("/api/departments/"+d),null).path("data").path("description").asText()).isEqualTo("部门介绍");
        ok(put("/api/teams/"+t),Map.of("name","重命名团队","departmentId",d,"description","更新介绍"));
        assertThat(ok(get("/api/teams/"+t),null).path("data").path("description").asText()).isEqualTo("更新介绍");
        assertStatus(delete("/api/departments/"+d),null,token,409,40904);
        long uid=ok(post("/api/users"),user("org_member","EMPLOYEE",d,t)).path("data").path("id").asLong();
        assertStatus(delete("/api/teams/"+t),null,token,409,40904);
        assertStatus(put("/api/teams/"+t),Map.of("name","重命名团队","departmentId",department),token,409,40904);
        ok(put("/api/users/"+uid),Map.of("realName","转组成员","role","EMPLOYEE","departmentId",department,"teamId",team));
        ok(delete("/api/teams/"+t),null); ok(delete("/api/departments/"+d),null);
        assertStatus(post("/api/departments"),Map.of("name","研发部","companyId",company),token,409,40907);
    }

    @Test void preservesLegacyMatterNullsAndPersistsShanghaiHours() throws Exception {
        jdbc.update("INSERT INTO company_matters(title,content,sort_order,updated_by) VALUES ('历史事项','旧记录',0,?)",admin);
        assertThat(ok(get("/api/company-matters"),null).path("data").path("items").get(0).path("startDate").isNull()).isTrue();
        long id=ok(post("/api/company-matters"),matter("09","09")).path("data").path("id").asLong();
        ok(put("/api/company-matters/"+id),matter("09","18"));
        JsonNode rows=ok(get("/api/company-matters"),null).path("data").path("items");
        assertThat(rows.get(1).path("startDate").asText()).isEqualTo("2026-10-29T09:00:00+08:00");
        assertThat(rows.get(1).path("deadline").asText()).isEqualTo("2026-10-29T18:00:00+08:00");
        assertThat(jdbc.queryForObject("SELECT deadline-start_date=interval '9 hours' FROM company_matters WHERE id=?",Boolean.class,id)).isTrue();
    }

    @Test void rejectsInvalidMatterDatesOffsetsFractionsAndReverseHours() throws Exception {
        for(String date:List.of("2026-10-29","2026-02-30T09:00:00+08:00","2026-10-29T09:01:00+08:00","2026-10-29T09:00:00.001+08:00","2026-10-29T01:00:00Z")) {
            Map<String,Object> r=matter("09","18");r.put("startDate",date);assertStatus(post("/api/company-matters"),r,token,400,40001);
        }
        assertStatus(post("/api/company-matters"),matter("09","08"),token,400,40001);
        Map<String,Object> fractional=matter("09","18"); fractional.put("sortOrder",1.5);
        assertStatus(post("/api/company-matters"),fractional,token,400,40001);
        Map<String,Object> r=matter("23","23");r.put("deadline","2026-10-30T00:00:00+08:00");ok(post("/api/company-matters"),r);
    }

    @Test void auditsSuccessAndFailuresWithoutPasswordsOrPrivatePayloads() throws Exception {
        ok(post("/api/users"),user("audited_user","EMPLOYEE",department,team));
        assertStatus(post("/api/users"),user("audited_user","EMPLOYEE",department,team),token,409,40906);
        JsonNode result=ok(get("/api/audits").param("actor","admin").param("size","1"),null).path("data");
        assertThat(result.path("total").asInt()).isEqualTo(2);assertThat(result.path("items").size()).isEqualTo(1);
        assertThat(result.path("items").get(0).path("result").asText()).isEqualTo("FAILED");
        assertThat(ok(get("/api/audits").param("action","创建用户"),null).path("data").path("total").asInt()).isEqualTo(2);
        String details=jdbc.queryForObject("SELECT string_agg(coalesce(detail,''),'') FROM operation_audits",String.class);
        assertThat(details).doesNotContain(PASSWORD,"13000000001","audited_user");
        assertStatus(get("/api/audits").param("from","wrong"),null,token,400,40001);
    }

    private Map<String,Object> user(String name,String role,Long dep,Long group) {
        Map<String,Object> r=new HashMap<>();r.put("username",name);r.put("phone","13000000001");r.put("password",PASSWORD);
        r.put("realName","验收成员");r.put("role",role);r.put("departmentId",dep);r.put("teamId",group);return r;
    }
    private Map<String,Object> matter(String start,String end) {
        return new HashMap<>(Map.of("title","事项验收","content","整点入库","sortOrder",1,"startDate","2026-10-29T"+start+":00:00+08:00","deadline","2026-10-29T"+end+":00:00+08:00"));
    }
    private MvcResult request(MockHttpServletRequestBuilder request,Object body,String access) throws Exception {
        if(access!=null)request.header(HttpHeaders.AUTHORIZATION,"Bearer "+access);
        if(body!=null)request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        return mvc.perform(request).andReturn();
    }
    private JsonNode read(MvcResult result) throws Exception { return json.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8)); }
    private JsonNode ok(MockHttpServletRequestBuilder request,Object body) throws Exception {
        MvcResult r=request(request,body,token);assertThat(r.getResponse().getStatus()).isEqualTo(200);
        JsonNode response=read(r);assertThat(response.path("code").asInt()).isZero();return response;
    }
    private void assertStatus(MockHttpServletRequestBuilder request,Object body,String access,int status,int code) throws Exception {
        MvcResult r=request(request,body,access);assertThat(r.getResponse().getStatus()).isEqualTo(status);assertThat(read(r).path("code").asInt()).isEqualTo(code);
    }
    private JsonNode login(String username,String password) throws Exception {
        return read(request(post("/api/auth/login"),Map.of("username",username,"password",password),null));
    }
}
