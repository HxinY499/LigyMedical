import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/core/backup/backup_service.dart';
import 'package:ligy_medical/core/database/app_database.dart';
import 'package:ligy_medical/core/media/image_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('第 1 版数据库升级：指标数值补上所属记录的日期，数据一条不丢', () async {
    final temp = await Directory.systemTemp.createTemp('ligy_migration');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/v1.sqlite');

    // 用第 1 版原样的建表语句造一个老库（fixtures/schema_v1.sql 是 v1 导出的）。
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(File('test/fixtures/schema_v1.sql').readAsStringSync());
    raw.execute('PRAGMA user_version = 1');
    raw.execute(
      "INSERT INTO profiles VALUES ('me', '我', 0, 1, 0, 0, 0)",
    );
    raw.execute(
      "INSERT INTO records VALUES ('r1', 'me', 0, '2025-12-22', '第五医院', '', 1, 1)",
    );
    raw.execute(
      "INSERT INTO records VALUES ('r2', 'me', 0, '2026-04-26', '第五医院', '', 2, 2)",
    );
    raw.execute(
      "INSERT INTO indicators VALUES ('esr', 'me', '血沉', 'mm/h', NULL, 20, 0)",
    );
    raw.execute("INSERT INTO indicator_values VALUES ('v1', 'r1', 'esr', 3, 0)");
    raw.execute("INSERT INTO indicator_values VALUES ('v2', 'r2', 'esr', 1, 0)");
    raw.execute(
      "INSERT INTO injections VALUES ('i1', 'me', '2026-09-18', '阿达木', '左腹', '', '', 0, 0)",
    );
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final series = (await db.watchOneSeries('me', 'esr').first)!;
    expect(series.points.map((p) => p.date), ['2025-12-22', '2026-04-26']);
    expect(series.points.map((p) => p.value), [3, 1]);
    expect(series.points.map((p) => p.recordId), ['r1', 'r2']);
    expect(await db.watchInjections('me').first, hasLength(1));

    // 升级后的表允许单独添加的数值，外键级联照旧。
    await db.saveStandaloneValue(
      id: 'v3',
      indicatorId: 'esr',
      date: '2026-06-01',
      value: 2,
    );
    await (db.delete(db.records)..where((r) => r.id.equals('r1'))).go();
    final after = (await db.watchOneSeries('me', 'esr').first)!.points;
    expect(after.map((p) => p.valueId), ['v2', 'v3']);

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_indicator_values_indicator'",
        )
        .get();
    expect(indexes, hasLength(1), reason: '重建表后索引要补回来');
  });

  test('第 1 版备份（数值没有日期）照样能恢复，日期取所属记录', () async {
    final temp = await Directory.systemTemp.createTemp('ligy_v1_backup');
    addTearDown(() => temp.delete(recursive: true));
    final manifest = {
      'format': 'ligy-medical-backup',
      'version': 1,
      'createdAt': '2026-10-06T10:00:00',
      'profileCount': 1,
      'recordCount': 1,
      'attachmentCount': 0,
      'injectionCount': 0,
    };
    final data = {
      'profiles': [
        {
          'id': 'me',
          'name': '我',
          'colorIndex': 0,
          'injectionEnabled': false,
          'sortOrder': 0,
          'createdAt': 0,
          'updatedAt': 0,
        },
      ],
      'records': [
        {
          'id': 'r1',
          'profileId': 'me',
          'kind': 0,
          'date': '2026-04-26',
          'hospital': '',
          'content': '',
          'createdAt': 0,
          'updatedAt': 0,
        },
      ],
      'attachments': [],
      'fieldDefs': [],
      'fieldValues': [],
      'indicators': [
        {
          'id': 'esr',
          'profileId': 'me',
          'name': '血沉',
          'unit': '',
          'refLow': null,
          'refHigh': null,
          'createdAt': 0,
        },
      ],
      'indicatorValues': [
        {
          'id': 'v1',
          'recordId': 'r1',
          'indicatorId': 'esr',
          'value': 1.0,
          'sortOrder': 0,
        },
      ],
      'injectionPlans': [],
      'injections': [],
    };
    final archive = Archive()
      ..add(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
      ..add(ArchiveFile.string('data.json', jsonEncode(data)));
    final file = File('${temp.path}/old.ligymedical')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await BackupService(db, ImageStorage.atRoot(temp.path)).restore(file.path);
    final point = (await db.watchOneSeries('me', 'esr').first)!.points.single;
    expect(point.date, '2026-04-26');
    expect(point.recordId, 'r1');
  });
}
