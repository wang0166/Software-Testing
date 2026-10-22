# API 契约样例

本目录提供 Pandora 后端接口的请求/响应样例，用于前端联调、Mock 与契约测试。所有样例均遵循统一响应结构：

```json
{ "code": 0, "message": "ok", "data": {} }
```

错误响应的 `data` 为 `null`，`code` 使用《后端接口文档》§12 的业务码。

## 文件说明

| 文件 | 对应接口 | 当前状态 |
|---|---|---|
| `auth.json` | `POST /api/auth/login`、`POST /api/auth/refresh`、`POST /api/auth/logout`、`GET /api/auth/me` | 已实现（Sprint 2） |
| `tasks.json` | `/api/tasks/**` 派发、接收、进度与检查 | 契约样例，后续 Sprint 实现 |
| `company-display.json` | `/api/company-matters`、`/api/company-important-tasks` | 契约样例，后续 Sprint 实现 |
| `task-map.json` | `GET /api/task-map` | 契约样例，后续 Sprint 实现 |
| `calendar.json` | `GET /api/calendar` | 契约样例，后续 Sprint 实现 |

每个文件包含 `baseUrl`、`description` 与 `cases[]`；每个用例含 `name`、`request`（`method`/`path`/`headers`/`body`）和 `response`（`status`/`body`）。

## 本地启动

### 1. 环境要求

- JDK 17 及以上（本机验证使用 JDK 21）
- Maven 3.9 及以上
- PostgreSQL 14 及以上，并已创建空库

```sql
CREATE DATABASE pandora;
```

### 2. 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| `SPRING_DATASOURCE_URL` | 否 | `jdbc:postgresql://localhost:5432/pandora` | 数据库连接串 |
| `SPRING_DATASOURCE_USERNAME` | 否 | `postgres` | 数据库用户名 |
| `SPRING_DATASOURCE_PASSWORD` | 否 | `postgres` | 数据库密码 |
| `JWT_SECRET` | 生产必填 | 本地开发密钥 | HS256 密钥，至少 32 字节 |
| `JWT_ISSUER` | 否 | `pandora-log` | 令牌签发者 |
| `ADMIN_INIT_USERNAME` | 否 | `admin` | 初始管理员用户名 |
| `ADMIN_INIT_PASSWORD` | 首次启动必填 | 空 | 初始管理员密码；为空时跳过创建并记录警告 |
| `SERVER_PORT` | 否 | `8080` | 服务端口 |

PowerShell 示例：

```powershell
$env:SPRING_DATASOURCE_URL="jdbc:postgresql://localhost:5432/pandora"
$env:SPRING_DATASOURCE_USERNAME="postgres"
$env:SPRING_DATASOURCE_PASSWORD="<数据库密码>"
$env:JWT_SECRET="<至少32字节的随机密钥>"
$env:ADMIN_INIT_PASSWORD="<初始管理员密码>"
mvn spring-boot:run
```

启动时 Flyway 自动执行 `classpath:db/migration` 下的迁移；仅当库中不存在管理员且提供了 `ADMIN_INIT_PASSWORD` 时创建初始管理员。

## 手工验证流程

以下命令基于 PowerShell，`$base` 为 API 前缀，健康检查不带 `/api`。

```powershell
$base = "http://localhost:8080/api"

# 1. 健康检查
Invoke-RestMethod "http://localhost:8080/actuator/health"

# 2. 登录
$login = Invoke-RestMethod -Method Post -Uri "$base/auth/login" `
  -ContentType "application/json" `
  -Body '{"username":"admin","password":"<初始管理员密码>"}'
$token = $login.data.accessToken
$refresh = $login.data.refreshToken

# 3. 当前用户与权限码
Invoke-RestMethod -Uri "$base/auth/me" -Headers @{ Authorization = "Bearer $token" }

# 4. 刷新令牌（旧刷新令牌随即失效）
$newTokens = Invoke-RestMethod -Method Post -Uri "$base/auth/refresh" `
  -ContentType "application/json" `
  -Body (@{ refreshToken = $refresh } | ConvertTo-Json)
$token = $newTokens.data.accessToken

# 5. 登出（重复调用同样返回成功）
Invoke-RestMethod -Method Post -Uri "$base/auth/logout" `
  -ContentType "application/json" `
  -Body (@{ refreshToken = $newTokens.data.refreshToken } | ConvertTo-Json)
```

预期结果：

- 健康检查返回 `{"status":"UP"}`。
- 登录返回 `code=0`，`data` 含 `accessToken`、`refreshToken`、`tokenType=Bearer`、`expiresIn` 与 `user`。
- `/auth/me` 返回用户摘要、`role`、`departmentId`、`teamId` 与 `permissions`。
- 使用旧刷新令牌再次刷新返回 401 `40102`。
- 登出后重复登出仍返回 `code=0`。

## Mock 使用

1. 将对应 JSON 文件导入 Postman（Collection 或 Mock Server）、Apifox 或 WireMock。
2. 以 `baseUrl` + `request.path` 作为匹配规则，按 `response.status` 与 `response.body` 返回样例。
3. `request.headers.Authorization` 中的 `<..._TOKEN>` 为占位符，Mock 场景可忽略具体值，只校验是否携带 Bearer 令牌。
4. 前端可据此先行开发页面；联调时替换为真实服务地址，字段与错误码保持不变。

## 注意事项

- 认证端点不提供注册或自助开户；账号只能由管理员后续接口创建。
- 刷新令牌在服务端仅保存 SHA-256 摘要，刷新成功后旧令牌被撤销，登出按摘要撤销且幂等。
- `tasks.json`、`company-display.json`、`task-map.json`、`calendar.json` 为接口文档冻结的契约样例，对应接口尚未在本 change 中实现，字段如与最终实现不一致，以接口文档修订为准。
