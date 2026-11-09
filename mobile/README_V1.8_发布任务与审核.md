# 潘多拉 Pandora V1.8.0 — 我发布的任务、编辑审核、撤回与删除

## 本次交互

进入【视图 → 任务清单】：

- **收到的任务**：默认显示，保留原来的双向滚动任务执行台账、进度更新与详情。
- **我发布的任务**：显示本人已发布任务和创建审批中的任务。每项展示任务标题、类型、接收人数、截止时间和状态。
- **创建**：仍通过视图右下角的【＋创建任务】进入。创建成功后自动打开【我发布的任务】，便于查看待审核状态。
- **编辑**：本人可以重复发起修改。对已发布任务，编辑会创建待审核的修改申请，审核前原任务不变；尚未通过的创建申请可以更新申请内容，仍处于待审核状态。
- **删除**：尚未批准的创建申请可以撤回；已发布任务通过确认后提交删除审核申请，批准前保留原任务和接收人数据。存在待审核修改/删除时，禁止重复提交。
- 管理员审批流程在 **Web Admin / Spring Boot** 实现，不在移动端伪造审核通过。

## 后端必须新增/确认的接口契约

以下均在已配置的 `API_BASE_URL` 下，响应采用现有的 `{code:0,message,data}` 结构。这是**待对接的接口建议**，不代表后端已经实现。所有返回内容必须由服务端按当前 token 的用户身份过滤。

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/tasks/dispatched?page=1&size=50` | 已存在的“本人已发布任务”列表；建议返回 `id,name,details,startDate,deadline,urgency,taskType,assigneeIds,assigneeCount,changePending` |
| GET | `/tasks/dispatch-requests/mine?page=1&size=50` | **新增**：本人创建的任务派发申请（包含 `requestId,name,details,startDate,deadline,urgency,taskType,assigneeIds,status`） |
| PUT | `/tasks/dispatch-requests/{requestId}` | **新增**：仅能更新本人 `PENDING` 的创建申请，返回 `data.status=PENDING` |
| DELETE | `/tasks/dispatch-requests/{requestId}` | **新增**：仅能撤回本人 `PENDING` 的创建申请，返回 `data.status=WITHDRAWN` |
| POST | `/tasks/{taskId}/change-requests` | **新增**：提交修改/删除申请；修改 `action=UPDATE` 携带新字段，删除 `action=DELETE`；返回 `data.status=PENDING` |
| GET | `/tasks/{taskId}` | 已有详情；必要时返回 `assignments[*].assigneeId` 用于编辑时保留原接收人 |

### 编辑申请示例

```json
{"action":"UPDATE","name":"客户对接计划更新","details":"补充交付清单","startDate":"2026-11-03T09:30:00","deadline":"2026-11-10T18:45:00","urgency":"URGENT","taskType":"OPERATION","assigneeIds":[12,13]}
```

### 删除申请示例

```json
{"action":"DELETE"}
```

### 审批安全要求

1. **仅发布人**能请求修改/删除本人任务；严禁通过客户端提供 senderId 冒充身份。
2. 修改/删除申请需要由管理员审核；批准之前 **不能 UPDATE/DELETE 实际任务及其分派关系**。
3. 后端要阻止同一任务同时存在多个待审核变更，建议加数据库唯一性/事务约束，防重放、防重复提交。
4. 审批通过后原子更新任务、接收人和日历/任务地图数据；删除建议软删除并写入审计日志，必要时保留历史任务用于追溯。
5. 同步公开 `changePending` 或 `changeRequestStatus=PENDING`，以便移动端禁用重复申请。
6. 对创建/修改/删除/撤回等操作记录人员、时间、字段差异、审批结果。权限必须由服务端校验，不能仅靠 Flutter 隐藏按钮。
7. 审核前后状态变更应通知发布人和接收人，并使任务列表与日历在刷新后同步。

## 与当前后端联调的限制

当前 `ApiRepository` 已有 `/tasks/dispatched`，但新接口尚需后端同学开发。如 `/tasks/dispatch-requests/mine` 不存在，页面仍可显示已发布任务，并明确提示“派发申请记录尚不可用”；不会显示不存在的待审核记录，也不会伪造修改/删除成功。

若没有后端新增接口，真实模式中的“编辑”“删除申请”会提示失败，这是符合预期的安全降级；演示模式会在本机保存待审申请，但不会凭空批准发布或删除。

## 本地使用与验证

1. 备份当前分支，再覆盖 ZIP 中的 `mobile/` 相关路径。
2. `flutter pub get && flutter analyze && flutter test`
3. `flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=true`
4. 登录 `demo001 / demo123456` → 视图 → 任务清单 → 我发布的任务。
5. 点击右下角“创建任务”→ 选择公司成员 → 提交 → 自动回到我发布的任务 → 待审核 → 编辑/撤回。
6. 使用 `leader / demo123456` 也可以通过仓库演示测试验证“已发布任务编辑/删除需要审核”的状态机制。

**本次改动为 Flutter 客户端 + 演示 Repository，不包含真实 Spring Boot / Web Admin 新接口实现。**
