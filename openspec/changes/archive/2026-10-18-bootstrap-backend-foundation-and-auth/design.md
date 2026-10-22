## Context

仓库当前只有文档与 OpenSpec 规格，没有任何后端源码。`tasks.md` 的 Sprint 1–2（1.1–2.6）定义了工程骨架、数据库迁移、种子数据与认证纵切，是 Sprint 3 用户/组织接口和 Sprint 4 日志接口的共同前置。

约束来自三份正式文档：

- `documents/技术设计文档.md` §5.1 规定 `com.pandora.log` 下 `common/config/security/controller/service/mapper/entity/dto/job/audit` 分层；§5.2 规定 `code/message/data` 统一响应与错误码分段。
- `documents/后端接口文档.md` §2 规定 `POST /api/auth/login`、`/refresh`、`/logout` 与 `GET /api/auth/me`，以及 `40101`/`40102`/`40103` 的语义。
- `documents/项目计划与里程碑.md` 规定 Sprint 1（2026-09-18 ~ 09-24）完成契约与工程基线，Sprint 2（09-25 ~ 10-01）完成认证纵切。

本变更只交付可运行的后端底座与认证，不实现用户/组织管理接口和业务领域接口。

## Goals / Non-Goals

**Goals:**

- Maven + Spring Boot 工程可在配置好 PostgreSQL 后直接启动，包结构与技术设计一致。
- 所有响应经过统一包装，参数校验、认证、无权限和业务异常返回文档定义的 HTTP 状态与业务码。
- Flyway 从空库一次迁移到最新结构，包含角色/权限/配置种子、组织与用户、日志、任务六表及约束。
- 账号密码登录、刷新、登出、当前用户四个接口可用；JWT 过滤器可保护后续业务接口；失败锁定与停用账号规则生效。
- 认证契约测试、迁移与约束集成测试可在构建中运行，供客户端按样例先行联调。

**Non-Goals:**

- 不实现 Sprint 3 的用户/组织/角色管理接口、任务对象鉴权。
- 不实现 Sprint 4 起的日志、统计、点评、任务、公司展示、数据地图、日历业务接口。
- 不修改 `产品需求文档`、接口契约或技术设计；前端代码不在本变更范围。
- 不引入 Redis、消息队列或分布式会话；认证状态全部落在 PostgreSQL。

## Decisions

### 1. 工程与分层

采用 Maven 单模块 Spring Boot 3 + Java 17，包根为 `com.pandora.log`，按技术设计 §5.1 建立 `common/config/security/controller/service/mapper/entity/dto/job/audit`。MyBatis 使用注解与 XML 混合（复杂查询后续放 XML），`@MapperScan` 指向 `mapper`。

- 理由：与文档结构逐项对应，评审和后续 Sprint 无需迁移目录。
- 备选：Gradle 或多模块。当前团队与文档均以 Maven 为基线，多模块在单体规模下只会增加构建复杂度。

### 2. 统一响应与异常映射

`ApiResponse<T>` 固定 `code/message/data`，成功 `code=0`、`message="ok"`。`PageResult<T>` 固定 `total/page/size/items`。`ErrorCode` 枚举承载业务码与默认文案，`BusinessException` 携带 `ErrorCode` 和可选覆盖文案。

异常映射集中在一个 `@RestControllerAdvice`：

| 来源 | HTTP | 业务码 |
|---|---|---|
| 参数校验 / JSON 解析失败 | 400 | `40001` |
| 未认证、令牌无效或过期 | 401 | `40102` |
| 用户名或密码错误 | 401 | `40101` |
| 账号锁定或停用 | 423 / 401 | `40103` |
| 已认证但无权限 | 403 | `40301` |
| 未捕获异常 | 500 | `50000` |

- 理由：客户端只需处理一套结构与分段码；HTTP 状态保留语义，便于网关与日志。
- 备选：全部返回 HTTP 200 由业务码区分。会掩盖认证失败，且与接口文档不一致，不采用。

