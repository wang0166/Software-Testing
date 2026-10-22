package com.pandora.log.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.PersonalTaskDto;
import com.pandora.log.dto.MobileDtos.PersonalTaskRequest;
import com.pandora.log.service.PersonalTaskService;

@RestController
@RequestMapping("/api/personal-tasks")
public class PersonalTaskController {

    private final PersonalTaskService personalTaskService;

    public PersonalTaskController(PersonalTaskService personalTaskService) {
        this.personalTaskService = personalTaskService;
    }

    @GetMapping
    public ApiResponse<PageResult<PersonalTaskDto>> list(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(personalTaskService.list(page, size));
    }

    @PostMapping
    public ApiResponse<PersonalTaskDto> create(@RequestBody PersonalTaskRequest request) {
        return ApiResponse.success(personalTaskService.create(request));
    }

    @PutMapping("/{id}")
    public ApiResponse<PersonalTaskDto> update(@PathVariable Long id,
            @RequestBody PersonalTaskRequest request) {
        return ApiResponse.success(personalTaskService.update(id, request));
    }
}
