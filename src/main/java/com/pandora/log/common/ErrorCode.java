package com.pandora.log.common;

public enum ErrorCode {

    SUCCESS(0, 200, "ok"),
    VALIDATION_FAILED(40001, 400, "参数校验失败"),
    TASK_VALIDATION_FAILED(40002, 400, "任务字段校验失败"),
    INVALID_ASSIGNEES(40003, 400, "接收人列表非法"),
    INVALID_CREDENTIALS(40101, 401, "用户名或密码错误"),
    INVALID_TOKEN(40102, 401, "访问令牌无效或过期"),
    ACCOUNT_LOCKED(40103, 423, "账号已锁定，请稍后重试"),
    ACCOUNT_DISABLED(40104, 401, "账号已停用"),
    FORBIDDEN(40301, 403, "无权访问该资源"),
    NOT_DIRECT_SUPERIOR(40302, 403, "非直属上级，不能点评"),
    CANNOT_DISPATCH(40310, 403, "非直接下级或当前角色无派发能力，不能派发任务"),
    TASK_ACCESS_DENIED(40311, 403, "无权访问或操作该任务"),
    NOT_ASSIGNEE(40312, 403, "仅被派发人可更新本人进度或发起邀约"),
    NOT_SENDER(40313, 403, "仅派发人可检查"),
    CONTENT_MANAGE_DENIED(40314, 403, "无权维护该展示内容"),
    NOT_FOUND(40400, 404, "资源不存在"),
    RESOURCE_NOT_VISIBLE(40401, 404, "资源不存在或不可见"),
    TASK_NOT_FOUND(40410, 404, "任务或接收记录不存在或不可见"),
    LOG_ALREADY_EXISTS(40901, 409, "当天已存在日志"),
    LOG_ALREADY_SUBMITTED(40902, 409, "已提交日志不可修改"),
    LOG_DEADLINE_PASSED(40903, 409, "已过截止时间"),
    USERNAME_EXISTS(40906, 409, "账户名已存在"),
    OWNER_EXISTS(40905, 409, "组织负责人已存在，请先调整原负责人的角色或归属"),
    ORGANIZATION_IN_USE(40904, 409, "组织仍有成员或下级组织，请先迁移归属"),
    ORGANIZATION_NAME_EXISTS(40907, 409, "同一上级组织中名称已存在"),
    LAST_ADMIN(40908, 409, "至少保留一个启用的系统管理员"),
    DATA_CONFLICT(40909, 409, "数据约束冲突，请刷新后重试"),
    TASK_STATUS_CONFLICT(40910, 409, "任务状态转换非法"),
    REVIEW_ALREADY_PENDING(40911, 409, "已存在待检查邀约"),
    REVIEW_ALREADY_HANDLED(40912, 409, "检查结果已处理或不可重复"),
    PASSWORD_REQUEST_CONFLICT(40920, 409, "密码申请已存在、过期或已处理"),
    PASSWORD_APPROVAL_REQUIRED(40320, 403, "需要有效的密码修改批准"),
    PASSWORD_RESET_INVALID(40020, 400, "恢复凭据无效或已过期"),
    TOO_MANY_REQUESTS(42901, 429, "请求过于频繁，请稍后重试"),
    INTERNAL_ERROR(50000, 500, "服务内部错误");

    private final int code;
    private final int httpStatus;
    private final String message;

    ErrorCode(int code, int httpStatus, String message) {
        this.code = code;
        this.httpStatus = httpStatus;
        this.message = message;
    }

    public int getCode() {
        return code;
    }

    public int getHttpStatus() {
        return httpStatus;
    }

    public String getMessage() {
        return message;
    }
}
