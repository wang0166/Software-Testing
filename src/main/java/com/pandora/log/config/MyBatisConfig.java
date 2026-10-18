package com.pandora.log.config;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@MapperScan("com.pandora.log.mapper")
public class MyBatisConfig {
}
