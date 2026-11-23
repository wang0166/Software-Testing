package com.pandora.log.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.common.BusinessException;
import com.pandora.log.common.ErrorCode;

/**
 * DeepSeek 服务端代理。密钥只从后端环境变量读取，不写日志、不下发客户端。
 */
@Service
public class DeepSeekClient {

    private static final Logger log = LoggerFactory.getLogger(DeepSeekClient.class);

    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String baseUrl;
    private final String model;
    private final Duration requestTimeout;
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    public DeepSeekClient(ObjectMapper objectMapper,
            @Value("${app.deepseek.api-key:}") String apiKey,
            @Value("${app.deepseek.base-url:https://api.deepseek.com}") String baseUrl,
            @Value("${app.deepseek.model:deepseek-chat}") String model,
            @Value("${app.deepseek.timeout-seconds:60}") long timeoutSeconds) {
        this.objectMapper = objectMapper;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.baseUrl = baseUrl == null ? "https://api.deepseek.com" : baseUrl.trim();
        this.model = model == null || model.isBlank() ? "deepseek-chat" : model.trim();
        this.requestTimeout = Duration.ofSeconds(Math.max(5, timeoutSeconds));
    }

    public boolean configured() {
        return !apiKey.isBlank();
    }

    public String model() {
        return model;
    }

    /** 调用 Chat Completions，返回模型消息正文（预期为 JSON 字符串）。 */
    public String complete(String systemPrompt, String userPrompt) {
        if (!configured()) {
            throw new BusinessException(ErrorCode.AI_NOT_CONFIGURED);
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", model);
        payload.put("messages", List.of(
                Map.of("role", "system", "content", systemPrompt),
                Map.of("role", "user", "content", userPrompt)));
        payload.put("temperature", 0.3);
        payload.put("max_tokens", 1200);
        payload.put("stream", false);
        payload.put("response_format", Map.of("type", "json_object"));

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(chatCompletionsUri()))
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .timeout(requestTimeout)
                    .POST(HttpRequest.BodyPublishers.ofString(
                            objectMapper.writeValueAsString(payload), StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> response = httpClient.send(request,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() != 200) {
                // 只记录状态码和截断后的响应，避免日志中出现密钥或完整业务数据
                log.warn("DeepSeek 调用失败：HTTP {}，响应摘要 {}",
                        response.statusCode(), abbreviate(response.body()));
                throw new BusinessException(ErrorCode.AI_UPSTREAM_FAILED);
            }

            JsonNode root = objectMapper.readTree(response.body());
            String content = root.path("choices").path(0).path("message").path("content").asText("");
            if (content.isBlank()) {
                throw new BusinessException(ErrorCode.AI_UPSTREAM_FAILED, "AI 分析服务返回空内容");
            }
            return content;
        } catch (BusinessException exception) {
            throw exception;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new BusinessException(ErrorCode.AI_UPSTREAM_FAILED, "AI 分析服务调用被中断");
        } catch (Exception exception) {
            log.warn("DeepSeek 调用异常：{}", exception.getClass().getSimpleName());
            throw new BusinessException(ErrorCode.AI_UPSTREAM_FAILED);
        }
    }

    private String chatCompletionsUri() {
        String normalized = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return normalized + "/chat/completions";
    }

    private static String abbreviate(String body) {
        if (body == null) {
            return "";
        }
        String compact = body.replaceAll("\\s+", " ");
        return compact.length() <= 200 ? compact : compact.substring(0, 200) + "...";
    }
}