### 3. Flyway 迁移切片

迁移按“先引用数据、再组织用户、再业务表”的顺序拆分，单个版本保持可独立回放：

| 版本 | 内容 |
|---|---|
| `V1__create_reference_tables.sql` | `roles`、`permissions`、`role_permissions`、`system_configs`，含 5 角色、15 权限、角色权限映射、5 项配置种子 |
| `V2__create_organization_and_user_tables.sql` | `companies`、`departments`、`teams`、`users`、`refresh_tokens`；`chk_users_role`、`chk_users_status`、`chk_users_org_alignment`；创始人/部门老总/团队长部分唯一索引；删除 RESTRICT |
| `V3__create_log_tables.sql` | `work_logs`、`log_comments`，含 `UNIQUE(author_id, log_date)` 与非空 CHECK |
| `V4__create_task_tables.sql` | `tasks`、`task_assignments`、`task_reviews`、`personal_tasks`、`company_matters`、`company_important_tasks` 及任务唯一约束与查询索引 |

- 理由：V1 可被任何环境单独验证；组织约束集中在 V2，便于 Sprint 3 接口直接依赖；Sprint 4 与 Sprint 6 的实现只需写代码，不再追加建表迁移。
- 备选：单一大迁移。空库可一次执行，但任一表评审变更都会导致整版重写，回滚粒度太粗。

部分唯一索引使用 `WHERE` 条件限定角色，例如公司创始人 `UNIQUE (company_id) WHERE role_code = 'FOUNDER'`，部门与团队同理。团队长与团队所属部门的一致性无法用单表 CHECK 表达，保留为 Sprint 3 服务层校验，本变更只保证表结构与索引就位。

### 4. JWT 与刷新令牌

- 访问令牌：JWT（HS256），`sub` 为用户 ID，携带 `role`、`username`，有效期取 `access_token_ttl_minutes`（默认 120 分钟），密钥来自环境变量，不写入仓库。
- 刷新令牌：随机不透明字符串，数据库仅存 SHA-256 摘要、`user_id`、`expires_at`、`revoked_at`、`created_at`；有效期取 `refresh_token_ttl_days`（默认 7 天）。
- 刷新策略：刷新成功时签发新访问令牌并轮换刷新令牌（旧令牌立即撤销）。客户端必须用响应中的新刷新令牌替换本地值。
- 登出：按摘要撤销，重复调用返回成功，保证幂等。
- 理由：数据库只存摘要，泄露库表也无法直接复用令牌；轮换可限制刷新令牌被窃取后的窗口。
- 备选：JWT 同时承载刷新语义（无状态、不落库）。无法实现登出撤销与停用即时生效，不采用。

### 5. 每请求身份校验

`AuthFilter` 解析并验签访问令牌后，按用户 ID 查询 `users`，确认状态为 `ACTIVE`、账号未锁定，再写入 `CurrentUser` 上下文（含角色、部门、团队）。不使用“令牌有效即信任”的无状态模式。

- 理由：规格要求停用账号的既有令牌立即失效；单库规模下每请求一次主键查询成本可接受。
- 备选：令牌版本号或短期令牌 + 黑名单。前者仍需每请求查库，后者需要额外存储；当前阶段不引入。

### 6. 登录、锁定与停用

登录流程：按用户名查用户 → 校验状态与锁定 → BCrypt 校验密码 → 失败则 `failed_attempts + 1`，达到 `login_max_failures` 时写入 `locked_until = now + login_lock_minutes` 并清零计数语义 → 成功则清零计数、签发令牌。

- 锁定判断以 `locked_until` 与当前时间比较，过期后允许重试。
- 停用账号在登录和每次鉴权时都返回拒绝；启用后无需重新签发令牌即可恢复。
- 失败响应不区分“用户不存在/密码错误”，统一 `40101`，避免账号枚举。
- 理由：规则完全由 `system_configs` 驱动，Sprint 8 的配置管理接口只需改值，无需改代码。
- 备选：固定阈值写死。无法满足配置化要求。

