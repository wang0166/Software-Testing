package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.CrmDtos.ActivityDto;
import com.pandora.log.dto.CrmDtos.BenefitDto;
import com.pandora.log.dto.CrmDtos.CreateActivityRequest;
import com.pandora.log.dto.CrmDtos.CreateCustomerRequest;
import com.pandora.log.dto.CrmDtos.CustomerDto;
import com.pandora.log.dto.CrmDtos.RevenueSummaryDto;
import com.pandora.log.service.CrmService;

@RestController
@RequestMapping("/api/crm")
public class CrmController {
    private final CrmService service;

    public CrmController(CrmService service) {
        this.service = service;
    }

    @GetMapping("/customers")
    public ApiResponse<PageResult<CustomerDto>> customers(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String business,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(service.customers(keyword, category, business, page, size));
    }

    @PostMapping("/customers")
    public ApiResponse<CustomerDto> createCustomer(@RequestBody CreateCustomerRequest request) {
        return ApiResponse.success(service.createCustomer(request));
    }

    @GetMapping("/customers/{customerId}/benefits")
    public ApiResponse<List<BenefitDto>> benefits(@PathVariable Long customerId) {
        return ApiResponse.success(service.benefits(customerId));
    }

    @PostMapping("/benefits/{benefitId}/redeem")
    public ApiResponse<BenefitDto> redeem(@PathVariable Long benefitId) {
        return ApiResponse.success(service.redeem(benefitId));
    }

    @GetMapping("/customers/{customerId}/activities")
    public ApiResponse<List<ActivityDto>> activities(@PathVariable Long customerId) {
        return ApiResponse.success(service.activities(customerId));
    }

    @PostMapping("/activities")
    public ApiResponse<ActivityDto> createActivity(@RequestBody CreateActivityRequest request) {
        return ApiResponse.success(service.createActivity(request));
    }

    @GetMapping("/revenue/summary")
    public ApiResponse<RevenueSummaryDto> revenue(@RequestParam String month) {
        return ApiResponse.success(service.revenue(month));
    }
}
