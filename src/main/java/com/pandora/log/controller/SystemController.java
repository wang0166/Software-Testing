package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.AdminDtos.AuditDto;
import com.pandora.log.dto.AdminDtos.ConfigItemDto;
import com.pandora.log.dto.AdminDtos.ConfigUpdateRequest;
import com.pandora.log.service.AuditService;
import com.pandora.log.service.ConfigService;

@RestController
@RequestMapping("/api")
public class SystemController {

    private final ConfigService configService;

    public SystemController(ConfigService configService) {
        this.configService = configService;
    }

    @GetMapping("/configs")
    public ApiResponse<ConfigList> configs() {
        return ApiResponse.success(new ConfigList(configService.list()));
    }

    @PutMapping("/configs/{key}")
    public ApiResponse<ConfigItemDto> updateConfig(@PathVariable String key,
            @RequestBody ConfigUpdateRequest request) {
        return ApiResponse.success(configService.update(key, request == null ? null : request.value()));
    }

    public record ConfigList(List<ConfigItemDto> items) {
    }
}
