# 潘多拉 Web 管理端（成员3）

React18 + Router6 + Vite5，管理员专用后台。

## 跑起来

```bash
npm install
npm run dev
```

浏览器开 `http://localhost:5174`，演示账号 `admin` / `123456`。

## 接口对接（严格对齐 documents/接口文档.md）

- 统一壳 `{code, message, data}`，`code===0` 为成功
- 分页 `data: {items, page, size, total}`（文档第1.1节）
- 角色传输用英文枚举（`EMPLOYEE`/`TEAM_LEADER`/`DEPT_MANAGER`/`FOUNDER`/`ADMIN`），界面显示中文
- HTTP 管协议层，`code` 是业务错误码（40103/40301/40901等），`ApiError` 统一处理
- 切真后端：`.env.local` 设 `VITE_API_BASE=http://localhost:8080/api` + `VITE_USE_MOCK=false`

## 路由

- `/login` 登录（POST /auth/login）
- `/users` 用户管理（GET/POST /users，PATCH /users/{id}/status，PUT /users/{id}/password）
- `/org` 组织/角色/配置（/departments、/teams、/roles、/permissions、/configs、/company-matters）
- `/logs` 日志只读（GET /logs，管理员不可改删）
- `/stats` 统计只读（GET /stats/overview、/stats/unsubmitted、/audits）

## 目录

```
src/api/http.ts    统一请求：Bearer、响应壳解包、错误码映射、分页
src/api/client.ts  各接口方法 + mock 数据（VITE_USE_MOCK 控制切换）
src/constants/roles.ts  5角色中文/英文映射、归属约束、权限码
src/components/ui.tsx    Toast/Modal/StatCard/Ring/Empty/Skeleton
src/theme.css            视觉 v3 主题
```

## 联调清单

- 成员1：后端接口就绪后改 `.env.local` 两个环境变量即可，页面不动
- 成员5：DDL 确认后对照 `users.status`（1启用/0停用）校验
- 成员4：用例可按本页 5 个路由覆盖功能点
