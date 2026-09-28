# 验证记录

日期：2026-09-28；本机 Windows 11 x64。

## 已通过

- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：10 项全部通过。
  - 长期无响应不自动拒绝；阈值包含等于当天。
  - 关闭并重开数据库后记录和设置仍存在。
  - 补录历史事件、同日事件排序及最新阶段推导。
  - 跟进备注和普通字段编辑不重置等待天数。
  - 简历导入副本、原文件删除后的副本读取、版本修改和解除关联。
  - 完整数据目录迁移后简历引用仍有效。
  - 无效日期回滚、结束状态不提醒、删除级联清理事件。
  - 中文界面新增、编辑、追加事件和确认删除。
  - 960×610 内容视口下主要页面无布局溢出。
- `flutter test integration_test/app_test.dart -d windows --no-pub`：在真实 Windows 窗口中运行 2 项工作流，全部通过。
- `flutter build windows --release --no-pub`：Windows x64 Release 构建成功。
- 从独立发布目录启动 Release EXE：窗口响应正常，中文总览实际渲染正常，SQLite 文件成功创建。
- 检查运行进程加载的 `sqlite3.dll`：来自发布目录，不依赖开发目录。
- 发布目录包含 Flutter/SQLite/文件选择器/链接启动器 DLL、Visual C++ 运行库及应用资源。

## 本机环境处理

Flutter stable 3.47.5 从官方仓库安装；复用已有 Visual Studio 2022 与 Windows SDK。依赖缓存设置到 Documents/Codex/tools/pub-cache，解决原缓存位置的跨盘重命名错误。由于当前进程不能修改系统开发者模式，插件使用目录连接；未修改系统开发者模式。脚本包含相同的回退处理。

## 验证边界

自动测试使用临时目录；发布版冒烟测试使用独立工作目录，正式启动保留空白用户库。尚未在第二台干净 Windows 电脑验证，也未进行安装包签名。系统文件打开依赖用户安装对应 PDF/Office 软件；原生文件选择器由 Flutter 官方插件提供，自动工作流没有操纵系统文件选择对话框。
