import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'database.dart';
import 'models.dart';

/// Local-only interchange. No user-provided path is used as an extraction target.
class DataTransfer {
  static const maxBackupBytes = 100 * 1024 * 1024;
  static const columns = <String, List<String>>{
    'resumes': [
      'id',
      'name',
      'version',
      'file_path',
      'original_path',
      'imported_at',
    ],
    'applications': [
      'id',
      'company',
      'position',
      'applied_at',
      'stage',
      'status',
      'source',
      'url',
      'notes',
      'resume_id',
      'last_progress',
      'follow_up_at',
      'next_action',
      'starred',
    ],
    'events': [
      'id',
      'application_id',
      'occurred_at',
      'stage',
      'status',
      'note',
      'is_progress',
    ],
    'settings': ['key', 'value'],
  };

  static String csv(JobDatabase database) {
    final resumes = {
      for (final r in database.resumes()) r.id: '${r.name} · ${r.version}',
    };
    String cell(Object? value) {
      var text = value?.toString() ?? '';
      // Prevent spreadsheet formula execution when a company or note starts with =,+,-,@.
      if (RegExp(r'^\s*[=+\-@]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <List<Object?>>[
      [
        '公司',
        '岗位',
        '投递日期',
        '当前阶段',
        '记录状态',
        '来源',
        '岗位链接',
        '备注',
        '关联简历',
        '最后进展',
        '等待天数',
        '下次跟进日期',
        '下一步',
        '重点收藏',
      ],
      ...database.applications().map(
        (r) => [
          r.company,
          r.position,
          dateText(r.appliedAt),
          r.stage,
          r.status,
          r.source,
          r.url,
          r.notes,
          resumes[r.resumeId] ?? '',
          dateText(r.lastProgress),
          r.isActive && r.stage != 'Offer' ? r.waitingDays(DateTime.now()) : '',
          r.followUpAt == null ? '' : dateText(r.followUpAt!),
          r.nextAction,
          r.starred ? '是' : '否',
        ],
      ),
    ];
    return '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n';
  }

  static Future<void> backup(JobDatabase database, String destination) async {
    final snapshot = database.transaction(
      () => <String, Object?>{
        'format': 'JobTrackerBackup',
        'version': 1,
        'schema': 2,
        'created_at': DateTime.now().toIso8601String(),
        for (final table in columns.keys)
          table: database.db
              .select('SELECT * FROM $table')
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
      },
    );
    final attachments = <String, String>{};
    var total = 0;
    for (final row in snapshot['resumes'] as List<Map<String, Object?>>) {
      final resume = ResumeRecord.fromRow(row);
      final file = File(
        p.isAbsolute(resume.path)
            ? resume.path
            : p.join(database.directory, resume.path),
      );
      if (!await file.exists()) {
        throw StateError('简历“${resume.name}”的副本缺失，请先检查文件路径。');
      }
      total += await file.length();
      if (total > maxBackupBytes * .7) {
        throw StateError('简历总量过大，请使用关闭应用后复制数据目录的方式备份。');
      }
      attachments[resume.id.toString()] = base64Encode(
        await file.readAsBytes(),
      );
    }
    snapshot['attachments'] = attachments;
    final bytes = utf8.encode(jsonEncode(snapshot));
    if (bytes.length > maxBackupBytes) {
      throw StateError('备份超过 100 MB，请直接复制数据目录备份。');
    }
    final target = File(destination);
    final temporary = File(
      '$destination.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      // File.rename replaces an existing file atomically on Windows.
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// Restores validated data in one database transaction, keeping old attachments.
  /// Returns an automatic pre-restore backup path so the operation can be undone.
  static Future<String> restore(JobDatabase database, String source) async {
    final file = File(source);
    if (await file.length() > maxBackupBytes) {
      throw const FormatException('备份超过 100 MB');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'JobTrackerBackup' ||
        decoded['version'] != 1 ||
        decoded['schema'] != 2) {
      throw const FormatException('不是受支持的 JobTracker 备份文件');
    }
    final attachments = decoded['attachments'];
    if (attachments is! Map<String, dynamic>) {
      throw const FormatException('简历附件清单无效');
    }
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in columns.keys) {
      final list = decoded[table];
      if (list is! List || list.length > 100000) {
        throw FormatException('$table 数据无效');
      }
      tables[table] = list.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('记录格式无效');
        }
        final row = <String, Object?>{};
        for (final key in columns[table]!) {
          final value = item[key];
          final nullable = key == 'resume_id' || key == 'follow_up_at';
          final integer = [
            'id',
            'resume_id',
            'application_id',
            'starred',
            'is_progress',
          ].contains(key);
          if (value == null && nullable) {
            row[key] = null;
            continue;
          }
          if (integer ? value is! int : value is! String) {
            throw FormatException('$table.$key 格式无效');
          }
          row[key] = value;
        }
        return row;
      }).toList();
    }
    for (final row in tables['applications']!) {
      _date(row['applied_at']);
      _date(row['last_progress']);
      if (row['follow_up_at'] != null) _date(row['follow_up_at']);
      if ((row['company'] as String).trim().isEmpty ||
          (row['position'] as String).trim().isEmpty) {
        throw const FormatException('公司或岗位为空');
      }
      if (!stages.contains(row['stage']) || !statuses.contains(row['status'])) {
        throw const FormatException('求职阶段或状态无效');
      }
    }
    for (final row in tables['events']!) {
      _date(row['occurred_at']);
      if (!stages.contains(row['stage']) || !statuses.contains(row['status'])) {
        throw const FormatException('事件阶段或状态无效');
      }
    }
    for (final row in tables['settings']!) {
      if (row['key'] == 'stale_days') {
        final value = int.tryParse(row['value'] as String);
        if (value == null || value < 1 || value > 365) {
          throw const FormatException('提醒天数无效');
        }
      }
    }
    final scratch = await Directory.systemTemp.createTemp(
      'jobtracker_restore_',
    );
    JobDatabase? candidate;
    final restoredFolder = Directory(
      p.join(
        database.directory,
        'resumes',
        'restored_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    var committed = false;
    try {
      candidate = JobDatabase(scratch.path);
      await restoredFolder.create(recursive: true);
      for (final row in tables['resumes']!) {
        final raw = attachments[row['id'].toString()];
        if (raw is! String) throw const FormatException('备份缺少简历文件');
        if ((row['name'] as String).trim().isEmpty ||
            (row['version'] as String).trim().isEmpty ||
            DateTime.tryParse(row['imported_at'] as String) == null) {
          throw const FormatException('简历信息无效');
        }
        final ext = p.extension(row['file_path'] as String).toLowerCase();
        if (!['.pdf', '.doc', '.docx'].contains(ext)) {
          throw const FormatException('简历格式无效');
        }
        final id = row['id'] as int;
        if (id < 1) throw const FormatException('简历编号无效');
        final output = File(p.join(restoredFolder.path, '$id$ext'));
        await output.writeAsBytes(base64Decode(raw), flush: true);
        row['file_path'] = p.relative(output.path, from: database.directory);
      }
      _replace(candidate, tables);
      for (final r in candidate.applications()) {
        final history = candidate.events(r.id!);
        final latest = history.where((e) => e.isProgress).firstOrNull;
        if (r.id! < 1 ||
            latest == null ||
            latest.stage != r.stage ||
            latest.status != r.status ||
            latest.at != r.lastProgress ||
            history.any((e) => e.at.isBefore(r.appliedAt))) {
          throw const FormatException('时间轴与当前进度不一致');
        }
      }
      final backupFolder = Directory(p.join(database.directory, 'backups'));
      await backupFolder.create(recursive: true);
      final safetyCopy = p.join(
        backupFolder.path,
        'before_restore_${DateTime.now().microsecondsSinceEpoch}.jobtracker',
      );
      await backup(database, safetyCopy);
      _replace(database, tables);
      committed = true;
      return safetyCopy;
    } finally {
      candidate?.close();
      await scratch.delete(recursive: true);
      if (!committed && await restoredFolder.exists()) {
        await restoredFolder.delete(recursive: true);
      }
    }
  }

  static void _date(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null || dateText(parsed) != value) {
      throw const FormatException('日期无效');
    }
  }

  static void _replace(
    JobDatabase database,
    Map<String, List<Map<String, Object?>>> tables,
  ) {
    database.transaction(() {
      for (final table in ['events', 'applications', 'resumes', 'settings']) {
        database.db.execute('DELETE FROM $table');
      }
      for (final table in columns.keys) {
        final names = columns[table]!;
        for (final row in tables[table]!) {
          database.db.execute(
            'INSERT INTO $table(${names.join(',')}) VALUES(${List.filled(names.length, '?').join(',')})',
            names.map((key) => row[key]).toList(),
          );
        }
      }
    });
  }
}
