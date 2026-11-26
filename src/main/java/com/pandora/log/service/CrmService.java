package com.pandora.log.service;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.CrmDtos.ActivityDto;
import com.pandora.log.dto.CrmDtos.BenefitDto;
import com.pandora.log.dto.CrmDtos.CreateActivityRequest;
import com.pandora.log.dto.CrmDtos.CreateCustomerRequest;
import com.pandora.log.dto.CrmDtos.CustomerDto;
import com.pandora.log.dto.CrmDtos.RevenueSummaryDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class CrmService {
    private static final Set<String> CATEGORIES = Set.of("PERSON", "COMPANY");
    private static final Set<String> ACTIVITY_KINDS =
            Set.of("MALL", "PERFORMANCE", "BANQUET", "VISIT", "SALON", "SERVICE", "OTHER");
    private static final Set<String> ACTIVITY_STATUSES =
            Set.of("PENDING", "IN_PROGRESS", "COMPLETED", "PLANNED", "CANCELLED");
    private static final String CUSTOMER_COLUMNS =
            "c.id,c.name,c.category,c.business,c.member_tier,c.member_expires_at,c.masked_contact," +
            "c.owner_id,o.real_name AS owner_name,c.department_id,c.team_id,c.remark," +
            "c.linked_mall_member_id,c.linked_ticket_card_id,c.sensitive," +
            "COALESCE(card.used_count,0) AS annual_used,COALESCE(card.total_count,0) AS annual_total ";

    private final JdbcTemplate jdbc;
    private final CurrentUserContext context;
    private final AuditTrail audit;

    public CrmService(JdbcTemplate jdbc, CurrentUserContext context, AuditTrail audit) {
        this.jdbc = jdbc;
        this.context = context;
        this.audit = audit;
    }

    public PageResult<CustomerDto> customers(String keyword, String category, String business,
            Integer page, Integer size) {
        CurrentUser user = require("crm:read");
        PageQuery pq = PageQuery.of(page, size);
        Scope scope = customerScope(user, "c");
        StringBuilder where = new StringBuilder(" WHERE ").append(scope.sql());
        List<Object> args = new ArrayList<>(scope.args());
        if (keyword != null && !keyword.isBlank()) {
            where.append(" AND (c.name ILIKE ? OR CAST(c.id AS TEXT)=? OR c.remark ILIKE ?)");
            String pattern = "%" + keyword.trim() + "%";
            args.add(pattern);
            args.add(keyword.trim());
            args.add(pattern);
        }
        if (category != null && !category.isBlank()) {
            String value = upper(category);
            if (!CATEGORIES.contains(value)) invalid("category 非法");
            where.append(" AND c.category=?");
            args.add(value);
        }
        if (business != null && !business.isBlank()) {
            where.append(" AND c.business=?");
            args.add(business.trim());
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM crm_customers c" + where,
                Long.class, args.toArray());
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(pq.size());
        pageArgs.add(pq.offset());
        List<CustomerDto> items = jdbc.query(
                "SELECT " + CUSTOMER_COLUMNS + customerJoins() + where +
                        " ORDER BY c.id DESC LIMIT ? OFFSET ?",
                customerMapper(), pageArgs.toArray());
        return new PageResult<>(total == null ? 0 : total, pq.page(), pq.size(), items);
    }

    @Transactional
    public CustomerDto createCustomer(CreateCustomerRequest request) {
        CurrentUser user = require("crm:write");
        if (request == null) invalid("客户资料不能为空");
        String name = required(request.name(), 200, "客户名称");
        String category = upper(request.category());
        if (!CATEGORIES.contains(category)) invalid("category 非法");
        String business = required(request.business(), 64, "业务类型");
        String tier = optional(request.memberTier(), 64, "普通客户");
        String remark = optional(request.remark(), 1000, "");
        String maskedContact = optional(request.maskedContact(), 100, "");

        boolean mayAssign = "FOUNDER".equals(user.roleCode()) || user.hasPermission("crm:all:read");
        Long ownerId = mayAssign && request.ownerId() != null ? request.ownerId() : user.id();
        UserOrg owner = requireActiveUser(ownerId);
        Long departmentId = mayAssign && request.departmentId() != null
                ? request.departmentId() : owner.departmentId();
        Long teamId = mayAssign && request.teamId() != null ? request.teamId() : owner.teamId();
        validateOrganization(departmentId, teamId);
        boolean sensitive = Boolean.TRUE.equals(request.sensitive());
        if (sensitive && !user.hasPermission("crm:sensitive:read")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        Long id = jdbc.queryForObject(
                "INSERT INTO crm_customers(name,category,business,member_tier,member_expires_at," +
                        "masked_contact,owner_id,department_id,team_id,remark,linked_mall_member_id," +
                        "linked_ticket_card_id,sensitive) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?) RETURNING id",
                Long.class, name, category, business, tier, request.memberExpiresAt(), maskedContact,
                ownerId, departmentId, teamId, remark, blank(request.linkedMallMemberId()),
                blank(request.linkedTicketCardId()), sensitive);
        audit.success("新增客户", "CRM_CUSTOMER", id, AuditTrail.USER,
                "创建客户档案", List.of());
        return requireVisibleCustomer(id, user);
    }

    public List<BenefitDto> benefits(Long customerId) {
        CurrentUser user = require("crm:read");
        requireVisibleCustomer(customerId, user);
        return jdbc.query("SELECT id,customer_id,title,total_count,used_count,service_status " +
                        "FROM crm_benefits WHERE customer_id=? ORDER BY id",
                benefitMapper(), customerId);
    }

    @Transactional
    public BenefitDto redeem(Long benefitId) {
        CurrentUser user = require("crm:write");
        List<BenefitRow> rows = jdbc.query(
                "SELECT id,customer_id,total_count,used_count,service_status FROM crm_benefits " +
                        "WHERE id=? FOR UPDATE",
                (rs, i) -> new BenefitRow(rs.getLong("id"), rs.getLong("customer_id"),
                        rs.getInt("total_count"), rs.getInt("used_count"), rs.getString("service_status")),
                benefitId);
        if (rows.isEmpty()) throw new BusinessException(ErrorCode.RESOURCE_NOT_VISIBLE);
        BenefitRow row = rows.get(0);
        requireVisibleCustomer(row.customerId(), user);
        if (row.used() >= row.total() || "CANCELLED".equals(row.status())) {
            throw new BusinessException(ErrorCode.CRM_BENEFIT_EXHAUSTED);
        }
        int used = row.used() + 1;
        String status = used >= row.total() ? "COMPLETED" : "IN_PROGRESS";
        jdbc.update("UPDATE crm_benefits SET used_count=?,service_status=?,updated_at=now() WHERE id=?",
                used, status, benefitId);
        audit.success("核销会员权益", "CRM_BENEFIT", benefitId, AuditTrail.USER,
                "权益核销成功", List.of());
        return jdbc.queryForObject("SELECT id,customer_id,title,total_count,used_count,service_status " +
                "FROM crm_benefits WHERE id=?", benefitMapper(), benefitId);
    }

    public List<ActivityDto> activities(Long customerId) {
        CurrentUser user = require("crm:read");
        requireVisibleCustomer(customerId, user);
        return loadActivities("a.customer_id=?", new Object[] {customerId});
    }

    @Transactional
    public ActivityDto createActivity(CreateActivityRequest request) {
        CurrentUser user = require("crm:write");
        if (request == null || request.customerId() == null || request.date() == null) {
            invalid("客户和活动日期不能为空");
        }
        requireVisibleCustomer(request.customerId(), user);
        String kind = upper(request.kind());
        String status = upper(request.status());
        if (!ACTIVITY_KINDS.contains(kind) || !ACTIVITY_STATUSES.contains(status)) {
            invalid("活动类型或状态非法");
        }
        String title = required(request.title(), 200, "活动标题");
        String note = optional(request.note(), 1000, "");
        long revenue = request.revenueAmountFen() == null ? 0 : request.revenueAmountFen();
        if (revenue < 0) invalid("营收金额不能为负数");
        LinkedHashSet<Long> participants = new LinkedHashSet<>(
                request.participantIds() == null ? List.of() : request.participantIds());
        if (!participants.isEmpty()) {
            String marks = String.join(",", Collections.nCopies(participants.size(), "?"));
            Long active = jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE status='ACTIVE' AND id IN (" +
                    marks + ")", Long.class, participants.toArray());
            if (active == null || active != participants.size()) invalid("参与人员包含无效或停用账号");
        }
        Long id = jdbc.queryForObject(
                "INSERT INTO crm_activities(customer_id,kind,title,status,activity_date,owner_id,note,revenue_amount_fen) " +
                        "VALUES (?,?,?,?,?,?,?,?) RETURNING id",
                Long.class, request.customerId(), kind, title, status, request.date(),
                user.id(), note, revenue);
        for (Long participant : participants) {
            jdbc.update("INSERT INTO crm_activity_participants(activity_id,employee_id) VALUES (?,?)", id, participant);
        }
        audit.success("新增客户业务记录", "CRM_ACTIVITY", id, AuditTrail.USER,
                "创建业务活动", List.of());
        return loadActivities("a.id=?", new Object[] {id}).get(0);
    }

    public RevenueSummaryDto revenue(String month) {
        require("crm:revenue:read");
        YearMonth parsed;
        try {
            parsed = YearMonth.parse(month);
        } catch (DateTimeParseException | NullPointerException exception) {
            invalid("month 必须为 YYYY-MM");
            return null;
        }
        LocalDate from = parsed.atDay(1);
        LocalDate to = parsed.plusMonths(1).atDay(1);
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT kind,COALESCE(SUM(revenue_amount_fen),0) AS amount,COUNT(*) AS orders " +
                        "FROM crm_activities WHERE activity_date>=? AND activity_date<? AND status='COMPLETED' " +
                        "GROUP BY kind ORDER BY kind", from, to);
        Map<String, Long> byBusiness = new LinkedHashMap<>();
        long total = 0;
        long count = 0;
        for (Map<String, Object> row : rows) {
            long amount = ((Number) row.get("amount")).longValue();
            long orders = ((Number) row.get("orders")).longValue();
            byBusiness.put(String.valueOf(row.get("kind")), amount);
            total += amount;
            count += orders;
        }
        return new RevenueSummaryDto(parsed.toString(), total, count, byBusiness);
    }

    List<ActivityDto> loadActivities(String condition, Object[] args) {
        List<ActivityDto> base = jdbc.query(
                "SELECT a.id,a.customer_id,a.kind,a.title,a.status,a.activity_date,a.owner_id," +
                        "u.real_name AS owner_name,a.note FROM crm_activities a " +
                        "JOIN users u ON u.id=a.owner_id WHERE " + condition +
                        " ORDER BY a.activity_date DESC,a.id DESC",
                (rs, i) -> new ActivityDto(rs.getLong("id"), rs.getLong("customer_id"),
                        rs.getString("kind"), rs.getString("title"), rs.getString("status"),
                        rs.getObject("activity_date", LocalDate.class), rs.getString("owner_name"),
                        rs.getString("note"), List.of(), List.of()), args);
        List<ActivityDto> result = new ArrayList<>();
        for (ActivityDto activity : base) {
            List<Participant> people = jdbc.query(
                    "SELECT p.employee_id,u.real_name FROM crm_activity_participants p " +
                            "JOIN users u ON u.id=p.employee_id WHERE p.activity_id=? ORDER BY p.employee_id",
                    (rs, i) -> new Participant(rs.getLong(1), rs.getString(2)), activity.id());
            result.add(new ActivityDto(activity.id(), activity.customerId(), activity.kind(), activity.title(),
                    activity.status(), activity.date(), activity.ownerName(), activity.note(),
                    people.stream().map(Participant::id).toList(),
                    people.stream().map(Participant::name).toList()));
        }
        return result;
    }

    CustomerDto requireVisibleCustomer(Long id, CurrentUser user) {
        if (id == null) throw new BusinessException(ErrorCode.RESOURCE_NOT_VISIBLE);
        Scope scope = customerScope(user, "c");
        List<Object> args = new ArrayList<>();
        args.add(id);
        args.addAll(scope.args());
        List<CustomerDto> rows = jdbc.query("SELECT " + CUSTOMER_COLUMNS + customerJoins() +
                " WHERE c.id=? AND " + scope.sql(), customerMapper(), args.toArray());
        if (rows.isEmpty()) throw new BusinessException(ErrorCode.RESOURCE_NOT_VISIBLE);
        return rows.get(0);
    }

    Scope customerScope(CurrentUser user, String alias) {
        List<String> conditions = new ArrayList<>();
        List<Object> args = new ArrayList<>();
        if (!user.hasPermission("crm:sensitive:read")) conditions.add(alias + ".sensitive=false");
        if (!"FOUNDER".equals(user.roleCode()) && !user.hasPermission("crm:all:read")) {
            switch (user.roleCode()) {
                case "DEPT_MANAGER" -> {
                    conditions.add(alias + ".department_id=?");
                    args.add(user.departmentId());
                }
                case "TEAM_LEADER" -> {
                    conditions.add(alias + ".team_id=?");
                    args.add(user.teamId());
                }
                default -> {
                    conditions.add(alias + ".owner_id=?");
                    args.add(user.id());
                }
            }
        }
        return new Scope(conditions.isEmpty() ? "TRUE" : String.join(" AND ", conditions), args);
    }

    private String customerJoins() {
        return "FROM crm_customers c JOIN users o ON o.id=c.owner_id " +
                "LEFT JOIN LATERAL (SELECT COALESCE(SUM(used_count),0)::int AS used_count," +
                "COALESCE(SUM(total_count),0)::int AS total_count FROM crm_benefits b " +
                "WHERE b.customer_id=c.id AND b.annual_card=true) card ON true";
    }

    private RowMapper<CustomerDto> customerMapper() {
        return (rs, i) -> new CustomerDto(rs.getLong("id"), rs.getString("name"),
                rs.getString("category"), rs.getString("business"), rs.getString("member_tier"),
                rs.getObject("member_expires_at", LocalDate.class), rs.getString("masked_contact"),
                rs.getString("owner_name"), rs.getString("remark"),
                rs.getString("linked_mall_member_id"), rs.getString("linked_ticket_card_id"),
                rs.getLong("owner_id"), nullableLong(rs, "department_id"), nullableLong(rs, "team_id"),
                rs.getInt("annual_used"), rs.getInt("annual_total"), rs.getBoolean("sensitive"));
    }

    private RowMapper<BenefitDto> benefitMapper() {
        return (rs, i) -> new BenefitDto(rs.getLong("id"), rs.getLong("customer_id"),
                rs.getString("title"), rs.getInt("total_count"), rs.getInt("used_count"),
                rs.getString("service_status"));
    }

    private CurrentUser require(String permission) {
        CurrentUser user = context.require();
        if (!user.hasPermission(permission)) throw new BusinessException(ErrorCode.FORBIDDEN);
        return user;
    }

    private UserOrg requireActiveUser(Long id) {
        List<UserOrg> rows = jdbc.query("SELECT department_id,team_id FROM users WHERE id=? AND status='ACTIVE'",
                (rs, i) -> new UserOrg(nullableLong(rs, "department_id"), nullableLong(rs, "team_id")), id);
        if (rows.isEmpty()) invalid("负责人不存在或已停用");
        return rows.get(0);
    }

    private void validateOrganization(Long departmentId, Long teamId) {
        if (teamId == null) {
            if (departmentId != null && !Boolean.TRUE.equals(jdbc.queryForObject(
                    "SELECT EXISTS(SELECT 1 FROM departments WHERE id=?)", Boolean.class, departmentId))) {
                invalid("归属部门不存在");
            }
            return;
        }
        if (departmentId == null || !Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM teams WHERE id=? AND department_id=?)",
                Boolean.class, teamId, departmentId))) invalid("团队与部门不匹配");
    }

    private static Long nullableLong(java.sql.ResultSet rs, String column) throws java.sql.SQLException {
        return rs.getObject(column) == null ? null : rs.getLong(column);
    }

    private static String required(String value, int max, String label) {
        String clean = value == null ? "" : value.trim();
        if (clean.isEmpty() || clean.length() > max) invalid(label + "不能为空且长度不能超过 " + max);
        return clean;
    }

    private static String optional(String value, int max, String fallback) {
        String clean = value == null ? fallback : value.trim();
        if (clean.length() > max) invalid("字段长度不能超过 " + max);
        return clean;
    }

    private static String upper(String value) {
        return value == null ? "" : value.trim().toUpperCase();
    }

    private static String blank(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static void invalid(String message) {
        throw new BusinessException(ErrorCode.VALIDATION_FAILED, message);
    }

    record Scope(String sql, List<Object> args) {
    }
    private record UserOrg(Long departmentId, Long teamId) {
    }
    private record BenefitRow(Long id, Long customerId, int total, int used, String status) {
    }
    private record Participant(Long id, String name) {
    }
}
