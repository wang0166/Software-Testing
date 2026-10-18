package com.pandora.log.security;

import org.springframework.stereotype.Component;

import com.pandora.log.common.CurrentUser;

/**
 * 请求级当前用户上下文，由 {@link AuthFilter} 写入并在请求结束时清理。
 */
@Component
public class CurrentUserContext {

    private static final ThreadLocal<CurrentUser> HOLDER = new ThreadLocal<>();

    public void set(CurrentUser currentUser) {
        HOLDER.set(currentUser);
    }

    public CurrentUser get() {
        return HOLDER.get();
    }

    public void clear() {
        HOLDER.remove();
    }
}
