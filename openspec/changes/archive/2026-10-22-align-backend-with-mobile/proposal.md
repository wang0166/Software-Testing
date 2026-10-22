## Why

`mobile` 已按 `documents/后端接口文档.md` 完成对接，但后端目前只有认证接口，移动端调用的 25 个非认证业务接口全部缺失（日志、统计、任务、自建任务、公司展示内容、日历、任务地图），联调无法进行。同时认证契约存在 3 处偏差：登录/刷新响应缺少 `permissions`、锁定与停用共用业务码、停用账号提示语不准确。

## What Changes

- 修复认证契约：
  - `POST /api/auth/login`、`POST /api/auth/refresh` 返回的 `user` 增加 `permissions` 数组，与 `GET /api/auth/me` 保持一致。
  - **BREAKING**：停用账号改用独立业务码 `40104`（HTTP 401），锁定账号保持 `40103`（HTTP 423），避免客户端无法区分。
  - 停用账号登录提示语改为准确文案，不再复用锁定提示。
- 补齐移动端调用的全部非认证接口：
  - 日志 7 个：列表、详情、创建、更新、提交、点评列表、新增点评。
  - 统计 3 个：`overview`、`trend`、`unsubmitted`。
  - 任务 9 个：候选接收人、派发、已派发、已接收、任务详情、接收任务详情（assignment）、更新进度、邀请检查、审批/退回。
  - 自建任务 3 个：列表、创建、更新。
  - 公司展示内容 2 个：公司大事、公司重要任务（只读）。
  - 日历 1 个：按日期区间聚合日志与任务，输出 `GREEN`/`RED`/`NONE` 标记。
  - 任务地图 1 个：分页返回派发任务与自建任务的统一数据源。
- 统一分页与错误码：新增 `PageQuery`（默认 20、上限 100），扩展 `ErrorCode` 覆盖参数、权限、状态冲突等场景，与接口文档逐条对齐。
- 新增端到端冒烟测试 `MobileApiSmokeTest`，在真实 PostgreSQL 上验证新接口的 SQL、权限拒绝与契约字段。
- 不修改数据库迁移（V1–V4 已包含全部表与约束），不修改移动端代码。

## Capabilities

### New Capabilities

- `work-logging`: 日志的每日一篇约束、22:00 截止、提交后不可改、按角色范围查询，以及点评仅作者与直属上级可见可写。
- `log-statistics`: 统计概览、趋势、未提交名单的口径与按角色数据范围。
- `company-content-api`: 公司大事与公司重要任务的只读展示接口，要求 `content:read` 权限，且不混入任务数据。
- `calendar-api`: 按日期区间聚合日志与任务，按天输出任务数、日志数与颜色标记。

### Modified Capabilities

- `authentication`: 登录与刷新响应返回用户 `permissions`；锁定与停用使用可区分的业务码与提示语。
- `task-management`: 增加移动端任务协作 HTTP 接口要求，包括候选接收人、派发结果、已派发/已接收列表、任务详情、逐接收人进度、检查邀请与审批，以及自建任务列表/创建/更新接口。
- `task-presentation`: 增加任务地图的服务端数据接口要求，统一返回派发任务与自建任务并支持分页。

## Impact

- 新增代码：`common/PageQuery`、`dto/MobileDtos`、日志/统计/任务/自建任务/内容/日历 6 个控制器及其服务。
- 修改代码：`ErrorCode`、`UserSummary`、`CurrentUserContext`（提供权限校验辅助）、`AuthService`（权限下发与停用文案）。
- 测试：新增 `MobileApiSmokeTest`（5 个端到端用例），全量测试由 17 项扩展到 43 项。
- 接口：新增 26 个端点，契约以 `documents/后端接口文档.md` 为准；移动端 `mobile/lib/data/api_repository.dart` 无需改动。
- 数据库：不需要新迁移，`users`、`work_logs`、`log_comments`、`tasks`、`task_assignments`、`task_reviews`、`personal_tasks`、`company_matters`、`company_important_tasks` 均已存在。
