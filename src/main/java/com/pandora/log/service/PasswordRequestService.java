package com.pandora.log.service;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.pandora.log.common.*;
import com.pandora.log.dto.PasswordDtos.*;
import com.pandora.log.mapper.UserMapper;
import com.pandora.log.security.CurrentUserContext;
import com.pandora.log.security.PasswordService;
import com.pandora.log.security.TokenHashService;

/** 密码审批只授权一次操作，不保存申请人的新密码；恢复凭据只保存摘要。 */
@Service
public class PasswordRequestService {
    private static final Set<String> STATUSES = Set.of("PENDING","APPROVED","REJECTED","CONSUMED","EXPIRED","CANCELLED");
    private static final RowMapper<RequestRow> MAPPER = (rs,n) -> new RequestRow(rs.getLong("id"),
            rs.getLong("user_id"),rs.getString("kind"),rs.getString("status"),rs.getInt("auth_version"),
            rs.getObject("expires_at",OffsetDateTime.class));
    private final JdbcTemplate jdbc;
    private final AdminSupport support;
    private final CurrentUserContext context;
    private final PasswordService passwords;
    private final PasswordRequestLimiter limiter;
    private final UserMapper users;
    private final Clock clock;

    public PasswordRequestService(JdbcTemplate jdbc, AdminSupport support, CurrentUserContext context,
            PasswordService passwords, PasswordRequestLimiter limiter, UserMapper users, Clock clock) {
        this.jdbc=jdbc; this.support=support; this.context=context; this.passwords=passwords;
        this.limiter=limiter; this.users=users; this.clock=clock;
    }

    @Transactional
    public Accepted requestReset(String username, String ip) {
        String name = username.trim();
        if (limiter.allow("reset-request",name,ip)) {
            support.lock(); expire();
            List<Long> ids = jdbc.queryForList("INSERT INTO password_requests(user_id,kind,auth_version,created_at,expires_at) "
                    + "SELECT id,'RESET',auth_version,?,? FROM users WHERE username=? AND status<>'DISABLED' "
                    + "ON CONFLICT(user_id,kind) WHERE status IN ('PENDING','APPROVED') DO NOTHING RETURNING id",
                    Long.class, now(), now().plusHours(24), name);
            if (!ids.isEmpty()) audit(null,"申请找回密码",ids.get(0));
        }
        // 不返回账号是否存在、是否停用、重复申请或限流命中等信息。
        return new Accepted("如果账号可用，申请已受理，请联系管理员完成身份核验。");
    }

    @Transactional
    public StatusDto requestChange() {
        CurrentUser user = context.require(); support.lock(); expire();
        if (support.exists("SELECT EXISTS(SELECT 1 FROM password_requests WHERE user_id=? AND kind='CHANGE' "
                + "AND status IN ('PENDING','APPROVED'))", user.id())) {
            throw new BusinessException(ErrorCode.PASSWORD_REQUEST_CONFLICT);
        }
        OffsetDateTime expiry = now().plusHours(24);
        Long id = jdbc.queryForObject("INSERT INTO password_requests(user_id,kind,auth_version,created_at,expires_at) "
                + "SELECT id,'CHANGE',auth_version,?,? FROM users WHERE id=? RETURNING id",Long.class,now(),expiry,user.id());
        audit(user.id(),"申请修改密码",id);
        return new StatusDto("PENDING",expiry);
    }

    public StatusDto changeStatus() {
        Long user = context.require().id();
        List<RequestRow> rows = jdbc.query("SELECT * FROM password_requests WHERE user_id=? AND kind='CHANGE' "
                + "ORDER BY id DESC LIMIT 1",MAPPER,user);
        if (rows.isEmpty()) return new StatusDto("NONE",null);
        RequestRow row=rows.get(0);
        String status = effective(row);
        return Set.of("PENDING","APPROVED","REJECTED").contains(status)
                ? new StatusDto(status,row.expiresAt()) : new StatusDto("NONE",null);
    }