### 7. 初始管理员

不使用迁移脚本写入默认密码。应用启动时由 `ApplicationRunner` 检查是否存在 `ADMIN` 角色用户；不存在且提供了 `ADMIN_INIT_PASSWORD` 时创建初始管理员，用户名取 `ADMIN_INIT_USERNAME`（默认 `admin`），密码经 BCrypt 存储；缺失环境变量时记录警告但不创建。

- 理由：避免仓库中出现可预测的默认口令，同时保证空库首次启动即可登录。
- 备选：迁移内置 `admin/admin123`。存在明显安全风险，不采用。

### 8. 测试与契约样例

- 单元测试：`PasswordService`、`JwtService`、锁定计数逻辑。
- 集成测试：`io.zonky.test:embedded-postgres` 启动与宿主机隔离的 PostgreSQL 实例（无需 Docker），验证空库迁移、重复启动、种子数据、部分唯一索引与 CHECK 约束。
- 契约测试：RestAssured 或 MockMvc 覆盖登录成功/失败、锁定、停用、刷新、登出幂等、`/me` 权限码、无注册入口。
- 契约样例：在 `documents/api-samples/` 下按认证、任务、公司展示、数据地图、日历分文件保存请求/响应 JSON，附 `README` 说明本地启动方式（样例不参与编译）。

- 理由：数据库约束只有真实 PostgreSQL 才能验证；契约样例让 Flutter/Web 在接口未实现前即可 mock。
- 备选：H2 内存库。无法验证部分唯一索引与 PostgreSQL 特有 CHECK 行为，不采用。

### 9. 配置与时间

数据库连接、JWT 密钥、初始管理员通过环境变量注入；`application.yml` 只保留本地默认值与非敏感配置。所有时间字段使用 `timestamptz`，业务日期按 `Asia/Shanghai` 计算，JVM 与数据库连接时区统一为该时区。

## Risks / Trade-offs

- [迁移顺序错误导致外键失败] → 按 V1 引用表、V2 组织用户、V3 日志、V4 任务固定顺序；集成测试从空库执行全部迁移。
- [每请求查库增加认证开销] → 只查主键与状态列，必要时加索引；当前用户规模下可接受，后续可加短 TTL 缓存。
- [刷新令牌轮换与客户端实现不一致] → 在契约样例中明确响应携带新刷新令牌；接口文档第 14 节确认后同步。
- [初始管理员未创建导致无法登录] → 启动日志明确提示缺失的环境变量；集成测试覆盖创建与跳过两条路径。
- [组织约束只落库、服务层校验未实现] → 本变更只保证数据库拒绝非法组合；团队长跨表一致性在 Sprint 3 服务层补齐，测试中标记为已知边界。
- [时区不一致导致令牌与锁定时间偏差] → 统一 `Asia/Shanghai` 与 `timestamptz`，测试覆盖跨日边界。

## Migration Plan

1. 合并代码后，在空库启动应用，Flyway 自动执行 V1–V4。
2. 配置 `ADMIN_INIT_PASSWORD` 后重启，创建初始管理员。
3. 使用管理员账号调用登录与 `/api/auth/me`，确认角色与权限码。
4. 回滚策略：本变更只新增表与代码，未修改既有 schema；如需回退，停止应用并删除新增表或使用 Flyway 反向脚本，客户端不受影响。

## Open Questions

- 刷新令牌是否强制轮换：本设计默认轮换，需在实现前由接口文档第 14 节确认；若客户端暂不支持替换，可退化为“仅校验有效期、登出撤销”。
- 初始管理员用户名是否固定为 `admin`：当前通过环境变量覆盖，默认 `admin`。
- 访问令牌有效期是否需要在 Sprint 8 配置接口中开放修改：当前读取种子值，修改配置后对新令牌生效。
