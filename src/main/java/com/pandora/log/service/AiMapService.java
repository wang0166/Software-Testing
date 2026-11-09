package com.pandora.log.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.AiDtos.AiAnalysisDto;
import com.pandora.log.dto.AiDtos.AiDataScope;
import com.pandora.log.dto.MobileDtos.DispatchedTaskDto;
import com.pandora.log.dto.MobileDtos.TaskMapDto;
import com.pandora.log.dto.MobileDtos.TaskMapItemDto;
import com.pandora.log.dto.MobileDtos.WorkLogDto;
import com.pandora.log.security.CurrentUserContext;

/**
 * AI 地图分析：只在服务端汇总当前用户已授权的日志/任务，再调用 DeepSeek。
 * 不向模型发送其他同事的原始数据，不伪造分析结果，未配置密钥时明确报错。
 */
@Service
public class AiMapService {

    private static final ZoneId ZONE = ZoneId.of("Asia/Shanghai");
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static final Duration CACHE_TTL = Duration.ofMinutes(5);
    private static final int MAX_LOGS = 20;
    private static final int MAX_TASKS = 60;
    private static final int MAX_DISPATCHED = 30;

    private static final String SYSTEM_PROMPT = """
            你是企业工作日志与任务管理系统的分析助手。你只能依据用户消息中提供的 JSON 数据进行分析：
            1) 不得编造数据中不存在的事实，不得虚构人名、进度或日期；
            2) 不推断人格、MBTI、健康等敏感信息，不做道德或绩效定性评价；
            3) 使用简体中文，只输出一个 JSON 对象，不要输出 Markdown、代码块或任何额外文字。

            输出 JSON 字段：
            - summary: 字符串，不超过 120 字，概括当前工作负荷与任务执行状态；
            - highlights: 字符串数组，2-4 条，只指出数据中可复核的亮点或规律；
            - risks: 字符串数组，1-4 条，指出逾期、临期、长期未推进、信息缺失等风险；没有风险时输出空数组；
            - suggestions: 字符串数组，2-5 条，给出可执行的下一步建议，避免空泛口号。

            如果数据为空或不足以分析，summary 中说明“暂无足够数据”，其余数组可以为空。
            """;

    private final CurrentUserContext currentUserContext;
    private final LogService logService;
    private final CalendarService calendarService;
    private final TaskService taskService;
    private final DeepSeekClient deepSeekClient;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    private final Map<Long, CacheEntry> cache = new ConcurrentHashMap<>();

    public AiMapService(CurrentUserContext currentUserContext,
            LogService logService,
            CalendarService calendarService,
            TaskService taskService,
            DeepSeekClient deepSeekClient,
            AuditService auditService,
            ObjectMapper objectMapper,
            Clock clock) {
        this.currentUserContext = currentUserContext;
        this.logService = logService;
        this.calendarService = calendarService;
        this.taskService = taskService;
        this.deepSeekClient = deepSeekClient;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    public AiAnalysisDto analyze(boolean refresh) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("task:execute") && !currentUser.hasPermission("task:self")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        CacheEntry cached = cache.get(currentUser.id());
        if (!refresh && cached != null && Instant.now(clock).isBefore(cached.expiresAt())) {
            return cached.dto();
        }

        PageResult<WorkLogDto> logs = logService.list(null, null, null, 1, MAX_LOGS);
        TaskMapDto tasks = calendarService.taskMap(1, MAX_TASKS);
        PageResult<DispatchedTaskDto> dispatched = currentUser.hasPermission("task:dispatch")
                ? taskService.dispatched(1, MAX_DISPATCHED)
                : null;

        String userPrompt = buildPrompt(currentUser, logs.items(), tasks.items(),
                dispatched == null ? List.of() : dispatched.items());

        String content;
        try {
            content = deepSeekClient.complete(SYSTEM_PROMPT, userPrompt);
        } catch (BusinessException exception) {
            auditService.record("AI地图分析", "AI", String.valueOf(currentUser.id()),
                    "model=" + deepSeekClient.model(), "FAILED");
            throw exception;
        }

        AiAnalysisDto dto = parse(content, logs.items(), tasks.items(),
                dispatched == null ? List.of() : dispatched.items());
        cache.put(currentUser.id(), new CacheEntry(dto, Instant.now(clock).plus(CACHE_TTL)));
        auditService.record("AI地图分析", "AI", String.valueOf(currentUser.id()),
                "model=" + deepSeekClient.model() + ", logs=" + logs.items().size()
                        + ", tasks=" + tasks.items().size(), "SUCCESS");
        return dto;
    }

