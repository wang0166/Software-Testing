潘多拉 Pandora 移动端 V1.3.0 商务界面改版

一、在已有 UI 开发分支备份现有修改，不要直接覆盖 main。
二、解压本 ZIP：移动端覆盖包按“mobile/”相对目录复制到你项目根目录的 mobile 文件夹，选择覆盖同名文件。
三、建议先 git diff 查看是否覆盖了你之后自行修改的内容。代码基于此前交付的 V1.2.0 + 任务地图补丁 + setState 修复补丁，而非当前 GitHub 远程最新提交。
四、flutter pub get; flutter analyze; flutter test; flutter run -d <你的设备ID> --dart-define=PANDORA_DEMO=true。
五、真实后端需按 README_V1.3_商务重构与后端联调.md 同步支持新增接口，否则相应功能显示接口错误，不能视为真实后端完成审批。
六、如使用 USB 真机，先 adb -s <设备ID> reverse tcp:8080 tcp:8080，再以 PANDORA_DEMO=false 和正确的 API_BASE_URL 运行。

本环境无 Flutter SDK，已做静态结构与依赖文件检查，未能进行真实编译。
