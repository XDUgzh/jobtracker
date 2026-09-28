import 'package:flutter/material.dart';
import '../data/models.dart';
import 'widgets.dart';
import 'dashboard.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.records,
    required this.threshold,
    required this.initialFilter,
    required this.onAdd,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.onStar,
  });
  final List<ApplicationRecord> records;
  final int threshold;
  final String initialFilter;
  final VoidCallback onAdd, onExport;
  final ValueChanged<ApplicationRecord> onStar;
  final ValueChanged<ApplicationRecord> onOpen, onEdit, onDelete;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  String query = '';
  late String filter;
  String order = '最近进展';
  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rows = widget.records.where((r) {
      final matches = '${r.company} ${r.position} ${r.source} ${r.notes}'
          .toLowerCase()
          .contains(query.toLowerCase());
      final included = switch (filter) {
        '全部' => true,
        '进行中' => r.isActive,
        '已结束' => !r.isActive,
        '长期无响应' => r.isStale(now, widget.threshold),
        '重点收藏' => r.starred,
        '跟进计划' => r.isActive && r.followUpAt != null,
        _ => r.stage == filter && r.isActive,
      };
      return matches && included;
    }).toList();
    rows.sort(
      (a, b) => switch (order) {
        '投递日期' => b.appliedAt.compareTo(a.appliedAt),
        '等待最久' => a.lastProgress.compareTo(b.lastProgress),
        _ => b.lastProgress.compareTo(a.lastProgress),
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '求职记录',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '共 ${widget.records.length} 个机会，把每一次尝试认真记录。',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '导出全部记录 CSV',
              onPressed: widget.onExport,
              icon: const Icon(Icons.download_outlined, color: accent),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('新增投递'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: '搜索公司、岗位、来源或备注',
                  prefixIcon: Icon(Icons.search, size: 21),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 165,
              child: DropdownButtonFormField<String>(
                initialValue: order,
                decoration: const InputDecoration(labelText: '排序'),
                items: ['最近进展', '投递日期', '等待最久']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => order = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['全部', '进行中', '重点收藏', '跟进计划', ...stages, '长期无响应', '已结束']
              .map(
                (s) => ChoiceChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  selected: filter == s,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => filter = s),
                  side: BorderSide(
                    color: filter == s ? accent.withValues(alpha: .2) : line,
                  ),
                  selectedColor: accent.withValues(alpha: .1),
                  backgroundColor: Colors.white,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Surface(
            padding: EdgeInsets.zero,
            child: rows.isEmpty
                ? EmptyState(
                    title: widget.records.isEmpty ? '还没有求职记录' : '没有找到匹配的记录',
                    description: widget.records.isEmpty
                        ? '点击“新增投递”，开始记录第一个机会。'
                        : '试试其他关键词或筛选条件。',
                    icon: Icons.manage_search_rounded,
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: line)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                '公司 / 岗位',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '阶段 / 状态',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '投递日期 / 等待',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ),
                            SizedBox(width: 38),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, index) =>
                              const Divider(height: 1, color: line),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final stale = r.isStale(now, widget.threshold);
                            return InkWell(
                              onTap: () => widget.onOpen(r),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 19,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        children: [
                                          InkWell(
                                            onTap: () => widget.onStar(r),
                                            child: Tooltip(
                                              message: r.starred
                                                  ? '取消收藏'
                                                  : '收藏机会',
                                              child: r.starred
                                                  ? const SizedBox(
                                                      width: 40,
                                                      height: 40,
                                                      child: Icon(
                                                        Icons.star_rounded,
                                                        color: Color(
                                                          0xFFB7862D,
                                                        ),
                                                      ),
                                                    )
                                                  : companyAvatar(r.company),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.company,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 7),
                                                Text(
                                                  r.position,
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          StatusBadge(
                                            r.stage,
                                            color: stageColor(r.stage),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            r.status,
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateText(r.appliedAt),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            !r.isActive
                                                ? '已结束等待'
                                                : r.stage == 'Offer'
                                                ? '已获 Offer'
                                                : '${stale ? '长期无响应 · ' : ''}${r.waitingDays(now)} 天',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: stale
                                                  ? const Color(0xFFB7862D)
                                                  : muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 38,
                                      child: PopupMenuButton<String>(
                                        tooltip: '记录操作',
                                        onSelected: (v) => v == 'edit'
                                            ? widget.onEdit(r)
                                            : widget.onDelete(r),
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('编辑记录'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('删除记录'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '显示 ${rows.length} 条记录',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
