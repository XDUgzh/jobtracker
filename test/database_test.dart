import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtracker/data/database.dart';
import 'package:jobtracker/data/models.dart';

void main() {
  late Directory temp;
  late JobDatabase db;
  final today = DateTime(2026, 9, 28);
  setUp(() {
    temp = Directory.systemTemp.createTempSync('jobtracker_test_');
    db = JobDatabase(temp.path);
  });
  tearDown(() {
    db.close();
    temp.deleteSync(recursive: true);
  });
  int add({int? resumeId}) => db.saveApplication(
    ApplicationRecord(
      company: '示例公司',
      position: '工程师',
      appliedAt: DateTime(2026, 9, 1),
      lastProgress: DateTime(2026, 9, 1),
      resumeId: resumeId,
    ),
    now: today,
  );

  test(
    'silent applications become stale but never rejected, and persist after reopening',
    () {
      add();
      var r = db.applications().single;
      expect(r.waitingDays(today), 27);
      expect(r.isStale(today, 14), isTrue);
      expect(r.status, '进行中');
      db.setThreshold(30);
      db.close();
      db = JobDatabase(temp.path);
      r = db.applications().single;
      expect(r.isStale(today, db.threshold), isFalse);
      expect(db.events(r.id!).length, 1);
    },
  );
  test(
    'historical events do not override newest progress; same-day events use insertion order',
    () {
      final id = add();
      db.addEvent(
        id,
        DateTime(2026, 9, 20),
        '面试',
        '进行中',
        '一面',
        true,
        now: today,
      );
      db.addEvent(
        id,
        DateTime(2026, 9, 10),
        '笔试',
        '进行中',
        '补录笔试',
        true,
        now: today,
      );
      expect(db.applications().single.stage, '面试');
      expect(db.applications().single.waitingDays(today), 8);
      db.addEvent(
        id,
        DateTime(2026, 9, 20),
        'Offer',
        '进行中',
        'Offer',
        true,
        now: today,
      );
      expect(db.applications().single.stage, 'Offer');
      expect(db.applications().single.isStale(DateTime(2027), 14), isFalse);
    },
  );
  test('follow-up notes do not reset progress or status', () {
    final id = add();
    db.addEvent(id, today, '已投递', '进行中', '主动询问 HR，无回复', false, now: today);
    expect(db.applications().single.waitingDays(today), 27);
    expect(db.events(id).first.isProgress, isFalse);
  });
  test('metadata edits preserve wait time; stage changes create events', () {
    final id = add();
    db.saveApplication(
      ApplicationRecord(
        id: id,
        company: '改名公司',
        position: '工程师',
        appliedAt: DateTime(2026, 9, 1),
        lastProgress: today,
        notes: '仅修改备注',
      ),
      now: today,
    );
    expect(db.applications().single.waitingDays(today), 27);
    expect(db.events(id).length, 1);
    db.saveApplication(
      ApplicationRecord(
        id: id,
        company: '改名公司',
        position: '工程师',
        appliedAt: DateTime(2026, 9, 1),
        lastProgress: today,
        stage: '面试',
      ),
      now: today,
    );
    expect(db.applications().single.waitingDays(today), 0);
    expect(db.events(id).length, 2);
  });
  test(
    'resume copy survives original deletion; deleting resume unlinks applications',
    () async {
      final source = File('${temp.path}/sample.PDF')
        ..writeAsStringSync('%PDF-1.4 test');
      await db.importResume(source.path, '通用简历', 'v1');
      final resume = db.resumes().single;
      add(resumeId: resume.id);
      source.deleteSync();
      expect(File(resume.path).existsSync(), isTrue);
      expect(File(resume.path).readAsStringSync(), '%PDF-1.4 test');
      db.updateResume(resume.id, '工程岗简历', 'v2');
      expect(db.resumes().single.version, 'v2');
      db.deleteResume(resume.id);
      expect(db.applications().single.resumeId, isNull);
      expect(File(resume.path).existsSync(), isTrue);
    },
  );
  test('invalid dates roll back and deletions cascade through timeline', () {
    final id = add();
    expect(
      () => db.addEvent(
        id,
        DateTime(2026, 8, 1),
        '面试',
        '进行中',
        '',
        true,
        now: today,
      ),
      throwsArgumentError,
    );
    expect(
      () => db.addEvent(
        id,
        DateTime(2026, 10, 1),
        '面试',
        '进行中',
        '',
        true,
        now: today,
      ),
      throwsArgumentError,
    );
    expect(db.events(id).length, 1);
    db.addEvent(id, today, '面试', '明确拒绝', '收到拒信', true, now: today);
    expect(db.applications().single.isStale(DateTime(2027), 14), isFalse);
    db.deleteApplication(id);
    expect(db.applications(), isEmpty);
    expect(db.events(id), isEmpty);
  });
  test('wait threshold is inclusive and calendar day based', () {
    final r = ApplicationRecord(
      company: 'A',
      position: 'B',
      appliedAt: DateTime(2026, 9, 1),
      lastProgress: DateTime(2026, 9, 1, 23, 59),
    );
    expect(r.isStale(DateTime(2026, 9, 14), 14), isFalse);
    expect(r.isStale(DateTime(2026, 9, 15), 14), isTrue);
    expect(r.waitingDays(DateTime(2026, 8, 1)), 0);
  });

  test('moving a full backup preserves imported resume references', () async {
    final source = File('${temp.path}/resume.docx')
      ..writeAsStringSync('fixture');
    await db.importResume(source.path, '测试简历', 'v1');
    db.close();
    temp = temp.renameSync('${temp.path}_moved');
    db = JobDatabase(temp.path);
    expect(File(db.resumes().single.path).readAsStringSync(), 'fixture');
  });
}
