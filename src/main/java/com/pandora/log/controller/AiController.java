package com.pandora.log.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.dto.AiDtos.AiAnalysisDto;
import com.pandora.log.dto.AiDtos.AiAnalysisRequest;
import com.pandora.log.service.AiMapService;

@RestController
@RequestMapping("/api/ai")
public class AiController {

    private final AiMapService aiMapService;

    public AiController(AiMapService aiMapService) {
        this.aiMapService = aiMapService;
    }

    /** AI 地图分析：服务端按当前用户权限取数并调用 DeepSeek，默认复用 5 分钟缓存。 */
    @PostMapping("/map/analysis")
    public ApiResponse<AiAnalysisDto> analyze(@RequestBody(required = false) AiAnalysisRequest request) {
        boolean refresh = request != null && Boolean.TRUE.equals(request.refresh());
        return ApiResponse.success(aiMapService.analyze(refresh));
    }
}
