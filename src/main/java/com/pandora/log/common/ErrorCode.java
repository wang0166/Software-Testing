package com.pandora.log.common;

public enum ErrorCode {

    SUCCESS(0, 200, "ok"),
    VALIDATION_FAILED(40001, 400, "参数校验失败"),
    INVALID_CREDENTIALS(40101, 401, "用户名或密码错误"),
    INVALID_TOKEN(40102, 401, "访问令牌无效或过期"),
    ACCOUNT_LOCKED(40103, 423, "账号已锁定，请稍后重试"),
    ACCOUNT_DISABLED(40103, 401, "账号已锁定或停用"),
    FORBIDDEN(40301, 403, "无权访问该资源"),
    NOT_FOUND(40400, 404, "资源不存在"),
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
