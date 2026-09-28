import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:jobtracker/data/database.dart';
import 'package:jobtracker/data/models.dart';
import 'package:jobtracker/data/transfer.dart';

void main() {
  late Directory root;
  late JobDatabase db;
  final today = calendarDate(DateTime.now());
  setUp(() {
    root = Directory.systemTemp.createTempSync('jobtracker_transfer_');
    db = JobDatabase(p.join(root.path, 'data'));
  });
  tearDown(() {
    db.close();
    root.deleteSync(recursive: true);
  });
  int add({String company = '示例公司', int? resume, bool star = true}) =>
      db.saveApplication(
        ApplicationRecord(
          company: company,
          position: '软件工程师',
          appliedAt: today.subtract(const Duration(days: 20)),
          lastProgress: today,
          followUpAt: today,
          nextAction: '询问面试安排',
          starred: star,
          resumeId: resume,
        ),
      );
  test(
    'backup round-trip includes resumes, events, settings, plans and stars; pre-restore snapshot can undo',
    () async {
      final source = File(p.join(root.path, '简历.pdf'))
        ..writeAsBytesSync([37, 80, 68, 70, 0, 1, 255]);
      await db.importResume(source.path, '工程师简历', 'v3');
      final id = add(resume: db.resumes().single.id);
      db.addEvent(id, today, '面试', '进行中', '收到面试邀请', true);
      db.setThreshold(21);
      final backup = p.join(root.path, 'roundtrip.jobtracker');
      await DataTransfer.backup(db, backup);
      add(company: '备份后的新增记录');
      final undo = await DataTransfer.restore(db, backup);
      expect(File(undo).existsSync(), isTrue);
      expect(db.applications().length, 1);
      final restored = db.applications().single;
      expect(restored.starred, isTrue);
      expect(restored.isDue(today), isTrue);
      expect(restored.nextAction, '询问面试安排');
      expect(restored.stage, '面试');
      expect(db.events(id).length, 2);
      expect(db.threshold, 21);
      expect(
        File(db.resumes().single.path).readAsBytesSync(),
        source.readAsBytesSync(),
      );
      await DataTransfer.restore(db, undo);
      expect(db.applications().length, 2);
    },
  );
  test(
    'corrupt or inconsistent backup leaves current records and resume files unchanged',
    () async {
      add();
      final backup = File(p.join(root.path, 'bad.jobtracker'));
      await DataTransfer.backup(db, backup.path);
      final snapshot =
          jsonDecode(backup.readAsStringSync()) as Map<String, dynamic>;
      (snapshot['applications'] as List).first['stage'] = 'Offer';
      backup.writeAsStringSync(jsonEncode(snapshot));
      await expectLater(
        DataTransfer.restore(db, backup.path),
        throwsFormatException,
      );
      expect(db.applications().single.stage, '已投递');
      expect(db.events(db.applications().single.id!).length, 1);
      expect(Directory(p.join(db.directory, 'backups')).existsSync(), isFalse);
    },
  );
  test(
    'backup attachment paths cannot escape the managed resume directory',
    () async {
      final source = File(p.join(root.path, 'original.docx'))
        ..writeAsStringSync('fixture');
      await db.importResume(source.path, '简历', 'v1');
      final backup = File(p.join(root.path, 'paths.jobtracker'));
      await DataTransfer.backup(db, backup.path);
      final snapshot =
          jsonDecode(backup.readAsStringSync()) as Map<String, dynamic>;
      (snapshot['resumes'] as List).first['file_path'] = '../../escaped.docx';
      backup.writeAsStringSync(jsonEncode(snapshot));
      await DataTransfer.restore(db, backup.path);
      expect(
        p.isWithin(p.join(db.directory, 'resumes'), db.resumes().single.path),
        isTrue,
      );
      expect(File(p.join(root.path, 'escaped.docx')).existsSync(), isFalse);
    },
  );
  test(
    'invalid foreign keys are rejected before replacement',
    () async {
      add();
      final backup = File(p.join(root.path, 'invalid.jobtracker'));
      await DataTransfer.backup(db, backup.path);
      final snapshot =
          jsonDecode(backup.readAsStringSync()) as Map<String, dynamic>;
      (snapshot['applications'] as List).first['resume_id'] = 999;
      backup.writeAsStringSync(jsonEncode(snapshot));
      await expectLater(
        DataTransfer.restore(db, backup.path),
        throwsA(isA<Exception>()),
      );
      expect(db.applications().single.resumeId, isNull);
    },
  );
  test(
    'backup destination can be overwritten and contains committed WAL data',
    () async {
      final path = p.join(root.path, 'overwrite.jobtracker');
      await DataTransfer.backup(db, path);
      add();
      await DataTransfer.backup(db, path);
      final decoded = jsonDecode(File(path).readAsStringSync());
      expect(decoded['applications'].length, 1);
      expect(
        root.listSync().where((file) => file.path.endsWith('.tmp')),
        isEmpty,
      );
    },
  );
  test(
    'CSV is UTF-8 BOM, quoted, and protects spreadsheet formula prefixes',
    () {
      add(company: '=HYPERLINK("https://example.com")');
      add(company: '中文,公司\n第二行');
      final csv = DataTransfer.csv(db);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('"\'=HYPERLINK(""https://example.com"")"'));
      expect(csv, contains('"中文,公司\n第二行"'));
      expect(csv, contains('下次跟进日期'));
      expect(csv, contains('询问面试安排'));
    },
  );
  test(
    'due plans are calendar-based, closed records excluded, completing does not reset progress',
    () {
      final id = add();
      expect(db.applications().single.isDue(today), isTrue);
      expect(
        db.applications().single.isDue(today.subtract(const Duration(days: 1))),
        isFalse,
      );
      db.completeFollowUp(id);
      expect(db.applications().single.followUpAt, isNull);
      expect(db.applications().single.nextAction, isEmpty);
      expect(db.applications().single.waitingDays(today), 20);
      db.toggleStar(id);
      expect(db.applications().single.starred, isFalse);
      expect(db.events(id).length, 1);
      final closed = ApplicationRecord(
        company: 'A',
        position: 'B',
        appliedAt: today,
        lastProgress: today,
        followUpAt: today,
        status: '明确拒绝',
      );
      expect(closed.isDue(today), isFalse);
    },
  );
  test(
    'invalid backup date and unsupported versions leave current data intact',
    () async {
      add();
      final backup = File(p.join(root.path, 'date.jobtracker'));
      await DataTransfer.backup(db, backup.path);
      final snapshot =
          jsonDecode(backup.readAsStringSync()) as Map<String, dynamic>;
      (snapshot['applications'] as List).first['follow_up_at'] = '2026-02-31';
      backup.writeAsStringSync(jsonEncode(snapshot));
      await expectLater(
        DataTransfer.restore(db, backup.path),
        throwsFormatException,
      );
      snapshot['schema'] = 999;
      backup.writeAsStringSync(jsonEncode(snapshot));
      await expectLater(
        DataTransfer.restore(db, backup.path),
        throwsFormatException,
      );
      expect(db.applications().length, 1);
    },
  );
}
