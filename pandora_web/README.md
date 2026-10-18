# 潘多拉 Web 管理端（成员3）

React18 + Router6 + Vite5，管理员只用 Web，只读日志与统计。

## 跑起来

```bash
npm install
npm run dev
```

浏览器开 `http://localhost:5174`，输名字登录即可。

## 路由

- `/login` 登录（假登录，换成员1 `POST /api/auth/login`）
- `/users` 用户管理（本地增删改，换成员1 `GET/POST/DELETE /api/users`）
- `/org` 组织/角色/配置（等成员5数据字典对字段）
- `/logs` 日志只读（换成员1 `GET /api/logs`，不可改）
- `/stats` 统计只读（换成员1 `GET /api/stats`）

## 联调清单（找人要）

- 成员1：接口契约（地址/参数/返回/401-403）
- 成员5：数据字典（5张表字段名）+ ER图
- 成员2：墨刀链接（字段同一套）
- 成员4：用例模板（自测一遍）

接口到了只改 `src/api/client.ts` 一处，页面不用动。
