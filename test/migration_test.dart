import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jobtracker/data/database.dart';

void main() {
  test('v1 database migrates to v2 without losing records, events or settings', () {
    final directory = Directory.systemTemp.createTempSync('jobtracker_v1_');
    final legacy = sqlite3.open('${directory.path}/jobtracker.sqlite3');
    legacy.execute(
      'CREATE TABLE resumes(id INTEGER PRIMARY KEY,name TEXT NOT NULL,version TEXT NOT NULL,file_path TEXT NOT NULL,original_path TEXT NOT NULL,imported_at TEXT NOT NULL)',
    );
    legacy.execute(
      "CREATE TABLE applications(id INTEGER PRIMARY KEY,company TEXT NOT NULL,position TEXT NOT NULL,applied_at TEXT NOT NULL,stage TEXT NOT NULL,status TEXT NOT NULL,source TEXT NOT NULL DEFAULT '',url TEXT NOT NULL DEFAULT '',notes TEXT NOT NULL DEFAULT '',resume_id INTEGER REFERENCES resumes(id) ON DELETE SET NULL,last_progress TEXT NOT NULL)",
    );
    legacy.execute(
      'CREATE TABLE events(id INTEGER PRIMARY KEY,application_id INTEGER NOT NULL REFERENCES applications(id) ON DELETE CASCADE,occurred_at TEXT NOT NULL,stage TEXT NOT NULL,status TEXT NOT NULL,note TEXT NOT NULL,is_progress INTEGER NOT NULL CHECK(is_progress IN (0,1)))',
    );
    legacy.execute(
      'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
    legacy.execute(
      "INSERT INTO applications(id,company,position,applied_at,stage,status,last_progress) VALUES(1,'旧版公司','工程师','2026-09-01','面试','进行中','2026-09-20')",
    );
    legacy.execute(
      "INSERT INTO events VALUES(1,1,'2026-09-20','面试','进行中','旧版面试记录',1)",
    );
    legacy.execute("INSERT INTO settings VALUES('stale_days','30')");
    legacy.execute('PRAGMA user_version=1');
    legacy.close();
    final db = JobDatabase(directory.path);
    expect(db.applications().single.company, '旧版公司');
    expect(db.events(1).single.note, '旧版面试记录');
    expect(db.applications().single.followUpAt, isNull);
    expect(db.applications().single.starred, isFalse);
    expect(db.threshold, 30);
    expect(db.db.select('PRAGMA user_version').single.values.single, 2);
    db.close();
    final reopened = JobDatabase(directory.path);
    expect(reopened.applications().single.stage, '面试');
    reopened.close();
    directory.deleteSync(recursive: true);
  });
}
