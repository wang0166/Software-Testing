# 潘多拉 V1.5.1 — 日历任务区可滚动

## 甲方要求

1. 日历只展示任务，不显示日志状态。
2. 同一天任务不超过三条：直接完整展示。
3. 同一天任务多于三条：初始视口最多显示三条，可在任务区内部**上下滑动**查看所有任务。
4. 同时保留带下划线的「还有 N 项任务 · 查看完整甘特图」文字链接，点击直接进入独立完整甘特图。

## 实现说明

- 月/周视图：现有跨日期任务横条按一周分轨展示。之前超过第三轨的任务会被截断；现在所有轨道都会参与布局，周内横条区域固定显示最多三轨高度，内部可纵向滚动，并保留原来的跳转文字。
- 日视图：超过三条时用固定三项高度的 `ListView.builder` 展示全部任务，列表自身可滚动，同时保留跳转文字。
- 不改数据源，仅使用有权查看的接收任务，不使用混合日志状态的后端日历接口。
- 不改任务创建、审批、人员范围及其它页面。

## 覆盖文件

- `mobile/lib/core/gantt_utils.dart` — 任务横条完整分轨工具
- `mobile/lib/screens/calendar_page.dart` — 月、周、日任务区域内部滚动
- `mobile/test/v151_calendar_scroll_test.dart` — 轨道分配及滚动组件测试
- `mobile/pubspec.yaml` — 版本号更新到 `1.5.1+7`
- `mobile/CHANGELOG_V1.5.md` — 变更记录
- `mobile/README_V1.5.1_日历任务可滚动.md`

## 本地验证

```powershell
cd D:\Projects\Software-Testing\mobile
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=true
```

更新了 `pubspec.yaml`，建议停止运行中的 Flutter 进程后重新运行，而不是只按大写 R。

**验证限制：** 代码已经按原 V1.5.0 源码更新并做文本检查，当前环境没有 Flutter SDK，尚未执行 Flutter 真机构建和自动化测试，以你的本地结果为准。
