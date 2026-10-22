package com.pandora.log.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.dto.MobileDtos.Items;
import com.pandora.log.dto.MobileDtos.OverviewDto;
import com.pandora.log.dto.MobileDtos.TrendDto;
import com.pandora.log.dto.MobileDtos.UnsubmittedUserDto;
import com.pandora.log.service.StatsService;

@RestController
@RequestMapping("/api/stats")
public class StatsController {

    private final StatsService statsService;

    public StatsController(StatsService statsService) {
        this.statsService = statsService;
    }

    @GetMapping("/overview")
    public ApiResponse<OverviewDto> overview() {
        return ApiResponse.success(statsService.overview());
    }

    @GetMapping("/unsubmitted")
    public ApiResponse<Items<UnsubmittedUserDto>> unsubmitted() {
        return ApiResponse.success(new Items<>(statsService.unsubmitted()));
    }

    @GetMapping("/trend")
    public ApiResponse<TrendDto> trend(@RequestParam(required = false) Integer days) {
        return ApiResponse.success(new TrendDto(statsService.trend(days)));
    }
}