    private String buildPrompt(CurrentUser currentUser, List<WorkLogDto> logs,
            List<TaskMapItemDto> tasks, List<DispatchedTaskDto> dispatched) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("asOf", DATE_FORMAT.format(java.time.LocalDate.now(clock.withZone(ZONE))));
        data.put("userRole", currentUser.roleCode());
        data.put("range", describeRange(logs));

        List<Map<String, Object>> logItems = new ArrayList<>();
        for (WorkLogDto log : logs) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("date", log.logDate() == null ? null : log.logDate().toString());
            item.put("status", log.status());
            item.put("important", log.isImportant());
            item.put("content", shorten(log.content(), 240));
            logItems.add(item);
        }
        data.put("logs", logItems);

        List<Map<String, Object>> taskItems = new ArrayList<>();
        for (TaskMapItemDto task : tasks) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("name", task.name());
            item.put("source", "PERSONAL".equals(task.source()) ? "自建任务" : "派发任务");
            item.put("status", task.executionStatus());
            item.put("urgency", task.urgency());
            item.put("startDate", task.startDate() == null ? null : task.startDate().toLocalDate().toString());
            item.put("deadline", task.deadline() == null ? null : task.deadline().toLocalDate().toString());
            item.put("details", shorten(task.details(), 160));
            taskItems.add(item);
        }
        data.put("tasks", taskItems);

        List<Map<String, Object>> dispatchedItems = new ArrayList<>();
        for (DispatchedTaskDto task : dispatched) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("name", task.name());
            item.put("assigneeCount", task.assigneeCount());
            item.put("completedCount", task.completedCount());
            item.put("pendingReviewCount", task.pendingReviewCount());
            item.put("deadline", task.deadline() == null ? null : task.deadline().toLocalDate().toString());
            dispatchedItems.add(item);
        }
        data.put("dispatchedTasks", dispatchedItems);

        String json;
        try {
            json = objectMapper.writeValueAsString(data);
        } catch (Exception exception) {
            throw new BusinessException(ErrorCode.AI_UPSTREAM_FAILED, "AI 分析数据准备失败");
        }
        return "以下是当前用户授权范围内的数据（JSON），请按要求输出 JSON 分析结果：\n" + json;
    }

    private AiAnalysisDto parse(String content, List<WorkLogDto> logs, List<TaskMapItemDto> tasks,
            List<DispatchedTaskDto> dispatched) {
        String cleaned = stripCodeFence(content);
        try {
            JsonNode root = objectMapper.readTree(cleaned);
            String summary = root.path("summary").asText("");
            if (summary.isBlank()) {
                throw new BusinessException(ErrorCode.AI_UPSTREAM_FAILED, "AI 分析结果缺少 summary");
            }
            return new AiAnalysisDto(
                    summary,
                    readArray(root.path("highlights")),
                    readArray(root.path("risks")),
                    readArray(root.path("suggestions")),
                    deepSeekClient.model(),
                    TIME_FORMAT.format(java.time.LocalDateTime.now(clock.withZone(ZONE))),
                    new AiDataScope(logs.size(), tasks.size(), dispatched.size(), describeRange(logs)));
        } catch (BusinessException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new BusinessException(ErrorCode.AI_UPSTREAM_FAILED, "AI 分析结果解析失败，请稍后重试");
        }
    }

    private static List<String> readArray(JsonNode node) {
        List<String> values = new ArrayList<>();
        if (node != null && node.isArray()) {
            for (JsonNode element : node) {
                String text = element.asText("");
                if (!text.isBlank()) {
                    values.add(text.trim());
                }
            }
        }
        return values;
    }

    private static String describeRange(List<WorkLogDto> logs) {
        if (logs.isEmpty()) {
            return "暂无日志";
        }
        String newest = logs.get(0).logDate() == null ? "" : logs.get(0).logDate().toString();
        String oldest = logs.get(logs.size() - 1).logDate() == null
                ? "" : logs.get(logs.size() - 1).logDate().toString();
        return oldest + " ~ " + newest;
    }

    private static String shorten(String value, int maxLength) {
        if (value == null) {
            return "";
        }
        String compact = value.replaceAll("\\s+", " ").trim();
        return compact.length() <= maxLength ? compact : compact.substring(0, maxLength) + "…";
    }

    private static String stripCodeFence(String content) {
        String trimmed = content == null ? "" : content.trim();
        if (trimmed.startsWith("```")) {
            int firstLineBreak = trimmed.indexOf('\n');
            if (firstLineBreak > 0) {
                trimmed = trimmed.substring(firstLineBreak + 1);
            }
            if (trimmed.endsWith("```")) {
                trimmed = trimmed.substring(0, trimmed.length() - 3);
            }
        }
        return trimmed.trim();
    }

    private record CacheEntry(AiAnalysisDto dto, Instant expiresAt) {
    }
}
