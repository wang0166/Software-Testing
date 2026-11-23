Pandora v1.16｜跨日期拖动 + 全应用软萌风格（仅覆盖文件）
=====================================================

针对甲方补充要求：
1. “事项可拖动”指从当天拖到日历的其他日期，不是单纯改变列表中的排序。
   - 长按日历上的事项色条，或长按下方当日事项卡片，拖到其他日期的方格松手；
   - 方格悬停时变成粉色；保存成功后会自动选中目标日期；
   - 相邻月份日期也可作为直接拖放目标；
   - 拖动时在月份左右箭头上悬停约 0.75 秒，会切换日历月份，然后继续拖到目标日期；
   - 也可以点击事项进入编辑页，通过“日期”选择器直接改日期（备用方式）；
   - 日期变化后保留事项 ID、标题、完成状态、颜色、起止时间和其他事项数据。
   - 原有“右侧手柄调整当天顺序”的功能仍保留，和跨日期拖动是两种不同操作。
2. 整个 App 全局统一“奶油白 + 莓果粉 + 薄荷绿 + 云朵紫”配色与圆润卡片/按钮。
   - 登录、底部导航、首页、公司工作区、日志、任务、统计、AI 地图、人员详情、个人中心、设置等统一设计；
   - 共用业务面板、表单、卡片、标题均采用软萌样式和星星点缀；
   - 业务字段、后端接口、组织授权、任务审核逻辑不作变更。
3. 每日事项仍仅保存在手机本地，按账号隔离，不是公司任务，原存储 Key 不变。

如何覆盖：
- 先备份 mobile 工程或提交一次 Git，然后将 ZIP 解压覆盖到 mobile 项目根目录。
- 文件从 lib/ 和 test/ 目录相对定位，不能把整个 ZIP 解压到 lib/ 中。
- 不需修改 pubspec.yaml，不增加依赖，不动后端。

在 Windows PowerShell 执行：
  cd "D:\Projects\Software-Testing\mobile"
  Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\Pandora_v1.16_跨日期拖动_全应用软萌风格_仅覆盖.zip" -DestinationPath . -Force
  flutter analyze
  flutter test test/daily_todos_cute_upgrade_test.dart
  flutter test test/v116_cute_cross_date_test.dart
  flutter test test/v111_home_todos_test.dart
  flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=true

真机/模拟器手工验证：
- 在同月的两天之间拖动事项（新日期显示、旧日期消失）。
- 从当月拖到下一月显示出来的日期格，或拖动时悬停下月箭头后继续拖放。
- 拖动后颜色、时间、完成状态保留；重启后仍在新日期。
- 登录、公司日历、任务表格、日志、AI 地图、个人中心等页面均为同一软萌主题。

注意：目前交付的是源码覆盖补丁，不是 APK。运行环境不包含 Flutter SDK，
无法直接执行 Flutter analyze/test/build；本地静态检查不等同于编译验证。
如果模拟器仍全黑，先处理模拟器显示问题；UI 换肤不保证能修复图形黑屏。
