import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'models.dart';

/// Owns the local database. Application changes and timeline events are atomic.
class JobDatabase {
  JobDatabase(this.directory) {
    Directory(directory).createSync(recursive: true);
    db = sqlite3.open(p.join(directory, 'jobtracker.sqlite3'));
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA busy_timeout = 5000');
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > 2) {
      db.close();
      throw StateError('此数据由更新版本创建，请使用新版 JobTracker。');
    }
    if (version == 0) {
      transaction(() {
        db.execute(
          '''CREATE TABLE resumes (
          id INTEGER PRIMARY KEY, name TEXT NOT NULL, version TEXT NOT NULL,
          file_path TEXT NOT NULL, original_path TEXT NOT NULL, imported_at TEXT NOT NULL)''',
        );
        db.execute(
          '''CREATE TABLE applications (
          id INTEGER PRIMARY KEY, company TEXT NOT NULL, position TEXT NOT NULL,
          applied_at TEXT NOT NULL, stage TEXT NOT NULL, status TEXT NOT NULL,
          source TEXT NOT NULL DEFAULT '', url TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
          resume_id INTEGER REFERENCES resumes(id) ON DELETE SET NULL, last_progress TEXT NOT NULL)''',
        );
        db.execute(
          '''CREATE TABLE events (
          id INTEGER PRIMARY KEY, application_id INTEGER NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
          occurred_at TEXT NOT NULL, stage TEXT NOT NULL, status TEXT NOT NULL,
          note TEXT NOT NULL, is_progress INTEGER NOT NULL CHECK(is_progress IN (0,1)))''',
        );
        db.execute(
          'CREATE INDEX events_application ON events(application_id, occurred_at, id)',
        );
        db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        db.execute('PRAGMA user_version = 1');
      });
    }
    if (version < 2) {
      transaction(() {
        db.execute('ALTER TABLE applications ADD COLUMN follow_up_at TEXT');
        db.execute(
          "ALTER TABLE applications ADD COLUMN next_action TEXT NOT NULL DEFAULT ''",
        );
        db.execute(
          'ALTER TABLE applications ADD COLUMN starred INTEGER NOT NULL DEFAULT 0 CHECK(starred IN (0,1))',
        );
        db.execute('PRAGMA user_version = 2');
      });
    }
  }
  final String directory;
  late final Database db;
  void close() => db.close();
  T transaction<T>(T Function() operation) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<ApplicationRecord> applications() => db
      .select('SELECT * FROM applications ORDER BY last_progress DESC, id DESC')
      .map(ApplicationRecord.fromRow)
      .toList();
  List<ResumeRecord> resumes() => db
      .select('SELECT * FROM resumes ORDER BY id DESC')
      .map(
        (row) => ResumeRecord.fromRow({
          ...row,
          'file_path': p.isAbsolute(row['file_path'] as String)
              ? row['file_path']
              : p.join(directory, row['file_path'] as String),
        }),
      )
      .toList();
  List<ProgressEvent> events(int id) => db
      .select(
        'SELECT * FROM events WHERE application_id = ? ORDER BY occurred_at DESC, id DESC',
        [id],
      )
      .map(ProgressEvent.fromRow)
      .toList();
  int get threshold =>
      int.tryParse(
        db
                    .select(
                      "SELECT value FROM settings WHERE key = 'stale_days'",
                    )
                    .firstOrNull?['value']
                as String? ??
            '',
      ) ??
      14;
  void setThreshold(int days) {
    if (days < 1 || days > 365) throw ArgumentError('提醒天数应为 1–365 天');
    db.execute(
      "INSERT OR REPLACE INTO settings(key,value) VALUES('stale_days',?)",
      [days.toString()],
    );
  }

  void _validate(String stage, String status) {
    if (!stages.contains(stage) || !statuses.contains(status)) {
      throw ArgumentError('无效的阶段或状态');
    }
  }

  int saveApplication(
    ApplicationRecord record, {
    DateTime? now,
  }) => transaction(() {
    _validate(record.stage, record.status);
    final today = calendarDate(now ?? DateTime.now());
    if (record.company.trim().isEmpty || record.position.trim().isEmpty) {
      throw ArgumentError('请填写公司和岗位');
    }
    if (calendarDate(record.appliedAt).isAfter(today)) {
      throw ArgumentError('投递日期不能晚于今天');
    }
    final values = <Object?>[
      record.company.trim(),
      record.position.trim(),
      dateText(record.appliedAt),
      record.stage,
      record.status,
      record.source.trim(),
      record.url.trim(),
      record.notes.trim(),
      record.resumeId,
      record.followUpAt == null ? null : dateText(record.followUpAt!),
      record.nextAction.trim(),
      record.starred ? 1 : 0,
    ];
    if (record.id == null) {
      db.execute(
        'INSERT INTO applications(company,position,applied_at,stage,status,source,url,notes,resume_id,follow_up_at,next_action,starred,last_progress) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [...values, dateText(record.appliedAt)],
      );
      final id = db.lastInsertRowId;
      _insertEvent(
        id,
        record.appliedAt,
        record.stage,
        record.status,
        '创建求职记录',
        true,
      );
      return id;
    }
    final old = db.select('SELECT * FROM applications WHERE id = ?', [
      record.id,
    ]).first;
    final firstEvent =
        db.select(
              'SELECT MIN(occurred_at) AS first_at FROM events WHERE application_id = ?',
              [record.id],
            ).first['first_at']
            as String?;
    if (firstEvent != null &&
        dateText(record.appliedAt).compareTo(firstEvent) > 0) {
      throw ArgumentError('投递日期不能晚于已有的最早事件（$firstEvent）');
    }
    db.execute(
      'UPDATE applications SET company=?,position=?,applied_at=?,stage=?,status=?,source=?,url=?,notes=?,resume_id=?,follow_up_at=?,next_action=?,starred=? WHERE id=?',
      [...values, record.id],
    );
    if (old['stage'] != record.stage || old['status'] != record.status) {
      _insertEvent(
        record.id!,
        today,
        record.stage,
        record.status,
        '编辑记录：更新阶段或状态',
        true,
      );
    }
    _recompute(record.id!);
    return record.id!;
  });
  void _insertEvent(
    int id,
    DateTime at,
    String stage,
    String status,
    String note,
    bool progress,
  ) => db.execute(
    'INSERT INTO events(application_id,occurred_at,stage,status,note,is_progress) VALUES(?,?,?,?,?,?)',
    [id, dateText(at), stage, status, note.trim(), progress ? 1 : 0],
  );
  void addEvent(
    int id,
    DateTime at,
    String stage,
    String status,
    String note,
    bool progress, {
    DateTime? now,
  }) => transaction(() {
    _validate(stage, status);
    final record = ApplicationRecord.fromRow(
      db.select('SELECT * FROM applications WHERE id=?', [id]).first,
    );
    if (calendarDate(at).isBefore(record.appliedAt) ||
        calendarDate(at).isAfter(calendarDate(now ?? DateTime.now()))) {
      throw ArgumentError('事件日期应在投递日期与今天之间');
    }
    if (!progress && note.trim().isEmpty) throw ArgumentError('请填写跟进备注');
    _insertEvent(id, at, stage, status, note, progress);
    _recompute(id);
  });
  void _recompute(int id) {
    // Backdated entries belong in history and never overwrite newer progress.
    final latest = db.select(
      'SELECT * FROM events WHERE application_id=? AND is_progress=1 ORDER BY occurred_at DESC,id DESC LIMIT 1',
      [id],
    ).first;
    db.execute(
      'UPDATE applications SET stage=?,status=?,last_progress=? WHERE id=?',
      [latest['stage'], latest['status'], latest['occurred_at'], id],
    );
  }

  void deleteApplication(int id) =>
      db.execute('DELETE FROM applications WHERE id=?', [id]);
  void toggleStar(int id) => db.execute(
    'UPDATE applications SET starred = 1 - starred WHERE id=?',
    [id],
  );
  void completeFollowUp(int id) => db.execute(
    "UPDATE applications SET follow_up_at=NULL, next_action='' WHERE id=?",
    [id],
  );
  Future<void> importResume(String source, String name, String version) async {
    if (name.trim().isEmpty || version.trim().isEmpty) {
      throw ArgumentError('请填写简历名称和版本');
    }
    if (![
      '.pdf',
      '.doc',
      '.docx',
    ].contains(p.extension(source).toLowerCase())) {
      throw ArgumentError('仅支持 PDF、DOC、DOCX 文件');
    }
    final folder = Directory(p.join(directory, 'resumes'));
    await folder.create(recursive: true);
    final destination = p.join(
      folder.path,
      '${DateTime.now().microsecondsSinceEpoch}_${p.basename(source)}',
    );
    final file = await File(source).copy(destination);
    try {
      db.execute(
        'INSERT INTO resumes(name,version,file_path,original_path,imported_at) VALUES(?,?,?,?,?)',
        [
          name.trim(),
          version.trim(),
          p.relative(file.path, from: directory),
          source,
          DateTime.now().toIso8601String(),
        ],
      );
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }

  void updateResume(int id, String name, String version) {
    if (name.trim().isEmpty || version.trim().isEmpty) {
      throw ArgumentError('请填写简历名称和版本');
    }
    db.execute('UPDATE resumes SET name=?,version=? WHERE id=?', [
      name.trim(),
      version.trim(),
      id,
    ]);
  }

  // Removing metadata unlinks applications. Retain the copy to prevent accidental file loss.
  void deleteResume(int id) =>
      db.execute('DELETE FROM resumes WHERE id=?', [id]);
}
