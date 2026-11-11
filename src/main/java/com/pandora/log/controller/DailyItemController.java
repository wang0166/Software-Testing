package com.pandora.log.controller;

import java.time.LocalDate;
import java.util.List;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.dto.MobileDtos.DailyItemDto;
import com.pandora.log.dto.MobileDtos.DailyItemRequest;
import com.pandora.log.dto.MobileDtos.Items;
import com.pandora.log.service.DailyItemService;

@RestController
@RequestMapping("/api/daily-items")
public class DailyItemController {

    private final DailyItemService dailyItemService;

    public DailyItemController(DailyItemService dailyItemService) {
        this.dailyItemService = dailyItemService;
    }

    @GetMapping
    public ApiResponse<Items<DailyItemDto>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        List<DailyItemDto> items = dailyItemService.list(from, to);
        return ApiResponse.success(new Items<>(items));
    }

    @PostMapping
    public ApiResponse<DailyItemDto> create(@RequestBody DailyItemRequest request) {
        return ApiResponse.success(dailyItemService.create(request));
    }

    @PutMapping("/{id}")
    public ApiResponse<DailyItemDto> update(@PathVariable Long id, @RequestBody DailyItemRequest request) {
        return ApiResponse.success(dailyItemService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        dailyItemService.delete(id);
        return ApiResponse.success(null);
    }
}
