# 潘多拉 Pandora —移动端待对接接口契约（建议稿）

本说明是**新增接口建议稿，不代表你们现有服务端已实现**。后端负责权限校验、审批、操作审计与存储。

## 登录前忘记密码

`POST /api/auth/password-reset-requests`

请求：`{"username":"登录账号"}`

要求：返回统一的请求接收提示；防暴力破解与账户枚举；在 Web 管理端可查看申请并作审批。批准后必须通过身份验证或受控的重置流程才能设置新密码。不可把新密码发送给普通管理人员。

## 已登录密码修改

`POST /api/account/password-change-requests`：提交修改密码申请，默认 `PENDING`。应禁止重复待审申请。

`GET /api/account/password-change-requests/me`：返回 `{ "status": "NONE|PENDING|APPROVED|REJECTED" }`（由通用 `{code:0,data:...}` 包裹）。

`POST /api/account/password-change`：请求 `{"newPassword":"..."}`。仅在本人最近一次有效申请状态为 `APPROVED` 且审批未过期时允许；消费审批、哈希存储、撤销已有会话及写审计日志。**不要将密码存入客户端本地数据库或明文存入后端。** 建议服务端另行校验当前密码/二次验证。

Web 端管理员需有查看、批准、拒绝申请的独立接口与 UI；移动端目前未包含 Web 管理员审核界面。

## 任务派发分钟精度

现有 `POST /api/tasks` 请求字段 `startDate`、`deadline`：

```json
{"name":"任务名称","details":"任务详情","startDate":"2026-10-29T09:30:00","deadline":"2026-10-29T17:45:00","urgency":"NOT_URGENT","assigneeIds":[12]}
```

后端需用 `LocalDateTime`/`TIMESTAMP` 或同等类型，明确 Asia/Shanghai 时区，严格检验截止晚于开始，返回时保留小时分钟；使用服务端组织关系限制直属下级派发。其他 `/tasks/received`、`/tasks/dispatched`、`/calendar`、`/task-map` 应保持时间精度一致。

## 日志组织信息

`GET /api/logs` 每条建议附加：

```json
{"id":101,"authorId":12,"authorName":"林小满","authorRole":"EMPLOYEE","departmentId":3,"departmentName":"技术研发部","teamId":8,"teamName":"移动研发团队","logDate":"2026-10-29","content":"...","status":"SUBMITTED"}
```

也支持嵌套的 `author.role/author.departmentId/author.teamId/author.departmentName/author.teamName`。

为了在移动端**准确隐藏非直属上级的点评交互**，需要返回 `authorRole` 或 `author.role`。若角色缺失，前端保守地隐藏点评入口，绝不自行推测或越权查看。**必须先由服务端按公司/部门/团队/用户角色过滤可见日志**；列表展示层级不得替代权限校验。直接上级点评对话只向作者和直属上级提供。

## 头像同步（尚未实现）

如果需要跨设备用户头像，建议新增受认证保护的 `POST /api/account/avatar`（multipart 文件）、`GET /api/account/avatar` 或返回图片 URL；限制 MIME、大小，图片存储走受控对象存储并覆盖审计。当前仅提供本机图片选择与本机保存。

## 四大信息面板

现有 `/company-matters`、`/company-important-tasks` 和 `/logs` 已用于首页；如需各“十大”按重要性排序，需为公司事项和个人事项提供 `priority/rank` 或专用列表接口。

## AI地图（尚未实现模型服务）

现有 `/task-map` 只提供任务列表。目前的页面仅按任务状态展示节点。如需真正 AI 关系图，需增加如 `POST /api/ai/task-graph` 或经确认的后端接口，具备输入授权校验、输出引用、隐私保护，并禁止未经授权的外部数据发送。
