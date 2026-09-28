import 'package:flutter/material.dart';
import '../data/database.dart';
import '../data/models.dart';
import 'widgets.dart';

class ApplicationDialog extends StatefulWidget {
  const ApplicationDialog({super.key, required this.database, this.record});
  final JobDatabase database;
  final ApplicationRecord? record;
  @override
  State<ApplicationDialog> createState() => _ApplicationDialogState();
}

class _ApplicationDialogState extends State<ApplicationDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController company,
      position,
      source,
      url,
      notes,
      nextAction;
  late DateTime date;
  late String stage, status;
  int? resumeId;
  DateTime? followUpAt;
  bool starred = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    company = TextEditingController(text: r?.company);
    position = TextEditingController(text: r?.position);
    source = TextEditingController(text: r?.source);
    url = TextEditingController(text: r?.url);
    notes = TextEditingController(text: r?.notes);
    date = r?.appliedAt ?? calendarDate(DateTime.now());
    stage = r?.stage ?? stages.first;
    status = r?.status ?? statuses.first;
    resumeId = r?.resumeId;
    nextAction = TextEditingController(text: r?.nextAction);
    followUpAt = r?.followUpAt;
    starred = r?.starred ?? false;
  }

  @override
  void dispose() {
    for (final c in [company, position, source, url, notes, nextAction]) {
      c.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    try {
      final id = widget.database.saveApplication(
        ApplicationRecord(
          id: widget.record?.id,
          company: company.text,
          position: position.text,
          appliedAt: date,
          stage: stage,
          status: status,
          source: source.text,
          url: url.text,
          notes: notes.text,
          resumeId: resumeId,
          followUpAt: followUpAt,
          nextAction: nextAction.text,
          starred: starred,
          lastProgress: widget.record?.lastProgress ?? date,
        ),
      );
      Navigator.pop(context, id);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Widget row(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 16),
      Expanded(child: b),
    ],
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.record == null ? '新增求职记录' : '编辑求职记录'),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              row(
                TextFormField(
                  key: const Key('companyField'),
                  controller: company,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '公司 *',
                    hintText: '例如：心仪的公司',
                  ),
                  maxLength: 100,
                  validator: requiredText,
                ),
                TextFormField(
                  key: const Key('positionField'),
                  controller: position,
                  decoration: const InputDecoration(
                    labelText: '岗位 *',
                    hintText: '例如：产品经理',
                  ),
                  maxLength: 100,
                  validator: requiredText,
                ),
              ),
              const SizedBox(height: 16),
              row(
                DateField(
                  value: date,
                  onChanged: (v) => setState(() => date = v),
                  label: '投递日期',
                ),
                TextFormField(
                  controller: source,
                  decoration: const InputDecoration(
                    labelText: '来源',
                    hintText: '官网 / 内推 / 招聘平台',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              row(
                DropdownButtonFormField<String>(
                  initialValue: stage,
                  decoration: const InputDecoration(labelText: '当前阶段'),
                  items: stages
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => stage = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: '记录状态'),
                  items: statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => status = v!),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                initialValue: resumeId ?? -1,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '关联简历'),
                items: [
                  const DropdownMenuItem(value: -1, child: Text('暂不关联')),
                  ...widget.database.resumes().map(
                    (r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${r.name} · ${r.version}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => resumeId = v == -1 ? null : v),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: '岗位链接',
                  hintText: 'https://',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final u = Uri.tryParse(v.trim());
                  return u != null &&
                          ['http', 'https'].contains(u.scheme) &&
                          u.host.isNotEmpty
                      ? null
                      : '请输入完整的 http 或 https 链接';
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: notes,
                minLines: 3,
                maxLines: 6,
                maxLength: 10000,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '岗位亮点、联系人、面试准备……',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '修改阶段或状态会自动写入时间轴；仅修改备注不会重置等待天数。',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('收藏为重点机会'),
                value: starred,
                onChanged: (value) => setState(() => starred = value),
              ),
              SwitchListTile(
                key: const Key('followUpSwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('安排下次跟进'),
                subtitle: const Text('到期后在首页提醒，不改变招聘进度'),
                value: followUpAt != null,
                onChanged: (value) => setState(
                  () =>
                      followUpAt = value ? calendarDate(DateTime.now()) : null,
                ),
              ),
              if (followUpAt != null) ...[
                const SizedBox(height: 12),
                DateField(
                  value: followUpAt!,
                  lastDate: DateTime(DateTime.now().year + 10),
                  onChanged: (value) => setState(() => followUpAt = value),
                  label: '下次跟进日期',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('nextActionField'),
                  controller: nextAction,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: '下一步要做什么',
                    hintText: '例如：询问结果 / 准备二面 / 确认 Offer',
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('saveApplication'),
        onPressed: save,
        child: const Text('保存记录'),
      ),
    ],
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? '此项不能为空' : null;

class EventDialog extends StatefulWidget {
  const EventDialog({super.key, required this.database, required this.record});
  final JobDatabase database;
  final ApplicationRecord record;
  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  late String stage, status;
  DateTime date = calendarDate(DateTime.now());
  final note = TextEditingController();
  bool progress = true;
  String? error;
  @override
  void initState() {
    super.initState();
    stage = widget.record.stage;
    status = widget.record.status;
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void save() {
    try {
      widget.database.addEvent(
        widget.record.id!,
        date,
        stage,
        status,
        note.text,
        progress,
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('记录一次进展'),
    content: SizedBox(
      width: 510,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            DateField(
              value: date,
              firstDate: widget.record.appliedAt,
              onChanged: (v) => setState(() => date = v),
              label: '事件日期',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('收到新的招聘进展'),
              subtitle: const Text('关闭后仅保存跟进备注，不重置等待天数'),
              value: progress,
              onChanged: (v) => setState(() => progress = v),
            ),
            if (progress) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: stage,
                      decoration: const InputDecoration(labelText: '阶段'),
                      items: stages
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (s) => stage = s!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: statuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (s) => status = s!,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              key: const Key('eventNote'),
              controller: note,
              minLines: 3,
              maxLines: 6,
              maxLength: 10000,
              decoration: const InputDecoration(
                labelText: '事件说明',
                hintText: '例如：收到一面邀请，周五下午 2 点',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '补录历史事件按日期排序；同一天以最后录入的进展为准。',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('saveEvent'),
        onPressed: save,
        child: const Text('保存事件'),
      ),
    ],
  );
}

class ResumeDialog extends StatefulWidget {
  const ResumeDialog({
    super.key,
    required this.database,
    required this.path,
    this.resume,
  });
  final JobDatabase database;
  final String path;
  final ResumeRecord? resume;
  @override
  State<ResumeDialog> createState() => _ResumeDialogState();
}

class _ResumeDialogState extends State<ResumeDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, version;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text:
          widget.resume?.name ??
          widget.path
              .split(RegExp(r'[/\\]'))
              .last
              .replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    version = TextEditingController(text: widget.resume?.version ?? 'v1.0');
  }

  @override
  void dispose() {
    name.dispose();
    version.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.resume == null) {
        await widget.database.importResume(
          widget.path,
          name.text,
          version.text,
        );
      } else {
        widget.database.updateResume(
          widget.resume!.id,
          name.text,
          version.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '保存失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.resume == null ? '导入简历' : '编辑简历信息'),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '简历名称 *'),
                  maxLength: 100,
                  validator: requiredText,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: version,
                  decoration: const InputDecoration(
                    labelText: '版本 *',
                    hintText: 'v1.0 / 产品岗 / 秋招版',
                  ),
                  maxLength: 60,
                  validator: requiredText,
                ),
                const SizedBox(height: 16),
                const Text(
                  '文件路径',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  widget.path,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text(
                  '导入时会在本机保存一份副本，原文件移动后仍可打开。',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? '正在保存…' : '保存简历'),
        ),
      ],
    ),
  );
}
