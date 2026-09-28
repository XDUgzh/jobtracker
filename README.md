# JobTracker · 求职有序

完全本地的中文 Windows 求职管理桌面应用，使用 Flutter + SQLite。无需账号、服务器、Supabase 或订阅。

## 直接使用发布版

打开同级的 `JobTracker-Windows-x64` 文件夹，双击 `jobtracker.exe`。如果收到 ZIP，先完整解压。

**分发时必须保留整个文件夹**，包括 DLL 和 `data/`；EXE 不能单独运行。发布包面向 Windows 10/11 x64，附带 Visual C++ 运行库。只使用发布版不需要安装 Flutter 或 Visual Studio。

## 已实现

- 总览：累计投递、当前笔试、面试、Offer、已结束统计；待跟进提醒和最近进展。
- 求职记录：新增、编辑、确认删除，关键词搜索、阶段/状态筛选、三种排序。
- 字段：公司、岗位、投递日期、当前阶段、记录状态、来源、岗位链接、备注、关联简历。
- 详情：投递信息、关联简历和倒序时间轴；手动录入招聘进展或跟进备注。
- 简历库：导入 PDF / DOC / DOCX，保存名称、版本、原路径、本机副本；可修改元数据、打开文件、复制路径及删除简历记录。
- 无响应提醒：默认 14 天，支持 7/14/21/30/60 天，不会自动标记拒绝。
- SQLite 持久化、事务、外键、版本号；原生中文日期选择器、文件选择器及系统文件打开。

## 统计与时间轴规则

“已投递”是累计记录数，不含已经删除的记录。“笔试 / 面试 / Offer”统计当前处于该阶段且状态为“进行中”的记录。“已结束”包括明确拒绝、主动放弃、已入职。

当前阶段独立于记录状态。创建记录自动生成初始事件；编辑阶段或状态自动追加今天的事件，修改其他字段不重置等待时间。新增事件关闭“收到新的招聘进展”时，仅保存跟进备注；开启时，即使阶段未变化，也代表收到真实进展，可以重置等待时间。

补录事件按发生日期排序，同日以最后录入的进展为准。旧事件不会覆盖较新的进展。事件不得早于投递日或晚于今天，投递日期也不能改到最早事件之后。

等待天数按本地日历日期计算；达到阈值的进行中记录显示“长期无响应”，Offer 与已结束记录不显示提醒。提醒是派生信息，不修改记录阶段或状态。窗口前台恢复及每分钟刷新提醒。

## 数据位置和备份

默认：`%LOCALAPPDATA%\JobTracker\data`

- `jobtracker.sqlite3`：求职记录、事件、简历元数据及设置。
- `resumes/`：简历副本；数据库使用相对路径，可随完整备份迁移。
- `jobtracker.sqlite3-wal / -shm`：SQLite 工作文件，运行时可能存在。

在“偏好设置”可以打开实际数据目录。**备份/恢复前先关闭应用**，复制或替换完整数据目录；恢复前另存当前数据以防覆盖。更新 EXE 不会清除用户数据。删除简历记录解除关联但保留文件副本，原始文件始终不被修改。

可用 `JOBTRACKER_DATA_DIR` 环境变量指定另一数据目录，适合隔离演示或测试。

```powershell
$env:JOBTRACKER_DATA_DIR = 'D:\MyJobTrackerData'
.\jobtracker.exe
```

## 开发环境

本机已配置并验证：Flutter stable 3.47.5 / Dart 3.13.4，Visual Studio Community 2022 17.14.16、C++ 桌面开发组件、Windows SDK 10.0.26100.0。

本机 Flutter：`%LOCALAPPDATA%\JobTrackerDev\flutter`。已加入用户 PATH，**新开的终端**可以直接执行 `flutter`。依赖缓存：`C:\Users\pc\Documents\Codex\tools\pub-cache`，已设置用户级 `PUB_CACHE`。

在新电脑上需要安装 Flutter stable、Git、Visual Studio 的“使用 C++ 的桌面开发”（包括 MSVC、Windows SDK 和 CMake）。推荐启用 Windows 开发者模式。项目脚本也支持无管理员权限的目录连接方案，不会修改系统开发者模式。

## 运行、测试、构建

在本仓库根目录执行：

```powershell
# 安装依赖并运行 Windows 调试版
powershell -ExecutionPolicy Bypass -File .\scripts\run.ps1

# 静态检查和单元/界面测试（首次执行可先运行 prepare.ps1）
flutter analyze
flutter test

# 在真实 Windows 窗口中执行端到端测试
flutter test integration_test\app_test.dart -d windows

# 构建并整理发布目录，默认输出到 dist/JobTracker-Windows-x64
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

原生构建命令为 `flutter build windows --release`，产物位于 `build/windows/x64/runner/Release/`。推荐使用脚本，它会同时收集 Visual C++ 运行库和中文使用说明。首次编译需要网络下载开发依赖；完成后的应用离线可用。

项目只生成 `windows/` 平台。环境诊断中的 Android 工具链缺失不影响本项目，无需安装 Android Studio。

## 仓库结构

```text
lib/
  main.dart          启动与数据目录
  app.dart           工作台、简历库、设置与操作协调
  data/              领域模型、SQLite、简历持久化
  ui/                总览、列表、详情、表单、样式组件
windows/             Windows 原生宿主及图标
scripts/             环境准备、运行、Release 打包脚本
test/                数据规则、持久化、中文界面工作流及小窗口测试
integration_test/    真实 Windows 窗口端到端测试
docs/                设计说明、中文使用说明、验证记录
```

仓库仅在本地初始化，未设置远程地址或上传 GitHub。`.gitignore` 排除构建产物、依赖缓存、个人数据库及分发压缩包；`pubspec.lock` 保留以固定依赖版本。

## MVP 边界

当前进度由用户手动维护，不接入邮箱、招聘网站或云端同步。提醒显示在应用内，未运行时不会发送系统通知。简历使用系统默认 PDF/Office 软件打开。数据库未加密，依赖本机账户的访问权限。当前发布包为便携目录，未提供安装向导、代码签名或自动更新。
