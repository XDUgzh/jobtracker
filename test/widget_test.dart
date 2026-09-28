import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtracker/app.dart';
import 'package:jobtracker/data/database.dart';
import 'package:jobtracker/data/models.dart';

void main() {
  testWidgets(
    'create, edit, add event, navigate, and delete in Chinese desktop UI',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final folder = Directory.systemTemp.createTempSync('jobtracker_ui_');
      final db = JobDatabase(folder.path);
      await tester.pumpWidget(JobTracker(database: db));
      await tester.pumpAndSettle();
      expect(find.text('每一步，都在靠近。'), findsOneWidget);
      await tester.tap(find.byKey(const Key('addApplication')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('companyField')), '测试公司');
      await tester.enterText(
        find.byKey(const Key('positionField')),
        'Flutter 工程师',
      );
      final formScroller = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('followUpSwitch')),
        250,
        scrollable: formScroller,
      );
      await tester.tap(find.byKey(const Key('followUpSwitch')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('nextActionField')),
        200,
        scrollable: formScroller,
      );
      await tester.enterText(
        find.byKey(const Key('nextActionField')),
        '准备面试材料',
      );
      await tester.tap(find.byKey(const Key('saveApplication')));
      await tester.pumpAndSettle();
      expect(db.applications().single.company, '测试公司');
      expect(db.applications().single.nextAction, '准备面试材料');
      expect(db.applications().single.isDue(DateTime.now()), isTrue);
      expect(find.text('求职时间轴'), findsOneWidget);
      await tester.tap(find.text('新增事件'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('eventNote')), '收到新的招聘消息');
      await tester.tap(find.byKey(const Key('saveEvent')));
      await tester.pumpAndSettle();
      expect(db.events(db.applications().single.id!).length, 2);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('positionField')),
        '高级 Flutter 工程师',
      );
      await tester.tap(find.byKey(const Key('saveApplication')));
      await tester.pumpAndSettle();
      expect(db.applications().single.position, '高级 Flutter 工程师');
      await tester.tap(find.text('返回求职记录'));
      await tester.pumpAndSettle();
      expect(find.text('高级 Flutter 工程师'), findsOneWidget);
      await tester.tap(find.text('高级 Flutter 工程师'));
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(
        tester.element(find.text('返回求职记录')),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('删除此记录'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('删除此记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(db.applications(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      db.close();
      folder.deleteSync(recursive: true);
    },
  );
  testWidgets('minimum desktop size has no overflow across primary pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 610);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final folder = Directory.systemTemp.createTempSync('jobtracker_small_');
    final db = JobDatabase(folder.path);
    await tester.pumpWidget(JobTracker(database: db));
    await tester.pumpAndSettle();
    for (final label in ['求职记录', '简历库', '偏好设置', '求职总览']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    db.close();
    folder.deleteSync(recursive: true);
  });
  testWidgets(
    'dashboard completes follow-ups and favorite filter updates immediately',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final folder = Directory.systemTemp.createTempSync('jobtracker_plan_ui_');
      final db = JobDatabase(folder.path);
      final now = calendarDate(DateTime.now());
      db.saveApplication(
        ApplicationRecord(
          company: '收藏公司',
          position: '工程师',
          appliedAt: now,
          lastProgress: now,
          followUpAt: now,
          nextAction: '联系招聘负责人',
          starred: true,
        ),
      );
      await tester.pumpWidget(JobTracker(database: db));
      await tester.pumpAndSettle();
      expect(find.text('联系招聘负责人'), findsOneWidget);
      await tester.tap(find.byTooltip('完成跟进计划'));
      await tester.pumpAndSettle();
      expect(db.applications().single.followUpAt, isNull);
      expect(db.events(db.applications().single.id!).length, 1);
      await tester.tap(find.text('求职记录').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('重点收藏'));
      await tester.pumpAndSettle();
      expect(find.text('收藏公司'), findsOneWidget);
      await tester.tap(find.byTooltip('取消收藏'));
      await tester.pumpAndSettle();
      expect(find.text('没有找到匹配的记录'), findsOneWidget);
      expect(db.applications().single.starred, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      db.close();
      folder.deleteSync(recursive: true);
    },
  );
}
