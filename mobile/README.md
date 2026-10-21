# 潘多拉 Flutter Android 移动端

基于项目组的《产品需求文档》《后端接口文档》《技术设计文档》制作。视觉风格为清新薄荷绿 + 暖杏色、卡片分层布局，支持不同屏幕尺寸。

## 安装与运行

将 `lib/`、`test/`、`pubspec.yaml` 合并或覆盖到本机已经执行过 `flutter create` 的 `mobile` 项目中。**请保留本机的 `android/` 平台工程**：此包不覆盖 Gradle、NDK、签名等设置。

```powershell
cd D:\Projects\Software-Testing\mobile
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554
```

项目使用 Dart 3.6+、Flutter 3.29+（建议以您已安装的 3.47.7 为准）。

## 运行模式

**默认 Mock 模式**：不依赖 Spring Boot，演示账号会在登录页提供快捷填充。代码在 `lib/data/mock_repository.dart` 中；修改日志、任务等数据会在模拟器本机持久化。模拟账号共用密码 `demo123456`。

**真实后端模式**：在团队后端启动并确认接口实现后：

```powershell
flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

服务器默认采用统一 `{code, message, data}` 响应。认证采用 `POST /auth/login`、`POST /auth/refresh`、`GET /auth/me`、`POST /auth/logout`；令牌存储在 `flutter_secure_storage`。`10.0.2.2` 是 Android 模拟器访问宿主机本地服务的专用地址。**真实手机应填写可访问的服务地址且优先使用 HTTPS。**

### Android 网络权限（仅真实后端模式）

当接入后端时，请在现有 `android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 内、`<application>` 外确保存在：

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

若本地后端暂时只支持 HTTP，针对**调试构建**可在 `android/app/src/debug/AndroidManifest.xml` 的 `<application>` 元素临时设置 `android:usesCleartextTraffic="true"`；不要在生产版本中允许任意明文网络连接。部署前应使用 HTTPS 并由后端启用权限校验。

## 页面与功能

- **登录**：角色模拟登录、密码显示切换、非空校验、错误反馈；真实模式支持 JWT 认证与刷新。
- **概览/导图**：公司重要事项、公司重要任务、个人重点工作、日志信息流四宫格，以及今日提交速览。
- **日志**：按权限查看/搜索/过滤、新建每天一条、保存草稿、正式提交、查看历史。服务端/Mock 约束提交后不可编辑、不可补交；Mock 在打开数据时会将 22:00 后当日草稿自动提交。
- **点评**：直属上级发起、日志作者回复；其他身份不可查看点评对话。
- **统计**：提交率、已提交与未提交人员、7/30 天趋势。
- **任务**：收到的任务及自建任务；直属领导任务派发、逐接收人检查，完成后邀约检查。
- **日历**：月/周/日视图；日志标红、派发任务标绿，有任务时优先绿标。演示任务暂以已知时间字段展示。
- **数据地图**：本人收到的任务与自建任务只读聚合；公司展示内容不混入。
- **个人中心**：账号身份和退出登录。

## 注意事项 / 与后端协作

1. **Mock 数据不是真实权限验证**。真实的角色范围、直属上下级和访问对象级校验只能由 Spring Boot 后端强制落实。
2. 此包实现了交互型 MVP。部分高级需求（公司内容原板块内双击编辑、完整任务派发内容后续编辑、按日周月的所有统计项、任务检查历史可视化等）需要团队进一步联调/细化；不得用演示截图宣称它们已完成。
3. 后端接口文档是团队契约，但尚未全部落地。切换真实模式后未完成的接口会提示加载失败而不会偷偷显示模拟成功。
4. 切换模式前先退出账号；如遇演示登录状态残留，可清除模拟器中应用的存储数据。
5. **不要把真正账号密码硬编码进 Mock 或提交进 Git**。Mock 密码仅用于本机演示。
6. 本包没有预编译 APK：你本地已有可编译的平台工程，执行 `flutter run` 即可构建。

## 代码结构

- `lib/core`：模型、状态与主题
- `lib/data`：Mock/REST 仓储实现
- `lib/screens`：登录、首页、日志、点评详情、任务、派发、日历、数据地图、统计和个人中心
- `lib/widgets`：通用 UI 组件
- `test`：登录页基本 Widget 测试

推荐先运行 Mock 模式验证界面，再与团队后端确认部署地址与测试账号，最后联调 API。
