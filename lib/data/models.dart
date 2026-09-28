import 'dart:math' as math;

const stages = ['已投递', '处理中', '笔试', '面试', 'Offer'];
const statuses = ['进行中', '明确拒绝', '主动放弃', '已入职'];

DateTime calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);
String dateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
int calendarDays(DateTime from, DateTime to) => math.max(
  0,
  DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays,
);

class ApplicationRecord {
  const ApplicationRecord({
    this.id,
    required this.company,
    required this.position,
    required this.appliedAt,
    this.stage = '已投递',
    this.status = '进行中',
    this.source = '',
    this.url = '',
    this.notes = '',
    this.resumeId,
    this.followUpAt,
    this.nextAction = '',
    this.starred = false,
    required this.lastProgress,
  });
  final int? id;
  final String company, position, stage, status, source, url, notes;
  final DateTime appliedAt, lastProgress;
  final int? resumeId;
  final DateTime? followUpAt;
  final String nextAction;
  final bool starred;
  bool isDue(DateTime now) =>
      isActive &&
      followUpAt != null &&
      !calendarDate(followUpAt!).isAfter(calendarDate(now));
  bool get isActive => status == '进行中';
  int waitingDays(DateTime now) => calendarDays(lastProgress, now);
  bool isStale(DateTime now, int threshold) =>
      isActive && stage != 'Offer' && waitingDays(now) >= threshold;
  factory ApplicationRecord.fromRow(Map<String, Object?> row) =>
      ApplicationRecord(
        id: row['id'] as int,
        company: row['company'] as String,
        position: row['position'] as String,
        appliedAt: DateTime.parse(row['applied_at'] as String),
        stage: row['stage'] as String,
        status: row['status'] as String,
        source: row['source'] as String,
        url: row['url'] as String,
        notes: row['notes'] as String,
        resumeId: row['resume_id'] as int?,
        followUpAt: row['follow_up_at'] == null
            ? null
            : DateTime.parse(row['follow_up_at'] as String),
        nextAction: row['next_action'] as String? ?? '',
        starred: row['starred'] == 1,
        lastProgress: DateTime.parse(row['last_progress'] as String),
      );
}

class ProgressEvent {
  const ProgressEvent({
    required this.id,
    required this.applicationId,
    required this.at,
    required this.stage,
    required this.status,
    required this.note,
    required this.isProgress,
  });
  final int id, applicationId;
  final DateTime at;
  final String stage, status, note;
  final bool isProgress;
  factory ProgressEvent.fromRow(Map<String, Object?> row) => ProgressEvent(
    id: row['id'] as int,
    applicationId: row['application_id'] as int,
    at: DateTime.parse(row['occurred_at'] as String),
    stage: row['stage'] as String,
    status: row['status'] as String,
    note: row['note'] as String,
    isProgress: row['is_progress'] == 1,
  );
}

class ResumeRecord {
  const ResumeRecord({
    required this.id,
    required this.name,
    required this.version,
    required this.path,
    required this.originalPath,
    required this.importedAt,
  });
  final int id;
  final String name, version, path, originalPath;
  final DateTime importedAt;
  factory ResumeRecord.fromRow(Map<String, Object?> row) => ResumeRecord(
    id: row['id'] as int,
    name: row['name'] as String,
    version: row['version'] as String,
    path: row['file_path'] as String,
    originalPath: row['original_path'] as String,
    importedAt: DateTime.parse(row['imported_at'] as String),
  );
}
