import 'package:flutter/material.dart';
import '../data/models.dart';
import 'widgets.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.record,
    required this.events,
    required this.resume,
    required this.threshold,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onEvent,
    required this.onOpenFile,
    required this.onOpenLink,
    required this.onStar,
    required this.onComplete,
  });
  final ApplicationRecord record;
  final List<ProgressEvent> events;
  final ResumeRecord? resume;
  final int threshold;
  final VoidCallback onBack, onEdit, onDelete, onEvent, onStar, onComplete;
  final ValueChanged<String> onOpenFile, onOpenLink;
  @override
  Widget build(BuildContext context) {
    final stale = record.isStale(DateTime.now(), threshold);
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 17),
            label: const Text('返回求职记录'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.company,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    record.position,
                    style: const TextStyle(color: muted, fontSize: 17),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('编辑'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onEvent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增事件'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            StatusBadge(record.stage, color: stageColor(record.stage)),
            StatusBadge(
              record.status,
              color: record.isActive ? const Color(0xFF14886C) : muted,
            ),
            if (stale) const StatusBadge('长期无响应', color: Color(0xFFB7862D)),
          ],
        ),
        const SizedBox(height: 24),
        if (record.isActive && record.stage != 'Offer') ...[
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: stale ? const Color(0xFFFFF7E6) : const Color(0xFFEBF0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: stale ? const Color(0xFFB7862D) : accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '距最后进展已等待 ${record.waitingDays(DateTime.now())} 天${stale ? '。可以考虑主动跟进；没有消息不等于拒绝。' : '。每一步进展都值得记录。'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: stale ? const Color(0xFF996912) : accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        LayoutBuilder(
          builder: (context, c) {
            final information = info();
            final history = timeline();
            if (c.maxWidth < 900) {
              return Column(
                children: [information, const SizedBox(height: 24), history],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: information),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: history),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFBF4758),
            ),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('删除此记录'),
          ),
        ),
      ],
    );
  }

  Widget info() => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '投递信息',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        field('投递日期', dateText(record.appliedAt)),
        field('最后进展', dateText(record.lastProgress)),
        TextButton.icon(
          onPressed: onStar,
          icon: Icon(
            record.starred ? Icons.star_rounded : Icons.star_border_rounded,
          ),
          label: Text(record.starred ? '已收藏 · 点击取消' : '收藏为重点机会'),
        ),
        if (record.followUpAt != null) ...[
          const SizedBox(height: 16),
          field('下次跟进', dateText(record.followUpAt!)),
          if (record.nextAction.isNotEmpty) field('下一步', record.nextAction),
          TextButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('完成本次跟进'),
          ),
          const SizedBox(height: 16),
        ],
        field('来源', record.source.isEmpty ? '未填写' : record.source),
        const Text('岗位链接', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 6),
        if (record.url.isEmpty)
          const Text('未填写')
        else
          TextButton(
            onPressed: () => onOpenLink(record.url),
            child: Text(
              record.url,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 22),
        const Divider(color: line),
        const SizedBox(height: 16),
        const Text('投递简历', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 10),
        if (resume == null)
          const Text('未关联简历', style: TextStyle(color: muted))
        else ...[
          Text(
            '${resume!.name} · ${resume!.version}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => onOpenFile(resume!.path),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('打开这份简历'),
          ),
        ],
        const SizedBox(height: 18),
        const Divider(color: line),
        const SizedBox(height: 16),
        const Text('备注', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 10),
        SelectableText(
          record.notes.isEmpty ? '暂无备注' : record.notes,
          style: const TextStyle(height: 1.8),
        ),
      ],
    ),
  );
  Widget field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 8),
        SelectableText(value),
      ],
    ),
  );
  Widget timeline() => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '求职时间轴',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${events.length} 个事件',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 26),
        ...events.asMap().entries.map((entry) {
          final e = entry.value;
          final latest = entry.key == 0;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: latest ? accent : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: latest ? accent : line,
                            width: 3,
                          ),
                        ),
                      ),
                      if (entry.key < events.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.only(top: 6),
                            color: line,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateText(e.at),
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: e.isProgress
                              ? [
                                  StatusBadge(
                                    e.stage,
                                    color: stageColor(e.stage),
                                  ),
                                  StatusBadge(e.status, color: muted),
                                ]
                              : [const StatusBadge('跟进备注', color: muted)],
                        ),
                        if (e.note.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            e.note,
                            style: const TextStyle(height: 1.7, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}
