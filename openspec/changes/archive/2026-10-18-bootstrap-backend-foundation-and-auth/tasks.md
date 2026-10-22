## 1. 契约与工程基线

- [x] 1.1 按 `documents/后端接口文档.md` §2 与 §3 冻结认证端点、请求/响应字段、`40101`/`40102`/`40103` 与权限码清单，确认无注册入口（对应 `tasks.md` 1.1）。
- [x] 1.2 按技术设计 §6 核对用户/角色/组织/刷新令牌/日志/任务六表与索引，确认迁移顺序为引用表、组织用户、日志、任务（对应 1.2）。
- [x] 1.3 确认组织约束落地方式：`chk_users_org_alignment`、创始人/部门老总/团队长部分唯一索引、删除 RESTRICT，团队长跨表一致性留给 Sprint 3 服务层（对应 1.3）。
- [x] 1.4 创建 Maven `pom.xml`，引入 Spring Boot 3、Java 17、Web、Validation、Security、MyBatis、Flyway、PostgreSQL 驱动、Actuator 与测试依赖。
- [x] 1.5 建立 `com.pandora.log` 包结构与 `PandoraApplication`，包含 `common/config/security/controller/service/mapper/entity/dto/job/audit` 分层（对应 1.4）。
- [x] 1.6 编写 `application.yml`，数据库、JWT 密钥、初始管理员均从环境变量读取，时区固定 `Asia/Shanghai`，控制器统一挂载 `/api` 前缀。
- [x] 1.7 实现 `ApiResponse`、`PageResult`、`ErrorCode`、`BusinessException` 与全局异常处理，覆盖参数校验、认证、无权限、业务冲突和未捕获异常（对应 1.4）。
- [x] 1.8 启用 Actuator 健康检查与 CORS/MyBatis/Security 基础配置，补充启动冒烟测试验证应用可启动且响应结构为 `code/message/data`。

## 2. Flyway 基础迁移与种子

- [x] 2.1 编写 `V1__create_reference_tables.sql`，创建 `roles`、`permissions`、`role_permissions`、`system_configs` 及主键/唯一约束（对应 1.5）。
- [x] 2.2 在 V1 写入 5 个角色、15 个权限码、角色权限映射与 5 项系统配置默认值，权限码包含 `task:dispatch`、`task:execute`、`task:self`、`content:read`、`company-matter:manage`、`company-task:manage`。
- [x] 2.3 配置 Flyway 随应用启动执行，补充迁移集成测试：空库一次迁移到最新、种子数据存在、重复启动不重复执行。

## 3. 组织与用户表迁移

- [x] 3.1 编写 `V2__create_organization_and_user_tables.sql`，创建 `companies`、`departments`、`teams`、`users`、`refresh_tokens` 及外键，组织删除使用 RESTRICT（对应 2.1）。
- [x] 3.2 为用户表增加 `chk_users_role`、`chk_users_status`、`chk_users_org_alignment`，覆盖员工/团队长必须有部门和团队、部门老总不得带团队、创始人/管理员不得有组织归属。
- [x] 3.3 建立创始人、部门老总、团队长的部分唯一索引，以及用户状态、部门/团队归属、刷新令牌摘要与过期时间的查询索引（对应 2.2）。
- [x] 3.4 补充约束集成测试：重复负责人被部分唯一索引拒绝、非法角色-组织组合被 CHECK 拒绝、有成员或子级的组织删除被 RESTRICT 拒绝。

## 4. 日志与任务表迁移

- [x] 4.1 编写 `V3__create_log_tables.sql`，创建 `work_logs` 与 `log_comments`，包含 `UNIQUE(author_id, log_date)`、内容非空 CHECK 与查询索引。
- [x] 4.2 编写 `V4__create_task_tables.sql`，创建 `tasks`、`task_assignments`、`task_reviews`、`personal_tasks`、`company_matters`、`company_important_tasks`（对应 2.2）。
- [x] 4.3 为任务表补充 `UNIQUE(task_id, assignee_id)`、`CHECK(deadline >= start_date)`、状态/紧急程度 CHECK 及派发人、接收人、任务状态查询索引。
- [x] 4.4 补充迁移测试，确认空库迁移后组织、日志、任务、配置表及关键约束全部存在，且任务六表可被 MyBatis 映射。

## 5. 认证核心

- [x] 5.1 实现 `PasswordService`，使用 BCrypt 校验与加密密码，禁止明文或弱哈希存储。
- [x] 5.2 实现 `JwtService`，按 `access_token_ttl_minutes` 签发访问令牌，解析时校验签名、过期时间与用户标识。
- [x] 5.3 实现刷新令牌仓储：仅保存 SHA-256 摘要、有效期与撤销时间，刷新成功时轮换并撤销旧令牌，登出按摘要撤销且幂等（对应 2.3）。
- [x] 5.4 实现 `AuthFilter` 与 `CurrentUser` 上下文，验签后查询用户状态，拒绝停用或锁定账号，并统一输出 401/403 响应（对应 2.4）。
- [x] 5.5 实现 `POST /api/auth/login`，成功返回 `accessToken`、`refreshToken`、`tokenType`、`expiresIn` 与用户摘要，错误凭据统一返回 401/`40101`（对应 2.3）。
- [x] 5.6 实现 `POST /api/auth/refresh`、`POST /api/auth/logout`，无效或过期刷新令牌返回 401/`40102`，登出重复调用成功。
- [x] 5.7 实现 `GET /api/auth/me`，返回用户摘要、角色、部门/团队与有效权限码，管理员不包含 `task:dispatch`、`task:execute`、`task:self`。
- [x] 5.8 实现失败计数与锁定：达到 `login_max_failures` 后锁定 `login_lock_minutes` 并返回 423/`40103`，成功登录清零计数；停用账号登录返回 401/`40103`（对应 2.5）。
- [x] 5.9 实现启动时初始管理员创建：仅在不存在管理员且提供 `ADMIN_INIT_PASSWORD` 时创建，缺失时记录警告且不写入默认口令。
- [x] 5.10 确认 `/api/auth` 下不存在注册或自助开户端点，所有账号只能由管理员后续接口创建。

## 6. 测试与契约样例

- [x] 6.1 为 `PasswordService`、`JwtService`、失败计数与锁定时间计算编写单元测试。
- [x] 6.2 编写认证契约测试：登录成功、错误密码、锁定、停用、过期/无效令牌、刷新、登出幂等、`/me` 权限码与无注册入口（对应 2.6）。
- [x] 6.3 使用嵌入式 PostgreSQL（`io.zonky.test:embedded-postgres`，无需 Docker）运行全部迁移与约束测试，确保与真实数据库行为一致。
- [x] 6.4 在 `documents/api-samples/` 下提供认证、任务、公司展示内容、数据地图、日历的请求/响应样例，并附本地启动与 mock 使用说明（对应 1.6）。
- [x] 6.5 执行 `mvn test` 与打包，确认认证契约测试、迁移测试和单元测试全部通过。

## 7. 验收与交接

- [x] 7.1 在空库按文档环境变量启动应用，调用健康检查、登录、`/me`、刷新与登出，记录可复核的运行结果。
- [x] 7.2 核对并更新根目录 `tasks.md` 中 Sprint 1 的 1.1–1.6 与 Sprint 2 的 2.1–2.6 完成状态。
- [x] 7.3 记录遗留项：刷新令牌轮换策略待接口文档第 14 节确认，团队长跨表一致性校验由 Sprint 3 完成。
- [x] 7.4 运行 `openspec validate "bootstrap-backend-foundation-and-auth" --strict`，确认变更可进入实现与归档流程。
