import 'package:flutter/material.dart';
import '../data/models.dart';
import 'widgets.dart';

class FollowUpsPanel extends StatelessWidget {
  const FollowUpsPanel({
    super.key,
    required this.records,
    required this.onOpen,
    required this.onComplete,
    required this.onViewAll,
  });
  final List<ApplicationRecord> records;
  final ValueChanged<ApplicationRecord> onOpen, onComplete;
  final VoidCallback onViewAll;
  @override
  Widget build(BuildContext context) {
    final today = calendarDate(DateTime.now());
    final upcoming =
        records.where((r) => r.isActive && r.followUpAt != null).toList()
          ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
    final due = upcoming.where((r) => r.isDue(today)).length;
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: accent,
                  size: 21,
                ),
                const SizedBox(width: 10),
                const Text(
                  '跟进计划',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                StatusBadge('$due 项到期'),
                const Spacer(),
                TextButton(onPressed: onViewAll, child: const Text('查看计划 →')),
              ],
            ),
            const Text(
              '完成待办只取消本次提醒，不会改动招聘进度。',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            ...upcoming
                .take(4)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '完成跟进计划',
                          onPressed: () => onComplete(r),
                          icon: const Icon(
                            Icons.radio_button_unchecked,
                            color: accent,
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => onOpen(r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.company} · ${r.position}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  r.nextAction.isEmpty
                                      ? '查看进展并安排下一步'
                                      : r.nextAction,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        StatusBadge(
                          r.followUpAt!.isBefore(today)
                              ? '逾期 ${calendarDays(r.followUpAt!, today)} 天'
                              : r.followUpAt == today
                              ? '今天'
                              : dateText(r.followUpAt!),
                          color: r.isDue(today)
                              ? const Color(0xFFB7862D)
                              : muted,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
