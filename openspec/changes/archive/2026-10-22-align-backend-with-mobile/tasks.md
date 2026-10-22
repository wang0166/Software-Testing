## 1. 公共契约与认证修复

- [x] 1.1 扩展 `ErrorCode`：新增参数、权限、资源归属、任务状态、日志冲突等业务码，并拆分 `ACCOUNT_LOCKED(40103,423)` 与 `ACCOUNT_DISABLED(40104,401)`
- [x] 1.2 新增 `PageQuery`（默认 20、上限 100、`page<1→1`）与 `PageResult{total,page,size,items}`，供所有列表接口复用
- [x] 1.3 `UserSummary` 增加 `permissions`，`AuthService` 在登录与刷新时注入服务端解析的权限集合
- [x] 1.4 修正停用账号登录文案，并确认 `AuthFilter` 对停用账号返回 `40104`
- [x] 1.5 `CurrentUserContext` 增加 `require(permission)` 辅助方法，统一抛出权限异常
- [x] 1.6 同步更新 `documents/后端接口文档.md` 中 `40104`、`permissions` 与新增端点说明

## 2. 日志接口

- [x] 2.1 新增 `MobileDtos` 中的日志、点评、统计、任务、自建任务、内容、日历、任务地图 DTO
- [x] 2.2 实现 `LogService`：按角色范围的列表/详情、每日一篇唯一性、`22:00` 截止、提交后不可改
- [x] 2.3 实现点评读写与“作者或直属上级”校验，越权返回 `40302`
- [x] 2.4 新增 `LogController`：`GET/POST /api/logs`、`GET/PUT /api/logs/{id}`、`POST /api/logs/{id}/submit`、`GET/POST /api/logs/{id}/comments`
- [x] 2.5 验证重复创建 `40901`、重复提交/修改 `40902`、超时 `40903`

## 3. 统计接口

- [x] 3.1 实现 `StatsService.overview`：按范围统计应提交、已提交、未提交与提交率
- [x] 3.2 实现 `StatsService.trend(days)`：默认 7、范围 1–30，末位为今天
- [x] 3.3 实现 `StatsService.unsubmitted`：`NOT EXISTS` 过滤当日已提交用户，注意占位符与参数顺序
- [x] 3.4 新增 `StatsController` 暴露 `/api/stats/overview`、`/trend`、`/unsubmitted`

## 4. 任务协作接口

- [x] 4.1 实现 `TaskService.recipients`：按调用者角色返回直属下级，拒绝非派发角色
- [x] 4.2 实现 `dispatch`：单事务写入任务与逐接收人 assignment，非法接收人整体回滚并返回 `40003`
- [x] 4.3 实现 `dispatched` 与 `received` 分页列表，字段包含 `assigneeCount`、`sender`、`executionStatus`、`reviewStatus`
- [x] 4.4 实现任务详情与 assignment 详情（含按时间排序的检查历史）
- [x] 4.5 实现进度更新状态机与 `PENDING/APPROVED` 期间的 `40910` 拦截
- [x] 4.6 实现检查邀请（`40911`）与 sender 审批/退回（`40912`），退回后回到 `IN_PROGRESS` 并保留记录
- [x] 4.7 新增 `TaskController` 暴露 9 个端点，并校验 `task:dispatch`、`task:execute`、assignee/sender 归属

## 5. 自建任务接口

- [x] 5.1 实现 `PersonalTaskService` 列表/创建/更新，默认 `NOT_STARTED`，仅 owner 可读写
- [x] 5.2 新增 `PersonalTaskController`：`GET/POST /api/personal-tasks`、`PUT /api/personal-tasks/{id}`

## 6. 内容、日历与任务地图

- [x] 6.1 实现 `ContentService` 与 `ContentController`：公司大事、公司重要任务只读分页，要求 `content:read`
- [x] 6.2 实现 `CalendarService.calendar`：区间校验（≤31 天）、按天聚合日志与任务、`GREEN/RED/NONE` 标记
- [x] 6.3 实现 `CalendarService.taskMap`：派发与自建任务 `UNION ALL` 合并、分页与来源标识
- [x] 6.4 暴露 `GET /api/calendar` 与 `GET /api/task-map`，校验 `task:execute`/`task:self`

## 7. 测试与验收

- [x] 7.1 新增 `MobileApiSmokeTest` 夹具：独立内嵌数据库、按外键顺序清表、构建公司/部门/团队/四级用户
- [x] 7.2 覆盖日志全生命周期与统计：创建→更新→提交→点评→概览/趋势/未提交
- [x] 7.3 覆盖任务流程：派发→接收→进度→邀请→审批→历史，以及审批后再改进度的冲突
- [x] 7.4 覆盖自建任务、任务地图、公司内容与日历（含管理员 403）
- [x] 7.5 运行 `mvn -B test`，确认全量测试通过且无 SQL 语法/参数顺序问题
