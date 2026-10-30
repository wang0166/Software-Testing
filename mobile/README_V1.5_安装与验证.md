# 潘多拉 V1.5.0 任务日历与创建入口：安装说明

## 应用补丁

请先提交/备份自己的当前代码，在新的 Git 分支中解压「仅覆盖新增文件」ZIP，将其中 `mobile/` 内的文件合并到本地仓库的 `mobile/`，覆盖同名文件。不要复制到后端同学的 web-admin Worktree。

相对 V1.4.0 主要覆盖：

- `lib/screens/calendar_page.dart`：只取任务，移除日志标记与计数，保留任务折叠/甘特图。
- `lib/screens/view_page.dart`：统一「＋ 创建任务」悬浮入口。
- `lib/screens/tasks_page.dart`：删除第二个重复悬浮按钮，保留收到的任务台账。
- `lib/screens/dispatch_page.dart`：提交成功后返回明确的成功结果，取消时不会让日历重置。
- `lib/screens/subordinates_page.dart`, `lib/screens/stats_page.dart`：底部留白避免遮挡。
- `test/v15_calendar_task_only_test.dart`：新增关键回归测试。
- `pubspec.yaml`：开发版本变为 1.5.0+6。

## 运行（PowerShell）

```powershell
cd D:\Projects\Software-Testing\mobile
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=true
```

若已运行 Flutter，纯 Dart 改动大写 `R` 一般可热重启；由于 `pubspec.yaml` 版本号也变了，**首次应用本包建议终止旧运行并重新 `flutter run`**，无需 `flutter clean`。

## 关键验收点

1. 视图默认进入日历。月、周、日、甘特图都不展示「有日志」或日志数量，仅展示任务的状态、日期、数量。
2. 同日期超过 3 个任务时折叠，可点击文本「查看更多任务」进入完整甘特图。
3. 在视图内切换「日历 / 任务清单 / 下属动态 / 统计看板」，右下角都能看到唯一的「＋ 创建任务」。
4. 点击后进入原任务派发申请表单，正常选择全公司成员、日期到分钟、任务类型；提交后须由服务端审核，不会前端假成功。
5. 导图首页和日志主导航保留原来的功能及样式。

## 真实后端联调

```powershell
# 真机 USB 时按需执行；模拟器直接可用 10.0.2.2
& "D:\Android\Sdk\platform-tools\adb.exe" -s 10AE5N1726001MK reverse tcp:8080 tcp:8080
flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

后端端口及 `/api` 路径以实际配置为准。此版本未改动后端数据接口。
