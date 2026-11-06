# Pandora 潘多拉 · V1.9.0 任务管理闭环（Flutter）

## 对甲方本轮要求的实现范围

- **收到的任务**：多列表格继续横向/纵向滚动，新增独立“完成率”列；点击任务进入新的任务执行详情页。详情含类型、紧急度、受阻/逾期、任务正文、负责人、起止时间、完成率、最近进度备注以及按时间排序的流转记录。
- **执行进度**：选择待开始/进行中/受阻/已完成，按 0–100% 填报进度与进度备注；受阻必须填写原因，完成必须是 100%，重复提交无效数据会被阻止。已完成任务通过已有的“邀请完成检查”流程，不能绕过审核直接退回执行中。
- **我发布的任务**：保留待审核创建申请、编辑申请、删除申请及撤回功能。点击“详情”可以查看已发布任务的接收人员、各自的执行状态、完成百分比（服务端有返回时）、进度备注和完成检查结果。发布人可以按既有接口通过/退回接收人的**完成检查**。这与管理员审核“任务派发/修改/删除”是两种不同审批。
- **下属动态**：在现有成员摘要中增加受阻和逾期数量；下属详情列出完成率及进度填报数量。所有数据只来自当前身份被允许访问的下属汇总接口。
- **其他**：底部导航、四大信息面板、默认任务日历、甘特图、日志及 AI 地图页面均不改动。

## 服务端对接：重要！V1.9 的两个新增接口尚需后端实现

手机真实模式使用 `PANDORA_DEMO=false`。**Flutter 前端已经实现新接口的调用，但不等于服务器已支持新接口。** 当前 Spring Boot 后端可能返回 404/405/501，此时显示失败提示，不会把演示数据写入真实服务器，也不会伪称保存成功。

### A. 接收任务进度记录（新增）

- `POST /api/tasks/assignments/{assignmentId}/progress-updates`
- 请求体（JSON）：

```json
{"status":"IN_PROGRESS","progressPercent":65,"note":"登录接口已完成联调，正在检查权限"}
```

- 响应与项目现有格式对齐：`{"code":0,"message":"ok","data":{"id":17,"createdAt":"2026-11-02T14:30:00+08:00"}}`
- 需要检查当前账号**确为该派发记录的接收人**；校验进度 0–100、状态及备注；**事务内**更新任务分派当前状态、进度和最近备注，同时插入不可变历史记录，写审计时间、操作人。不得允许客户端使用 senderId/assigneeId 越权写入别人任务。
- “完成”不代表通过上级验收；验收仍经 `/tasks/assignments/{id}/review-invitations` 和发布人检查接口。

### B. 获取进度历史（新增）

- `GET /api/tasks/assignments/{assignmentId}/progress-updates`
- 示例：

```json
{"code":0,"message":"ok","data":{"items":[{"id":17,"status":"IN_PROGRESS","progressPercent":65,"note":"完成登录联调","authorName":"张同事","createdAt":"2026-11-02T14:30:00+08:00"}],"total":1}}
```

- 历史查询必须限制给接收人及其**被授权的管理人员**。记录应含执行人更新、发布人的完成检查（若整合为统一流转），不可随意覆盖历史。建议接口分页并按时间倒序，当前前端一次展示接口返回的记录。

### C. 已有接口需要补字段

- `GET /api/tasks/received` 或分页列表中，任务项应包含 `assignmentId,executionStatus,progressPercent,progressNote,progressUpdatedAt,assigneeName,deadline,reviewStatus`。
- `GET /api/tasks/{taskId}` 中的 `assignments[]` 可增加 `progressPercent,progressNote,executionStatus,reviewStatus`，以便发布人查看各接收人的工作情况。**未提供进度时页面显示“未填报”，绝不臆造百分比。**
- `GET /api/tasks/subordinates/overview` 内 `tasks[]` 也返回进度及截止时间，**后端先做组织层级和角色权限过滤**。前端不能简单用“全部员工任务”列表进行客户端过滤替代权限校验。
- 已有任务创建/修改/删除审批接口与此版本独立，仍由管理员审核通过后才生效。

## 演示模式说明

`PANDORA_DEMO=true`：本地 `SharedPreferences` 按用户、任务分别保存更新和进度记录，适合在模拟器展示。演示模式进度不会写进 PostgreSQL，也**不能**代替后端审核。

## 建议运行顺序

在项目 `mobile/` 目录执行：

```powershell
flutter pub get
flutter analyze
flutter test test/v19_task_progress_test.dart
flutter test
flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=true
```

验证：登录 `demo001 / demo123456` → 视图 → 任务清单 → 收到的任务 → “完成模块联调” → 更新进度（例如 70%，补充备注）→ 返回台账检查百分比 → 重新打开历史记录。切换 “我发布的任务”，查看已发布任务的接收人；若无已发布记录则以演示身份 `leader` 发布一项任务。

真机联调时先确保 Spring Boot / 数据库运行和 ADB reverse 端口映射。**真实模式的两个进度接口需要后端同学新增**。

## Git 新分支

此包不能替你在 Windows 本地运行 Git。先在 **项目根目录**（`D:\Projects\Software-Testing`）确认没有未提交修改，执行：

```powershell
git status
git switch -c feat/pandora-task-workflow-v1.9
```

然后将覆盖包中 `mobile/` 内容复制到项目的 `mobile/` 目录，确认测试通过后：

```powershell
git add mobile/
git commit -m "feat(mobile): task progress history and issuer oversight v1.9"
git push -u origin feat/pandora-task-workflow-v1.9
```

注意不能直接 `git pull origin feature/web-admin` 合并后端同学分支进自己的分支；继续用已有 Git Worktree 本地联调。

## 已知限制与交付验证

- 目前制作环境没有 Flutter SDK，**无法实际执行 `flutter analyze`/`flutter test`/Android 模拟器编译**。代码变更已静态检查和打包，实际运行请以你本机命令为准。
- 本版本未修改 Spring Boot 服务及数据库。真实进度/审批功能需要后端接口对接；数据库 schema migration 由后端同学管理。
- 改动基于先前交付的 V1.8.0 完整源码并合并上一轮“AppFailure 编译错误”热修复；若你本机额外修改过相同 Dart 文件，覆盖前先用 Git diff 比对。
