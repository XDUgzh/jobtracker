import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/database.dart';
import 'data/models.dart';
import 'data/transfer.dart';
import 'ui/forms.dart';
import 'ui/widgets.dart';
import 'ui/dashboard.dart';
import 'ui/records.dart';
import 'ui/detail.dart';

class JobTracker extends StatelessWidget {
  const JobTracker({super.key, required this.database});
  final JobDatabase database;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'JobTracker · 求职有序',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Workspace(database: database),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.database});
  final JobDatabase database;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  int page = 0;
  int? selected;
  String quickFilter = '全部';
  late List<ApplicationRecord> records;
  late List<ResumeRecord> resumes;
  late int threshold;
  late final Timer clock;
  JobDatabase get db => widget.database;
  @override
  void initState() {
    super.initState();
    refresh();
    WidgetsBinding.instance.addObserver(this);
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  void refresh() {
    records = db.applications();
    resumes = db.resumes();
    threshold = db.threshold;
  }

  void reload() {
    if (mounted) setState(refresh);
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void star(ApplicationRecord record) {
    try {
      db.toggleStar(record.id!);
      reload();
    } catch (e) {
      message('收藏失败：$e');
    }
  }

  void completeFollowUp(ApplicationRecord record) {
    try {
      db.completeFollowUp(record.id!);
      reload();
      message('跟进计划已完成，招聘进度保持不变');
    } catch (e) {
      message('保存失败：$e');
    }
  }

  Future<void> transfer(String action) async {
    try {
      String? target;
      if (action == 'restore') {
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'JobTracker 备份',
              extensions: ['jobtracker'],
            ),
          ],
        );
        if (file == null || !mounted) return;
        target = file.path;
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('用备份恢复全部数据？'),
            content: const Text(
              '恢复会替换当前全部求职记录、时间轴、简历与设置。系统会先验证备份，并自动保存恢复前的数据到本机 backups 文件夹。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('恢复备份'),
              ),
            ],
          ),
        );
        if (approved != true) return;
      } else {
        final extension = action == 'csv' ? 'csv' : 'jobtracker';
        final location = await getSaveLocation(
          suggestedName: 'JobTracker-${dateText(DateTime.now())}.$extension',
          acceptedTypeGroups: [
            XTypeGroup(
              label: action == 'csv' ? 'Excel CSV' : 'JobTracker 备份',
              extensions: [extension],
            ),
          ],
        );
        if (location == null || !mounted) return;
        target = location.path;
      }
      if (!mounted) return;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 20),
                  Text('正在处理本地数据…'),
                ],
              ),
            ),
          ),
        ),
      );
      String result;
      try {
        if (action == 'csv') {
          await File(
            target,
          ).writeAsBytes(utf8.encode(DataTransfer.csv(db)), flush: true);
          result = 'CSV 已导出，可用 Excel 打开';
        } else if (action == 'backup') {
          await DataTransfer.backup(db, target);
          result = '备份已保存，包含全部记录和简历副本';
        } else {
          final safetyCopy = await DataTransfer.restore(db, target);
          selected = null;
          result = '恢复完成。恢复前备份：$safetyCopy';
        }
      } finally {
        if (mounted) Navigator.of(context).pop();
      }
      reload();
      message(result);
    } catch (e) {
      message('操作未完成：$e');
    }
  }

  Future<void> edit([ApplicationRecord? r]) async {
    final id = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApplicationDialog(database: db, record: r),
    );
    if (id != null && mounted) {
      setState(() {
        refresh();
        selected = id;
        page = 1;
      });
      message('求职记录已保存');
    }
  }

  Future<void> event(ApplicationRecord r) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EventDialog(database: db, record: r),
    );
    if (result == true) {
      reload();
      message('事件已加入时间轴');
    }
  }

  Future<void> remove(ApplicationRecord r) async {
    if (!await confirm(
      context,
      '删除这条求职记录？',
      '“${r.company} · ${r.position}”及其全部时间轴事件将被删除，无法撤销。关联的简历会保留。',
    )) {
      return;
    }
    try {
      db.deleteApplication(r.id!);
      if (mounted) {
        setState(() {
          selected = null;
          refresh();
        });
      }
      message('记录已删除');
    } catch (e) {
      message('删除失败：$e');
    }
  }

  Future<void> importResume() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: '简历文件', extensions: ['pdf', 'doc', 'docx']),
        ],
      );
      if (file == null || !mounted) return;
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ResumeDialog(database: db, path: file.path),
      );
      if (result == true) {
        reload();
        message('简历已保存在本机');
      }
    } catch (e) {
      message('导入失败：$e');
    }
  }

  Future<void> openLocal(String path, {bool folder = false}) async {
    try {
      if (!(folder
          ? await Directory(path).exists()
          : await File(path).exists())) {
        message('文件或目录不存在，请检查保存路径。');
        return;
      }
      if (!await launchUrl(Uri.file(path, windows: true))) {
        message('无法打开，请检查是否安装了对应软件。');
      }
    } catch (e) {
      message('无法打开：$e');
    }
  }

  Future<void> openLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      message('岗位链接无效');
      return;
    }
    try {
      if (!await launchUrl(uri)) message('无法打开浏览器');
    } catch (e) {
      message('无法打开链接：$e');
    }
  }

  void navigate(int index) => setState(() {
    page = index;
    selected = null;
    quickFilter = '全部';
  });
  void showRecord(ApplicationRecord r) => setState(() {
    selected = r.id;
    page = 1;
  });
  @override
  Widget build(BuildContext context) {
    final current = records.where((r) => r.id == selected).firstOrNull;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 208,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 20, 36),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.all(Radius.circular(11)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(
                            Icons.work_outline_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JobTracker',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '求职有序 · 向前一步',
                                style: TextStyle(fontSize: 10, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 28, bottom: 12),
                  child: Text(
                    '我的工作台',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                nav(0, Icons.space_dashboard_outlined, '求职总览'),
                nav(1, Icons.view_list_outlined, '求职记录'),
                nav(2, Icons.description_outlined, '简历库'),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: canvas,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 15,
                              color: Color(0xFF14886C),
                            ),
                            SizedBox(width: 7),
                            Text(
                              '安心保存在本机',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '无需登录，离线也能记录\n每一步进展。',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                nav(3, Icons.tune_rounded, '偏好设置'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 12, 20, 22),
                  child: Text(
                    'WINDOWS  /  v1.1.0',
                    style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 66,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: line)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '我的工作台  /  ${['求职总览', '求职记录', '简历库', '偏好设置'][page]}',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: muted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateText(DateTime.now()),
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(width: 24),
                      const StatusBadge('本地模式', color: Color(0xFF14886C)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
                    child: switch (page) {
                      0 => Dashboard(
                        records: records,
                        threshold: threshold,
                        onAdd: () => edit(),
                        onOpen: showRecord,
                        onComplete: completeFollowUp,
                        onFilter: (filter) => setState(() {
                          page = 1;
                          selected = null;
                          quickFilter = filter;
                        }),
                      ),
                      1 =>
                        current == null
                            ? RecordsPage(
                                key: ValueKey(quickFilter),
                                records: records,
                                threshold: threshold,
                                initialFilter: quickFilter,
                                onAdd: () => edit(),
                                onOpen: showRecord,
                                onEdit: edit,
                                onDelete: remove,
                                onExport: () => transfer('csv'),
                                onStar: star,
                              )
                            : DetailPage(
                                record: current,
                                events: db.events(current.id!),
                                resume: resumes
                                    .where((r) => r.id == current.resumeId)
                                    .firstOrNull,
                                threshold: threshold,
                                onBack: () => setState(() => selected = null),
                                onEdit: () => edit(current),
                                onDelete: () => remove(current),
                                onEvent: () => event(current),
                                onOpenFile: openLocal,
                                onOpenLink: openLink,
                                onStar: () => star(current),
                                onComplete: () => completeFollowUp(current),
                              ),
                      2 => resumePage(),
                      _ => settingsPage(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget nav(int index, IconData icon, String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Material(
      color: page == index ? accent.withValues(alpha: .08) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(icon, size: 21, color: page == index ? accent : muted),
        minLeadingWidth: 22,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: page == index ? accent : muted,
            fontWeight: page == index ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        onTap: () => navigate(index),
      ),
    ),
  );
  Widget resumePage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '简历库',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('每个版本都有归处，每次投递都有记录。', style: TextStyle(color: muted)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: importResume,
            icon: const Icon(Icons.file_upload_outlined, size: 19),
            label: const Text('导入简历'),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Expanded(
        child: resumes.isEmpty
            ? Surface(
                child: EmptyState(
                  title: '把第一份简历放在这里',
                  description: '支持 PDF、DOC、DOCX，导入后可在求职记录中关联。',
                  icon: Icons.description_outlined,
                  action: OutlinedButton(
                    onPressed: importResume,
                    child: const Text('选择本地文件'),
                  ),
                ),
              )
            : ListView.separated(
                itemCount: resumes.length,
                separatorBuilder: (_, index) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final r = resumes[i];
                  final count = records.where((a) => a.resumeId == r.id).length;
                  return Surface(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: accent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    r.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  StatusBadge(r.version),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '导入于 ${dateText(r.importedAt)}  ·  关联 $count 条求职记录',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SelectableText(
                                r.path,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => openLocal(r.path),
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      size: 16,
                                    ),
                                    label: const Text('打开文件'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: r.path),
                                      );
                                      message('路径已复制');
                                    },
                                    child: const Text('复制路径'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '简历操作',
                          onSelected: (action) async {
                            if (action == 'edit') {
                              if (await showDialog<bool>(
                                    context: context,
                                    builder: (_) => ResumeDialog(
                                      database: db,
                                      path: r.path,
                                      resume: r,
                                    ),
                                  ) ==
                                  true) {
                                reload();
                              }
                            } else if (await confirm(
                              context,
                              '删除简历记录？',
                              '将解除 $count 条求职记录的简历关联。本地文件副本和原文件都会保留。',
                            )) {
                              try {
                                db.deleteResume(r.id);
                                reload();
                              } catch (e) {
                                message('删除失败：$e');
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('编辑名称和版本'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除简历记录'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );
  Widget settingsPage() => ListView(
    children: [
      const Text(
        '偏好设置',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text('让记录方式适合你的求职节奏。', style: TextStyle(color: muted)),
      const SizedBox(height: 28),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '长期无响应提醒',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              '从最后一次实际招聘进展开始计算。只提示进行中的记录，Offer 和已结束记录不提醒。\n提醒不会改变当前阶段，也不会将记录标记为拒绝。',
              style: TextStyle(color: muted, height: 1.8),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<int>(
                key: ValueKey('threshold-$threshold'),
                initialValue: threshold,
                decoration: const InputDecoration(labelText: '多久没有进展时提醒'),
                items: ({7, 14, 21, 30, 60, threshold}.toList()..sort())
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d 天')))
                    .toList(),
                onChanged: (days) {
                  if (days != null) {
                    try {
                      db.setThreshold(days);
                      reload();
                      message('提醒规则已保存');
                    } catch (e) {
                      message('保存失败：$e');
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本地数据与备份',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              '一键备份包含全部记录、时间轴和简历副本。恢复会替换当前数据，并自动保留恢复前备份。CSV 可用于 Excel 分析，不能作为完整备份。',
              style: TextStyle(color: muted, height: 1.8),
            ),
            const SizedBox(height: 16),
            SelectableText(db.directory),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => transfer('backup'),
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('备份全部数据'),
                ),
                OutlinedButton.icon(
                  onPressed: () => transfer('restore'),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('从备份恢复'),
                ),
                OutlinedButton.icon(
                  onPressed: () => transfer('csv'),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('导出 CSV'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => openLocal(db.directory, folder: true),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('打开数据文件夹'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '关于 JobTracker',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text(
              '版本 1.1.0 · Windows 桌面版\n无需账号、服务器或订阅。招聘状态由你手动记录。',
              style: TextStyle(color: muted, height: 1.8),
            ),
          ],
        ),
      ),
    ],
  );
}
