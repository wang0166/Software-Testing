# Pandora 移动端 v1.14 — 中国大陆动态节假日日历（仅需覆盖/新增文件）

本补丁以 **v1.12 全量工程 + v1.13 修复包** 为基础。解压到 Windows Flutter 项目根目录，保持 `lib/`、`test/`、`docs/` 目录结构即可。原来的任务清单、Todo、发布任务流程和权限逻辑不会被本补丁替换。

## 已做的移动端改动

1. **共用节假日服务**：首页个人月历与公司视图月/周/日历共享 `HolidayCalendarService`，但数据层分离。两者均不再自行推算 / 写死假期日期。
2. **节日展示**：法定或调休放假显示红色 `休`，调休补班显示橙色 `班`，节日名以小号红字标记。选中日期可阅读节假日和传统节日信息。
3. **月视图适配**：公司任务日历继续显示最多两项任务文字和 `+N`；首页的私人 Todo 在狭窄格子中按剩余高度显示，点击日期在下方查看完整 Todo，不恢复单元格内滚动条。
4. **真实接口预留**：`GET /api/calendar/holidays?year=YYYY`，复用原有 Bearer token 和 `{code,message,data}` 协议。用户从不直接调用第三方日历 API。
5. **缓存与错误处理**：按年在 `SharedPreferences` 缓存后端最近一次成功数据，默认 12 小时刷新；网络断开则显示已缓存数据并提示可能过期。无缓存时显示不可用，不输出假节日；未公布年份有单独状态。
6. **演示模式**：无硬编码假期表。演示模式不会凭空制造节假日数据。
7. **网络权限**：主 Android Manifest 补充 INTERNET 权限，正式发布请使用 HTTPS；本地调试的 HTTP 放行仍仅位于 debug Manifest。
8. **自动化测试代码**：新增解析、分离展示、缓存回退和 API 合约测试；**当前打包环境没有 Flutter SDK，未执行编译和测试**。

## 给后端同学的接口约定

见 `docs/节假日接口契约.md`。特别是 `days[].dayType`、`days[].festivals` 和 `dataStatus`，必须按契约实现；否则客户端会明确提示数据异常/暂不可用。

## Windows / PowerShell 运行步骤

原项目目录：`D:\Projects\Software-Testing\mobile`

**第一步：先覆盖本 ZIP 中 `lib/`、`test/` 和 `docs/` 的相对路径文件。**

```powershell
cd "D:\Projects\Software-Testing\mobile"
flutter pub get
flutter analyze
flutter test test/holiday_calendar_test.dart test/holiday_api_contract_test.dart
```

**第二步：确认后端实际端口可达。**（示例 `8080`，要改为你的真实端口）

```powershell
Test-NetConnection 127.0.0.1 -Port 8080
```

`TcpTestSucceeded` 必须为 `True` 才能从本机通过该端口访问后端；如为 `False`，先确认后端配置 / 监听端口 / Docker 端口映射。

**第三步：连接真实后端在已启动的 Android 模拟器上运行。**（替换 `8080` 为实际端口）

```powershell
flutter run -d emulator-5554 --dart-define=PANDORA_DEMO=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

> 后端未完成新接口时，旧业务功能仍可运行；节假日会明确显示“暂不可用”，而不是把假数据冒充真实数据。`flutter analyze` / `flutter test` 的真实结果需在本机 Flutter 环境验证。
