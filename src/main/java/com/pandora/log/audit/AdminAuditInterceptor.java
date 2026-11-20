package com.pandora.log.audit;

import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import com.pandora.log.controller.AdminController;
import com.pandora.log.controller.PasswordController;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.security.CurrentUserContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/** 成功审计随业务事务写入；失败请求在事务回滚后只记录动作和状态，不读取请求正文。 */
@Component
public class AdminAuditInterceptor implements HandlerInterceptor, WebMvcConfigurer {
    private static final Logger log = LoggerFactory.getLogger(AdminAuditInterceptor.class);
    private final JdbcTemplate jdbc;
    private final CurrentUserContext context;
    public AdminAuditInterceptor(JdbcTemplate jdbc, CurrentUserContext context) { this.jdbc = jdbc; this.context = context; }
    @Override public void addInterceptors(InterceptorRegistry registry) { registry.addInterceptor(this).addPathPatterns("/api/**"); }
    @Override public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception error) {
        if (!(handler instanceof HandlerMethod method)
                || (method.getBeanType() != AdminController.class && method.getBeanType() != PasswordController.class)
                || !Set.of("POST", "PUT", "PATCH", "DELETE").contains(request.getMethod()) || response.getStatus() < 400) return;
        String[] parts = request.getRequestURI().split("/");
        String resource = parts.length > 2 ? parts[2] : "unknown";
        String id = parts.length > 3 && parts[3].matches("[0-9]{1,19}") ? parts[3] : null;
        String action = request.getMethod() + " " + resource;
        if (method.getBeanType() == PasswordController.class) {
            action = resource.equals("password-requests") ? "审批密码申请" : "密码申请或修改";
        } else if (resource.equals("users") && parts.length > 4) {
            action = parts[4].equals("password") ? "重置密码" : "更新账号状态";
        } else {
            String object = switch (resource) {
                case "users" -> "用户"; case "departments" -> "部门"; case "teams" -> "团队";
                case "companies" -> "公司"; case "company-matters" -> "公司事项"; default -> resource;
            };
            action = switch (request.getMethod()) {
                case "POST" -> "创建" + object; case "PUT" -> "编辑" + object; case "DELETE" -> "删除" + object; default -> action;
            };
        }
        CurrentUser user = context.get();
        try {
            jdbc.update("INSERT INTO operation_audits(operator_id,action,object_type,object_id,detail,result,ip) VALUES (?,?,?,?,?,'FAILED',?)",
                    user == null ? null : user.id(), action, resource, id,
                    "HTTP " + response.getStatus(), request.getRemoteAddr());
        } catch (RuntimeException e) { log.warn("管理失败请求的审计写入失败"); }
    }
}
