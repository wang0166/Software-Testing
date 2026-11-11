package com.pandora.log.dto;

import java.util.List;

public final class AiDtos {

    private AiDtos() {
    }

    /** 请求体：refresh=true 时跳过服务端缓存，重新调用模型。 */
    public record AiAnalysisRequest(Boolean refresh) {
    }

    /** 本次分析实际使用的数据范围，便于客户端和用户核对。 */
    public record AiDataScope(int logCount, int taskCount, int dispatchedTaskCount, String range) {
    }

    public record AiAnalysisDto(
            String summary,
            List<String> highlights,
            List<String> risks,
            List<String> suggestions,
            String model,
            String generatedAt,
            AiDataScope dataScope) {
    }
}