    public PageResult<RequestDto> list(String status, String kind, Integer page, Integer size) {
        support.require("user:manage");
        if (status!=null && !STATUSES.contains(status)) AdminSupport.invalid("申请状态非法");
        if (kind!=null && !Set.of("CHANGE","RESET").contains(kind)) AdminSupport.invalid("申请类型非法");
        PageQuery pq=PageQuery.of(page,size);
        String table=" FROM (SELECT r.*,u.username,u.real_name,CASE WHEN r.status IN ('PENDING','APPROVED') "
                + "AND (r.expires_at<=? OR r.auth_version<>u.auth_version) THEN 'EXPIRED' "
                + "ELSE r.status END AS effective_status FROM password_requests r JOIN users u ON u.id=r.user_id) p WHERE 1=1";
        List<Object> args=new ArrayList<>(List.of(now()));
        if (status!=null) { table+=" AND effective_status=?"; args.add(status); }
        if (kind!=null) { table+=" AND kind=?"; args.add(kind); }
        Long total=jdbc.queryForObject("SELECT count(*)"+table,Long.class,args.toArray());
        args.add(pq.size());args.add(pq.offset());
        return new PageResult<>(total,pq.page(),pq.size(),jdbc.query("SELECT id,user_id,username,real_name,kind,"
                + "effective_status,created_at,expires_at,reviewer_id"+table+" ORDER BY id DESC LIMIT ? OFFSET ?",
                (rs,n)->new RequestDto(rs.getLong("id"),rs.getLong("user_id"),rs.getString("username"),
                        rs.getString("real_name"),rs.getString("kind"),rs.getString("effective_status"),
                        rs.getObject("created_at",OffsetDateTime.class),rs.getObject("expires_at",OffsetDateTime.class),
                        rs.getObject("reviewer_id",Long.class)),args.toArray()));
    }

    @Transactional
    public ReviewDto review(Long id, ReviewRequest request) {
        CurrentUser actor=support.require("user:manage");
        if (!limiter.allow("password-review",String.valueOf(actor.id()),String.valueOf(actor.id()))) {
            throw new BusinessException(ErrorCode.TOO_MANY_REQUESTS);
        }
        support.lock();
        var reviewer=users.findById(actor.id());
        if (reviewer==null || reviewer.isDisabled() || !"ADMIN".equals(reviewer.getRoleCode())) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        if (request.currentPassword().getBytes(StandardCharsets.UTF_8).length>72) AdminSupport.invalid("当前密码 UTF-8 不超过 72 字节");
        if (!passwords.matches(request.currentPassword(),reviewer.getPasswordHash())) {
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }
        RequestRow row=find(id);
        if (row.userId().equals(actor.id())) throw new BusinessException(ErrorCode.FORBIDDEN,"不能审批自己的密码申请");
        if (!"PENDING".equals(effective(row))) throw new BusinessException(ErrorCode.PASSWORD_REQUEST_CONFLICT);
        if (users.findById(row.userId()).isDisabled()) throw new BusinessException(ErrorCode.PASSWORD_REQUEST_CONFLICT);
        boolean approved="APPROVED".equals(request.decision());
        if (approved && !request.identityVerified()) AdminSupport.invalid("批准前必须完成申请人身份核验");
        String token=approved && row.kind().equals("RESET") ? TokenHashService.generateRawToken() : null;
        OffsetDateTime expiry=approved ? now().plusMinutes(15) : row.expiresAt();
        jdbc.update("UPDATE password_requests SET status=?,reviewer_id=?,reviewed_at=?,identity_verified=?,"
                + "expires_at=?,token_hash=? WHERE id=?",request.decision(),actor.id(),now(),request.identityVerified(),
                expiry,token==null?null:TokenHashService.sha256(token),id);
        audit(actor.id(),approved?"批准密码申请":"拒绝密码申请",id);
        // 只在身份核验后的管理员批准响应返回一次；必须通过受控渠道交给本人，不放入列表或日志。
        return new ReviewDto(id,request.decision(),expiry,token);
    }

