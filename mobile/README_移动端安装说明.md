# 潘多拉 Flutter 移动端 · 全功能源码覆盖包

这是一份为 **D:\Projects\Software-Testing\mobile** 已经运行成功的 Flutter Android 工程准备的**源码覆盖包**，不是整个后端仓库，也不含 `.gradle`、Flutter SDK、NDK 或完整 Android 平台脚手架。

**文件夹中的 `mobile/` 是要覆盖进去的代码，原来 `mobile/android` 下的 Gradle、SDK、签名、applicationId 等设置必须保留。**

## 最快安装：运行脚本（推荐）

1. 在 VS Code 中停止当前 `flutter run`：在运行终端按 `q` 或 `Ctrl+C`。退出 Android Studio 中正在编辑的项目亦可，模拟器可以保留。
2. 把本 ZIP 解压到任意**英文路径**，例如 `D:\Projects\PandoraPackage`。
3. 打开解压后的文件夹，在文件资源管理器地址栏输入 `powershell` 回车，或在该路径打开 PowerShell。
4. 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\安装到现有项目.ps1
```

脚本默认目标为 `D:\Projects\Software-Testing\mobile`。运行前会将现有 `lib/`、`test/`、`pubspec.yaml`、`analysis_options.yaml` 和相关 AndroidManifest 备份到用户目录 `C:\Users\22825\PandoraBackups\mobile-时间戳`，不会污染仓库或被 `flutter analyze` 扫描；然后替换 Dart 源码与测试，保留原 `android/` 下的 Gradle、签名、应用标识等配置。

如目标位置不同：

```powershell
powershell -ExecutionPolicy Bypass -File .\安装到现有项目.ps1 -Target "D:\你自己的目录\Software-Testing\mobile"
```

5. 返回 VS Code 项目目录执行：

```powershell
cd D:\Projects\Software-Testing\mobile
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554
```

第一次增加了 `http`、`shared_preferences`、`flutter_secure_storage`，可能需要下载依赖。运行时保持 Android 模拟器开启。如果 Gradle 再次卡在 Maven 下载，沿用你此前设置好的 SakuraCat 7897 代理和 Gradle `gradle.properties` 配置。

## 手动安装（不运行脚本也可以）

将压缩包的 `mobile/lib/`、`mobile/test/` 与 `mobile/pubspec.yaml` 覆盖到你现有的 `D:\Projects\Software-Testing\mobile`；**不要删除或整体替换已生成的 `mobile/android/` 目录**。若需要对接本机 HTTP 后端，再合并 `mobile/android/app/src/debug/AndroidManifest.xml` 中的 `usesCleartextTraffic=true` 配置，并为主 AndroidManifest 增加 INTERNET 权限（脚本会自动处理）。

## 已包含的功能

- 登录：账号/密码校验、加载态、错误提示；无自助注册；本地 Mock 演示账户与角色切换。
- 概览：首页欢迎卡、今日提交率、我的日志、公司十大重要事项、十大重要任务、个人任务与日志入口。
- 工作日志：按角色可见、列表、搜索/状态筛选、当日创建/编辑草稿、保存、确认提交、详情；每天一条、22:00（Asia/Shanghai）截止、提交后禁止编辑。
- 点评：直属上级发起，日志作者回复；Mock 按角色及组织关系检查对话可见范围。
- 任务：我的接收任务、自建任务、创建自建任务、进度维护；按角色提供直属下级派发、进度检查与检查邀约；遵循状态转换规则。
- 数据地图：只读汇总本人的收到任务与自建任务，不混入公司展示项。
- 统计：今日提交率、应提交/已提交/未提交、趋势（7/30 天切换）、未提交名单。
- 日历：月切换、日期标记、单日任务/日志计数。
- 我的：用户角色、组织归属、演示环境提示、退出账号。
- 演示数据保存在本设备 SharedPreferences 中；真实认证 Token 使用 flutter_secure_storage。

## 演示账号（默认启动就是演示模式）

统一密码：**demo123456**（仅本地 Mock 有效，真实后端没有此密码）。登录页可点角色芯片快速填入。

| 账号 | 身份 | 可操作范围 |
|------|------|------------|
| demo001 | 员工 | 个人日志与任务、回复直属上级点评 |
| demo002 | 员工 | 另一个员工的独立数据 |
| leader | 团队长 | 团队日志、对员工发起点评 |
| manager | 部门负责人 | 部门日志、对团队长发起点评 |
| founder | 创始人 | 全公司日志、对部门负责人点评 |
| admin | 管理员 | 全公司日志只读，无日志写入和任务操作 |

## 切换到团队后端

后端接口必须运行、账号必须真实存在，才能联调。你们接口文档是 `documents/后端接口文档.md`（统一 JSON `{code,message,data}`，路径 `/api`，业务时区 Asia/Shanghai）。

Android 模拟器访问 Windows 本机 `localhost:8080` 的地址通常是 **10.0.2.2**：

```powershell
flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

**生产部署必须使用 HTTPS，不要在正式版本保留 HTTP 明文通信。** 不应使用 Mock 凭据登录真实服务，真实认证数据以团队后端为准。

已为登录、刷新令牌、登出、获取当前用户、日志、点评、统计、接收/自建任务、公司展示内容、数据地图与日历配置请求方法，任务派发、检查在界面中已有基础操作；与后端完整联调、全部越权/并发验收仍需团队完成。接口中不一致或尚未上线的字段/能力，需要与你们后端同学对齐后再验收。

**重要：Mock 展示成功不等于后端联调成功。** 当前交付没有在你的 Windows Flutter SDK / Android 模拟器上进行实际编译，第一次覆盖后请以 `flutter analyze`、`flutter test` 和 `flutter run` 为准。如有具体编译报错，可把完整报错发来，按你的 Flutter 3.47.7 做兼容修复。

## 功能源码目录

```text
mobile/
  pubspec.yaml
  lib/
    main.dart
    core/{app_state.dart,models.dart,theme.dart}
    data/{repository.dart,mock_repository.dart,api_repository.dart}
    widgets/ui.dart
    screens/{login_page.dart,shell_page.dart,home_page.dart,logs_page.dart,
             log_detail_page.dart,tasks_page.dart,task_map_page.dart,
             stats_page.dart,calendar_page.dart,profile_page.dart}
  test/{widget_test.dart,mock_repository_test.dart}
  android/app/src/debug/AndroidManifest.xml  # 仅供源工程合并
```

## 团队 Git 提交（先确保 feature/flutter-mobile 分支正确）

```powershell
cd D:\Projects\Software-Testing
git status
git add mobile/lib mobile/test mobile/pubspec.yaml mobile/android/app/src
# 查看差异再提交，避免把 build 或密钥文件添加到仓库
git diff --cached --stat
git commit -m "feat(mobile): complete Pandora Flutter MVP UI and mock flows"
```
