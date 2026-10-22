## Context

后端已完成 Spring Boot 骨架、Flyway V1–V4 迁移和认证纵切，`users`/`work_logs`/`log_comments`/`tasks`/`task_assignments`/`task_reviews`/`personal_tasks`/`company_matters`/`company_important_tasks` 及其实体、Mapper 已存在。移动端 `ApiRepository` 已按 `documents/后端接口文档.md` 调用 25 个业务接口，但这些接口尚未实现，联调只能停留在登录。认证侧还存在 3 处契约偏差（缺少 `permissions`、锁定/停用同码、停用提示语复用锁定文案）。

约束：不新增数据库迁移；响应统一为 `{code,message,data}`；时间戳为带偏移的 ISO-8601；日期为 `YYYY-MM-DD`；时区 `Asia/Shanghai`；角色权限以种子数据为准。

## Goals / Non-Goals

**Goals:**

- 一次性补齐移动端实际调用的 25 个业务接口及接收任务详情接口，字段与 `models.dart` 的 `fromJson` 完全对齐。
- 修复认证契约偏差，使登录、刷新与 `/auth/me` 的权限集合一致。
- 用自动化测试证明新接口的真实 SQL、权限边界与错误码在 PostgreSQL 上可用。

**Non-Goals:**

- 不实现 Web 端管理接口（用户/组织/内容维护）。
- 不修改移动端代码、不调整数据库结构。
- 不引入缓存、消息推送、导出等非本期能力。

## Decisions

### 1. 读模型用 `JdbcTemplate` 直接 SQL，不复用 MyBatis Mapper

移动端接口以聚合列表为主（日志+作者、任务+接收人、日历按天聚合、任务地图联合查询）。逐层建 Entity/VO/Mapper 会带来大量样板且难以表达 `COUNT(*) FILTER`、`UNION ALL` 与窗口聚合。

- 选择：`JdbcTemplate` + RowMapper + 聚合 DTO，写操作使用条件更新（`UPDATE ... WHERE id=? AND status=?`）保证并发下的状态机正确。
- 放弃：扩展 MyBatis XML/Mapper，样板成本高且与“尽可能快”冲突。
- 例外：认证、用户、刷新令牌继续沿用现有 MyBatis 实现，不改动。

### 2. 按领域分组 Controller，DTO 集中在 `MobileDtos`

新增 6 个控制器（日志、统计、任务、自建任务、内容、日历/任务地图），每个控制器只做参数绑定与调用服务；所有移动端 DTO 集中在 `dto/MobileDtos.java`，用 `record` 定义，避免 30 余个独立文件。

### 3. 权限校验统一经 `CurrentUserContext.require`

`CurrentUserContext` 增加 `require(permission)` 辅助：无权限时抛出 `BusinessException(FORBIDDEN/CANNOT_DISPATCH)`。业务侧再叠加“作者/直属上级”“sender/assignee”“owner”等资源级校验，形成“功能权限 + 数据归属”双层防线。管理员仅持有管理类权限与 `log:read`，因此在日志写入、任务、日历、任务地图上自然被拒绝。

### 4. 分页统一 `PageQuery`

`PageQuery.of(page,size)` 归一化参数：`page<1→1`、默认 `size=20`、上限 `100`；`PageResult` 固定输出 `{total,page,size,items}`。移动端 `_allPages` 以 `size=50` 翻页，超出上限时被截断到 100，不会破坏调用方。

### 5. 认证契约修复方式

- `UserSummary` 增加 `permissions`，由 `AuthService` 在登录与刷新时注入角色权限，与 `/auth/me` 共用同一解析逻辑，避免两处漂移。
- `ErrorCode` 拆分：`ACCOUNT_LOCKED(40103,423)` 与 `ACCOUNT_DISABLED(40104,401)`，登录与过滤器分别使用对应文案。
- 错误码整体扩展为文档中的业务码区间（400xx/401xx/403xx/404xx/409xx/500xx），由 `GlobalExceptionHandler` 统一映射 HTTP 状态。

### 6. 关键业务算法

- 日志范围：员工 `u.id=?`、组长 `u.team_id=?`、部门经理 `u.department_id=?`、创始人 `1=1`；管理员只读。
- 统计：`overview` 用 `COUNT(*) FILTER (WHERE ...)` 一次查询完成；`trend` 以日期序列左连接计数；`unsubmitted` 用 `NOT EXISTS` 判断当日已提交日志，参数顺序与占位符严格一致。
- 日历：先按 `from..to` 生成连续日期，再分别加载范围内的日志与任务并按日期分组；`mark` 规则为任务优先 `GREEN`，其次日志 `RED`，否则 `NONE`；跨度上限 31 天。
- 任务地图：派发任务与自建任务通过 `UNION ALL` 合并，缺失列用 `CAST(NULL AS ...)` 对齐类型，再分页与计数。
- 状态机：进度更新与检查审批使用条件更新；邀请要求 `COMPLETED` 且当前无 `PENDING`；审批仅 sender 且仅 `PENDING`。

### 7. 测试策略

新增 `MobileApiSmokeTest`，继承 `EmbeddedPostgresSupport`，用真实 PostgreSQL 建独立库，`@BeforeEach` 按外键顺序清理并重建“公司—部门—团队—四级用户”夹具。5 个用例覆盖日志全生命周期与统计、派发→进度→检查→审批、自建任务与任务地图、公司内容与日历（含管理员 403）。测试数据通过 `INSERT ... RETURNING id` 直接写入，避免依赖种子账号。

## Risks / Trade-offs

- [直接 SQL 与表结构耦合，改表易漏改] → 所有查询集中在服务层，迁移变更时同步检索 `JdbcTemplate` 调用点，并由冒烟测试兜底。
- [JDBC 动态拼接存在注入风险] → 动态部分只拼接固定的 scope 片段，所有外部值一律使用 `?` 占位符。
- [停用账号业务码由 `40103` 改为 `40104` 属破坏性契约变更] → 移动端只按 HTTP 状态与 `message` 展示，已确认无按码分支；文档同步更新。
- [日历区间上限与移动端月视图耦合] → 月视图只请求“月初至月末”（≤31 天），文档与实现共同约束，超限返回 `40001`。
- [冒烟测试启动内嵌 PostgreSQL 较慢] → 复用静态共享实例，仅每次重建数据库，控制单次全量测试时长。

## Migration Plan

1. 合入代码，无需执行数据库迁移。
2. 部署后用种子管理员账号登录，验证 `permissions` 字段；再以员工/组长/部门经理账号各走一次日志与任务主流程。
3. 回滚仅需回退代码；数据库结构未变更，无数据回滚动作。

## Open Questions

- 无。接口字段与错误码以 `documents/后端接口文档.md` 为唯一准绳。
