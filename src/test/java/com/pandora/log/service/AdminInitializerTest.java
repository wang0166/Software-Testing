package com.pandora.log.service;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;

import com.pandora.log.mapper.UserMapper;
import com.pandora.log.security.PasswordPolicy;
import com.pandora.log.security.PasswordService;

class AdminInitializerTest {
    private final UserMapper users = mock(UserMapper.class);
    private final PasswordService passwords = mock(PasswordService.class);
    private final PasswordPolicy policy = new PasswordPolicy();

    @Test void productionRequiresInitialPasswordWhenNoAdministratorExists() {
        when(users.countByRole("ADMIN")).thenReturn(0L);
        AdminInitializer initializer = new AdminInitializer(
                users, passwords, policy, "admin", "", true);

        assertThatThrownBy(() -> initializer.run(null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("ADMIN_INIT_PASSWORD");
    }

    @Test void weakInitialPasswordAlwaysStopsInitialization() {
        when(users.countByRole("ADMIN")).thenReturn(0L);
        AdminInitializer initializer = new AdminInitializer(
                users, passwords, policy, "admin", "123456", false);

        assertThatThrownBy(() -> initializer.run(null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("强密码要求");
    }

    @Test void existingAdministratorDoesNotRequireBootstrapSecret() {
        when(users.countByRole("ADMIN")).thenReturn(1L);
        AdminInitializer initializer = new AdminInitializer(
                users, passwords, policy, "admin", "", true);

        assertThatCode(() -> initializer.run(null)).doesNotThrowAnyException();
    }
}
