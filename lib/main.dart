import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'app.dart';
import 'data/database.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final override = Platform.environment['JOBTRACKER_DATA_DIR'];
    final directory =
        override ??
        p.join(
          p.join(
            Platform.environment['LOCALAPPDATA'] ?? Directory.current.path,
            'JobTracker',
          ),
          'data',
        );
    final database = JobDatabase(directory);
    runApp(JobTracker(database: database));
  } catch (error) {
    runApp(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: Surface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('暂时无法打开本地数据', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 20),
                    const Text('请检查目录权限及磁盘空间后重新启动。已有数据不会被自动清除。'),
                    const SizedBox(height: 16),
                    SelectableText(error.toString()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
