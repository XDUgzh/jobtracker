import 'package:flutter/material.dart';
import '../data/models.dart';
import 'widgets.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.records,
    required this.threshold,
    required this.onAdd,
    required this.onOpen,
    required this.onFilter,
  });
  final List<ApplicationRecord> records;
  final int threshold;
  final VoidCallback onAdd;
  final ValueChanged<ApplicationRecord> onOpen;
  final ValueChanged<String> onFilter;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = records.where((r) => r.isActive).length;
    final stale = records.where((r) => r.isStale(now, threshold)).toList()
      ..sort((a, b) => a.lastProgress.compareTo(b.lastProgress));
    final metrics = <(String, int, IconData, Color, String)>[
      ('已投递', records.length, Icons.send_outlined, accent, '全部'),
      (
        '笔试',
        records.where((r) => r.isActive && r.stage == '笔试').length,
        Icons.edit_note_rounded,
        const Color(0xFFB7862D),
        '笔试',
      ),
      (
        '面试',
        records.where((r) => r.isActive && r.stage == '面试').length,
        Icons.forum_outlined,
        const Color(0xFF8864C4),
        '面试',
      ),
      (
        'Offer',
        records.where((r) => r.isActive && r.stage == 'Offer').length,
        Icons.celebration_outlined,
        const Color(0xFF16876F),
        'Offer',
      ),
      (
        '已结束',
        records.where((r) => !r.isActive).length,
        Icons.task_alt_outlined,
        muted,
        '已结束',
      ),
    ];
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '每一步，都在靠近。',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    records.isEmpty
                        ? '从第一份投递开始，把机会和进展整理在一起。'
                        : '你有 $active 个进行中的机会，保持自己的节奏。',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              key: const Key('addApplication'),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('新增投递'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 14,
            children: metrics
                .map(
                  (m) => SizedBox(
                    width:
                        (constraints.maxWidth -
                            (constraints.maxWidth < 850 ? 28 : 56)) /
                        (constraints.maxWidth < 850 ? 3 : 5),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: line),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onFilter(m.$5),
                        child: Padding(
                          padding: const EdgeInsets.all(19),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(m.$3, size: 19, color: m.$4),
                                  const Spacer(),
                                  Icon(
                                    Icons.north_east,
                                    size: 13,
                                    color: m.$4.withValues(alpha: .5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '${m.$2}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                m.$1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '已投递为累计记录数；笔试、面试、Offer 为当前进行中的数量。',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 24),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 21,
                    color: Color(0xFFB7862D),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '值得跟进的机会',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  StatusBadge(
                    '${stale.length}',
                    color: const Color(0xFFB7862D),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => onFilter('长期无响应'),
                    child: const Text('查看全部 →'),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '超过 $threshold 天没有新的进展，仅作提醒，不代表拒绝。',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              if (stale.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF16876F),
                        size: 21,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '目前没有需要提醒的记录，按自己的节奏继续前进。',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ...stale
                  .take(3)
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: InkWell(
                        onTap: () => onOpen(r),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              companyAvatar(r.company),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.company,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.position,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(r.stage, color: stageColor(r.stage)),
                              const SizedBox(width: 24),
                              Text(
                                '已等待 ${r.waitingDays(now)} 天',
                                style: const TextStyle(
                                  color: Color(0xFFB7862D),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.chevron_right,
                                color: muted,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '最近进展',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => onFilter('全部'),
                    child: const Text('全部记录 →'),
                  ),
                ],
              ),
              if (records.isEmpty)
                EmptyState(
                  title: '新的机会，从这里开始',
                  description: '记录公司、岗位和简历版本，让求职不再散落各处。',
                  icon: Icons.work_outline_rounded,
                  action: OutlinedButton(
                    onPressed: onAdd,
                    child: const Text('添加第一条求职记录'),
                  ),
                ),
              ...records
                  .take(5)
                  .map(
                    (r) => InkWell(
                      onTap: () => onOpen(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            companyAvatar(r.company),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 3,
                              child: Text(
                                r.company,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                r.position,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: StatusBadge(
                                  r.isActive ? r.stage : r.status,
                                  color: r.isActive
                                      ? stageColor(r.stage)
                                      : muted,
                                ),
                              ),
                            ),
                            Text(
                              dateText(r.lastProgress),
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            '把精力留给准备，把记录交给 JobTracker。',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ),
      ],
    );
  }
}

Widget companyAvatar(String company) => Container(
  width: 40,
  height: 40,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: accent.withValues(alpha: .07),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    company.characters.first,
    style: const TextStyle(
      color: accent,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  ),
);
