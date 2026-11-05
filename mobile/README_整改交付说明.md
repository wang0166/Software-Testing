# 智能掌上日志系统（潘多拉 Pandora）—移动端整改交付

版本：V1.1.0（2026-10-29），基于用户提供的 Flutter Android 移动端源代码整改。

## 立即使用

1. **先备份现有 `mobile` 项目**；保留现有后端和 Web 端，不要覆盖。
2. 将覆盖包中 `mobile/` 下的文件按相同相对路径拷入原 `mobile/` 项目。新文件也一并复制；不要删除其他业务源文件。
3. 删除废弃文件 `lib/pages/home/home_page.dart` 和 `lib/services/mock_auth_service.dart`（两者为未使用的旧示例）。
4. 在 `mobile/` 根目录执行：

   ```powershell
   flutter clean
   flutter pub get
   flutter analyze
   flutter test
   flutter run --dart-define=PANDORA_DEMO=true
   ```

5. 联调后端时运行：

   ```powershell
   flutter run --dart-define=PANDORA_DEMO=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
   ```

   `10.0.2.2` 是 Android 模拟器访问宿主机的地址，真机应使用可达的服务器地址。生产环境应使用 HTTPS。

> 新增依赖 `image_picker`，**必须运行 `flutter pub get`** 以更新依赖和 `pubspec.lock`。
> 由于当前交付环境没有 Flutter/Dart SDK 和 Android 模拟器，此包未实际执行 `flutter analyze`、`flutter test` 或 APK 编译；需要在你的电脑上执行以上命令核验。

## 界面与业务调整

| 功能 | 修改 |
|---|---|
| 导航 | **导图 / 视图 / 日志 / AI地图 / 我的**，名称顺序固定 |
| 导图 | 首屏四大信息面板：**公司10大重要事项展示、公司10大任务派发、个人10大信息展示、日志展示**；移除原欢迎、快捷入口、统计卡片的首屏占用 |
| 视图 | 集中进入任务清单、日历视图、统计看板，并保留任务甘特图 |
| 任务清单 | 仅展示「收到的任务」和「派发任务」两个选项；移除自建任务入口和页面 |
| 任务派发 | 开始时间与截止时间均支持**年月日 + 小时分钟**选择，截止必须晚于开始时间 |
| 日历 | 点击年月日期可直接打开日期选择器，从年开始选择、再选月和日，保留月/周/日/甘特图 |
| 日志 | 授权范围内按**部门 → 团队 → 日志**组织，提供部门筛选、我的日志和搜索 |
| 日志编辑 | 每日一条、22:00 截止、草稿/提交仍经原 repository；本机加密临时保留未送出的编辑内容（尽力恢复） |
| 账号 | 登录页有「忘记密码？」；个人中心有「设置」入口；设置中可更换本机头像、申请修改密码并查看审核状态 |
| AI地图 | 现在按状态可视化**收到的任务**；未接入真正的 AI 推理服务，页面已明确说明，不会虚构 AI 结论 |

## 必须知道的对接边界

- **头像**：图片选择和本机保存可用；跨设备同步需要后台提供头像上传/读取接口。本项目原 API 没有头像接口，所以界面没有伪称“上传成功”。
- **密码审核**：完整生产业务需要 Web 管理员审核的服务端 API。已在 `ApiRepository` 增加调用入口，具体契约见 `README_后端接口对接.md`。演示模式只能生成本机 PENDING 申请，不能代替 Web 审核。
- **日志部门分类**：演示数据可以按部门/团队显示。真实 API 要在日志列表中返回作者 `departmentId/teamId` 与部门/团队名称，或者提供可按 ID 查询的组织结构；缺失时页面显示“未标注部门”，不会猜测。
- **任务分钟精度**：移动端会发送 `YYYY-MM-DDTHH:mm:ss`，后台必须按分钟保存和校验；如果后端字段目前只有 `DATE`，必须调整接口和持久层。
- **个人10大信息**：当前根据可访问的**个人最近十条日志**展示基础提要；真正“重点提取、置顶、排序和手动维护”仍需要后端接口或业务规则支持。
- **公司10大事项和任务**：使用已有 `/company-matters` 和 `/company-important-tasks`；仅在弹层展示前 10 条，若需“管理员指定十大”须服务端排序。
- **权限/审计**：前端不具备安全强制力，服务端必须落实组织可见性、直属上级点评、管理员审核、22:00 自动处理、审计日志及密码哈希。

## 保留与未更改

登录、JWT 令牌刷新、工作日志、点评对话、统计图表、任务进度和检查、日历甘特图沿用原项目 repository 及 Spring Boot 服务端接口；本次**未提供或篡改后端代码**。

## 交付内容

- `lib/screens/home_page.dart`：四大信息面板首页
- `lib/screens/shell_page.dart`：五项主导航
- `lib/screens/view_page.dart`：新增视图导航页
- `lib/screens/tasks_page.dart`：两类任务
- `lib/screens/dispatch_page.dart`：分钟级派发
- `lib/screens/calendar_page.dart`：年月日直选
- `lib/screens/logs_page.dart`：部门团队日志、编辑内容恢复
- `lib/screens/profile_page.dart`、`settings_page.dart`：个人设置、头像、密码申请
- `lib/screens/login_page.dart`：忘记密码入口
- `lib/screens/task_map_page.dart`：AI地图任务可视化入口
- `lib/core/models.dart`、`gantt_utils.dart`：组织信息及分钟时间解析
- `lib/data/*`：组织演示数据、权限及密码接口约定
- `pubspec.yaml`、`android/app/src/main/AndroidManifest.xml`、`test/*`：依赖、应用名称和测试