    @Transactional
    public void completeChange(String newPassword) {
        CurrentUser user=context.require(); support.lock();
        RequestRow row=jdbc.query("SELECT * FROM password_requests WHERE user_id=? AND kind='CHANGE' "
                + "AND status='APPROVED' ORDER BY id DESC LIMIT 1",MAPPER,user.id()).stream().findFirst()
                .orElseThrow(()->new BusinessException(ErrorCode.PASSWORD_APPROVAL_REQUIRED));
        if (!"APPROVED".equals(effective(row))) throw new BusinessException(ErrorCode.PASSWORD_APPROVAL_REQUIRED);
        consume(row,newPassword,user.id());
    }

    @Transactional
    public void completeReset(String token, String newPassword, String ip) {
        if (!limiter.allow("reset-complete",TokenHashService.sha256(token),ip)) {
            throw new BusinessException(ErrorCode.TOO_MANY_REQUESTS);
        }
        support.lock();
        RequestRow row=jdbc.query("SELECT * FROM password_requests WHERE token_hash=? AND kind='RESET'",
                MAPPER,TokenHashService.sha256(token)).stream().findFirst()
                .orElseThrow(()->new BusinessException(ErrorCode.PASSWORD_RESET_INVALID));
        if (!"APPROVED".equals(effective(row))) throw new BusinessException(ErrorCode.PASSWORD_RESET_INVALID);
        consume(row,newPassword,row.userId());
    }

    private void consume(RequestRow row, String newPassword, Long actor) {
        if (newPassword==null || newPassword.isBlank() || newPassword.length()<8
                || newPassword.getBytes(StandardCharsets.UTF_8).length>72) AdminSupport.invalid("新密码至少 8 位且 UTF-8 不超过 72 字节");
        int changed=jdbc.update("UPDATE users SET password_hash=?,auth_version=auth_version+1,failed_attempts=0,"
                + "locked_until=NULL,updated_at=? WHERE id=? AND auth_version=? AND status<>'DISABLED'",
                passwords.encode(newPassword),now(),row.userId(),row.authVersion());
        if (changed!=1) throw new BusinessException(ErrorCode.PASSWORD_REQUEST_CONFLICT);
        jdbc.update("UPDATE refresh_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL",now(),row.userId());
        jdbc.update("UPDATE password_requests SET status='CANCELLED',token_hash=NULL WHERE user_id=? "
                + "AND status IN ('PENDING','APPROVED')",row.userId());
        jdbc.update("UPDATE password_requests SET status='CONSUMED',token_hash=NULL WHERE id=?",row.id());
        audit(actor,"完成密码修改",row.id());
    }

    private String effective(RequestRow row) {
        if (Set.of("PENDING","APPROVED").contains(row.status()) && (!row.expiresAt().isAfter(now())
                || !support.exists("SELECT EXISTS(SELECT 1 FROM users WHERE id=? AND auth_version=?)",row.userId(),row.authVersion()))) {
            return "EXPIRED";
        }
        return row.status();
    }
    private void expire() {
        jdbc.update("UPDATE password_requests r SET status='EXPIRED',token_hash=NULL WHERE status IN ('PENDING','APPROVED') "
                + "AND (expires_at<=? OR NOT EXISTS(SELECT 1 FROM users u WHERE u.id=r.user_id AND u.auth_version=r.auth_version))",now());
    }
    private RequestRow find(Long id) {
        return jdbc.query("SELECT * FROM password_requests WHERE id=?",MAPPER,id).stream().findFirst()
                .orElseThrow(()->new BusinessException(ErrorCode.NOT_FOUND));
    }
    private void audit(Long actor, String action, Long id) {
        jdbc.update("INSERT INTO operation_audits(operator_id,action,object_type,object_id,result) "
                + "VALUES (?,?,'PASSWORD_REQUEST',?,'SUCCESS')",actor,action,String.valueOf(id));
    }
    private OffsetDateTime now() { return OffsetDateTime.now(clock); }
    private record RequestRow(Long id,Long userId,String kind,String status,int authVersion,OffsetDateTime expiresAt) { }
}
