# 验收记录：bootstrap-backend-foundation-and-auth

记录时间：2026-10-18

## 1. 环境

| 项目 | 值 |
| --- | --- |
| JDK | 21.0.11（编译目标 Java 17） |
| Maven | 3.9.16 |
| 数据库 | 嵌入式 PostgreSQL 14.15（`io.zonky.test:embedded-postgres`，无需 Docker） |
| 数据库端口 | 55432，`trust` 认证，库 `pandora_acceptance` |
| 应用端口 | 18080 |
| 环境变量 | `SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:55432/pandora_acceptance`、`JWT_SECRET=acceptance-secret-key-0123456789abcdef`、`ADMIN_INIT_PASSWORD=Acceptance#2026` |

## 2. 启动与迁移

空库启动后日志按序出现：

1. `Current version of schema "public": << Empty Schema >>`
2. 依次应用 `V1`–`V4`
3. `Successfully applied 4 migrations ... now at version v4`
4. `已创建初始管理员账号 'admin'`

## 3. 接口验收结果

| 场景 | 请求 | 实际结果 | 结论 |
| --- | --- | --- | --- |
| 健康检查 | `GET /actuator/health` | 200，`status=UP` | 通过 |
| 管理员登录 | `POST /api/auth/login` | 200，`code=0`，`tokenType=Bearer`，`expiresIn=7200`，`user={id:1, username:"admin", realName:"系统管理员", role:"ADMIN", departmentId:null, teamId:null}` | 通过 |
| 当前用户 | `GET /api/auth/me` | 200，权限码为 `audit:read`、`company-matter:manage`、`config:manage`、`content:read`、`log:read`、`org:manage`、`role:manage`、`stats:read`、`user:manage`，不含 `task:dispatch`、`task:execute`、`task:self` | 通过 |
| 刷新令牌 | `POST /api/auth/refresh`（间隔 2 秒） | 200，`accessTokenChanged=true`，`refreshTokenChanged=true`，`expiresIn=7200` | 通过 |
| 旧刷新令牌重放 | `POST /api/auth/refresh`（使用已轮换令牌） | 401，`{"code":40102,"message":"刷新令牌无效或过期","data":null}` | 通过 |
| 登出幂等 | `POST /api/auth/logout` 连续两次 | 两次均 `code=0` | 通过 |
| 无注册入口 | `POST /api/auth/register`（携带有效令牌） | 404，`{"code":40400,"message":"资源不存在","data":null}` | 通过 |
| 无效访问令牌 | `GET /api/auth/me`（伪造令牌） | 401，`{"code":40102,"message":"访问令牌无效或过期","data":null}` | 通过 |

失败密码、锁定、停用、参数校验与员工登录等场景由 `AuthContractTest`（17 项）覆盖，结果见第 4 节。

## 4. 自动化测试

`mvn -B package` 结果：BUILD SUCCESS，测试 38 项，0 failures / 0 errors / 0 skipped。

| 测试类 | 数量 | 覆盖范围 |
| --- | --- | --- |
| `AuthContractTest` | 17 | 认证 spec 全部 5 个 Requirement |
| `DatabaseMigrationTest` | 10 | 空库迁移、种子、幂等、18 张表、关键约束 |
| `JwtServiceTest` | 4 | 访问令牌签发、解析、过期、篡改 |
| `PasswordServiceTest` | 4 | BCrypt 加密与校验 |
| `LoginAttemptPolicyTest` | 3 | 失败计数与锁定时间计算 |

产物：`target/pandora-log-backend-0.1.0-SNAPSHOT.jar`。

## 5. 遗留项

1. 刷新令牌轮换策略（是否允许并发刷新、旧令牌重放检测窗口）待 `documents/后端接口文档.md` 第 14 节确认；当前实现为刷新即轮换并撤销旧令牌，重放返回 `40102`。
2. 团队长与团队/部门跨表一致性校验由 Sprint 3 服务层实现；本次仅落地数据库层 `chk_users_org_alignment` 与部分唯一索引。
3. `documents/api-samples/` 中 `auth.json` 对应已实现接口；任务、公司展示内容、数据地图、日历样例为契约样例，待对应 Sprint 实现后校验。
