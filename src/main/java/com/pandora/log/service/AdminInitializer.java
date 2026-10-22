package com.pandora.log.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;

import com.pandora.log.entity.User;
import com.pandora.log.mapper.UserMapper;
import com.pandora.log.security.PasswordService;

@Component
public class AdminInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminInitializer.class);

    private static final String ADMIN_ROLE = "ADMIN";

    private final UserMapper userMapper;
    private final PasswordService passwordService;
    private final String initUsername;
    private final String initPassword;

    public AdminInitializer(UserMapper userMapper,
            PasswordService passwordService,
            @Value("${app.admin.init-username:admin}") String initUsername,
            @Value("${app.admin.init-password:}") String initPassword) {
        this.userMapper = userMapper;
        this.passwordService = passwordService;
        this.initUsername = initUsername;
        this.initPassword = initPassword;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (userMapper.countByRole(ADMIN_ROLE) > 0) {
            return;
        }
        if (initPassword == null || initPassword.isBlank()) {
            log.warn("系统中不存在管理员账号，且未提供 ADMIN_INIT_PASSWORD，已跳过初始管理员创建");
            return;
        }

        User admin = new User();
        admin.setUsername(initUsername);
        admin.setPasswordHash(passwordService.encode(initPassword));
        admin.setRealName("系统管理员");
        admin.setRoleCode(ADMIN_ROLE);
        admin.setStatus("ACTIVE");
        admin.setFailedAttempts(0);

        try {
            userMapper.insert(admin);
            log.info("已创建初始管理员账号 '{}'", initUsername);
        } catch (DataIntegrityViolationException exception) {
            log.warn("初始管理员创建失败，用户名 '{}' 可能已被占用", initUsername);
        }
    }
}
