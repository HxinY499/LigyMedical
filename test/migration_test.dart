import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
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
    raw.execute("INSERT INTO profiles VALUES ('me', '我', 0, 1, 0, 0, 0)");
    raw.execute(
      "INSERT INTO records VALUES ('r1', 'me', 0, '2025-12-22', '第五医院', '', 1, 1)",
    );
    raw.execute(
      "INSERT INTO records VALUES ('r2', 'me', 0, '2026-04-26', '第五医院', '', 2, 2)",
    );
    raw.execute(
      "INSERT INTO indicators VALUES ('esr', 'me', '血沉', 'mm/h', NULL, 20, 0)",
    );
    raw.execute(
      "INSERT INTO indicator_values VALUES ('v1', 'r1', 'esr', 3, 0)",
    );
    raw.execute(
      "INSERT INTO indicator_values VALUES ('v2', 'r2', 'esr', 1, 0)",
    );
    raw.execute(
      "INSERT INTO injections VALUES ('i1', 'me', '2026-09-18', '阿达木', '左腹', '', '', 0, 0)",
    );
    raw.execute(
      "INSERT INTO injections VALUES ('i0', 'me', '2026-09-04', '修美乐', '右腹', '', '', 0, 0)",
    );
    raw.execute(
      "INSERT INTO injection_plans VALUES ('me', '阿达木', 14, '左腹', '', 0)",
    );
    raw.execute(
      "INSERT INTO attachments VALUES ('img', 'r1', 0, 'media/r1/img.jpg', 'media/r1/img_thumb.jpg', '1000034567.jpg', 1, 0, 0)",
    );
    raw.execute(
      "INSERT INTO attachments VALUES ('pdf', 'r1', 1, 'media/r1/pdf.pdf', NULL, '体检报告.pdf', 1, 1, 0)",
    );
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final series = (await db.watchOneSeries('me', 'esr').first)!;
    expect(series.points.map((p) => p.date), ['2025-12-22', '2026-04-26']);
    expect(series.points.map((p) => p.value), [3, 1]);
    expect(series.points.map((p) => p.recordId), ['r1', 'r2']);
    expect(await db.watchInjections('me').first, hasLength(2));

    // 第 4 版的药品列表：计划的药品排第一，打过的药品各一个；计划指向自己的药品。
    final drugs = await db.watchDrugs('me').first;
    expect(drugs.map((d) => d.name), ['阿达木', '修美乐']);
    final plan = (await db.watchInjectionPlan('me').first)!;
    expect(plan.drugId, drugs.first.id);
    expect(plan.siteList, ['左腹']);

    // 第 5 版：图片附件原来的相册文件名清空，PDF 文件名保留。
    final attachments = (await db.watchRecord('r1').first)!.attachments;
    expect(attachments.map((a) => a.name), ['', '体检报告.pdf']);

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

    // 第 3 版加的注射照片表建好了，删那一针时照片行跟着级联删。
    await db
        .into(db.injectionPhotos)
        .insert(
          InjectionPhotosCompanion.insert(
            id: 'p1',
            profileId: 'me',
            injectionId: const Value('i1'),
            path: 'media/i1/p1.jpg',
            thumbnailPath: 'media/i1/p1_thumb.jpg',
            sizeBytes: 1,
            createdAt: 0,
          ),
        );
    expect(await db.photoList(injectionId: 'i1'), hasLength(1));
    await db.deleteInjection('i1');
    expect(await db.photoList(injectionId: 'i1'), isEmpty);
  });

  test('第 3 版数据库升级：计划的药品照片归到计划的药品，每一针的照片不动', () async {
    final temp = await Directory.systemTemp.createTemp('ligy_migration_v3');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/v3.sqlite');

    // fixtures/schema_v3.sql：v1 的建表语句 + v2 改过的指标数值表 + v3 新加的照片表。
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(File('test/fixtures/schema_v3.sql').readAsStringSync());
    raw.execute('PRAGMA user_version = 3');
    raw.execute("INSERT INTO profiles VALUES ('me', '我', 0, 1, 0, 0, 0)");
    raw.execute("INSERT INTO profiles VALUES ('mom', '妈妈', 1, 1, 1, 0, 0)");
    raw.execute(
      "INSERT INTO injections VALUES ('i1', 'me', '2026-09-18', '阿达木', '左腹', '', '', 0, 0)",
    );
    raw.execute(
      "INSERT INTO injection_plans VALUES ('me', ' 阿达木 ', 14, '左腹', '', 0)",
    );
    raw.execute(
      "INSERT INTO injection_plans VALUES ('mom', '', 14, '左腹', '', 0)",
    );
    raw.execute(
      "INSERT INTO injection_photos VALUES ('box', 'me', NULL, 'media/plan-me/box.jpg', 'media/plan-me/box_thumb.jpg', 1, 0, 0)",
    );
    raw.execute(
      "INSERT INTO injection_photos VALUES ('shot', 'me', 'i1', 'media/i1/shot.jpg', 'media/i1/shot_thumb.jpg', 1, 0, 0)",
    );
    raw.execute(
      "INSERT INTO injection_photos VALUES ('orphan', 'mom', NULL, 'media/plan-mom/a.jpg', 'media/plan-mom/a_thumb.jpg', 1, 0, 0)",
    );
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final drug = (await db.watchDrugs('me').first).single;
    expect(drug.name, '阿达木', reason: '同名去掉首尾空格后合成一个');
    expect((await db.watchInjectionPlan('me').first)!.drugId, drug.id);
    expect((await db.watchInjectionPlan('mom').first)!.drugId, isNull);

    final drugPhoto = (await db.photoList(drugId: drug.id)).single;
    expect(drugPhoto.id, 'box');
    expect(drugPhoto.path, 'media/plan-me/box.jpg', reason: '文件不搬，路径照旧');
    expect((await db.photoList(injectionId: 'i1')).single.id, 'shot');
    expect(
      await db.watchInjectionPhotos('mom').first,
      isEmpty,
      reason: '计划没填药品时，计划的照片没有归属',
    );
  });

  test('第 1 版备份照样能恢复：数值日期、药品列表、附件名称都按新规则补齐', () async {
    final temp = await Directory.systemTemp.createTemp('ligy_v1_backup');
    addTearDown(() => temp.delete(recursive: true));
    final manifest = {
      'format': 'ligy-medical-backup',
      'version': 1,
      'createdAt': '2026-10-06T10:00:00',
      'profileCount': 1,
      'recordCount': 1,
      'attachmentCount': 2,
      'injectionCount': 1,
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
      'attachments': [
        {
          'id': 'img',
          'recordId': 'r1',
          'kind': 0,
          'path': 'media/r1/img.jpg',
          'thumbnailPath': 'media/r1/img_thumb.jpg',
          'name': '1000034567.jpg',
          'sizeBytes': 1,
          'sortOrder': 0,
          'createdAt': 0,
        },
        {
          'id': 'pdf',
          'recordId': 'r1',
          'kind': 1,
          'path': 'media/r1/pdf.pdf',
          'thumbnailPath': null,
          'name': '体检报告.pdf',
          'sizeBytes': 1,
          'sortOrder': 1,
          'createdAt': 0,
        },
      ],
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
      'injectionPlans': [
        {
          'profileId': 'me',
          'drug': '阿达木',
          'intervalDays': 14,
          'sites': '左腹',
          'note': '',
          'updatedAt': 0,
        },
      ],
      'injections': [
        {
          'id': 'i1',
          'profileId': 'me',
          'date': '2026-09-18',
          'drug': '阿达木',
          'site': '左腹',
          'place': '',
          'note': '',
          'createdAt': 0,
          'updatedAt': 0,
        },
      ],
    };
    final archive = Archive()
      ..add(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
      ..add(ArchiveFile.string('data.json', jsonEncode(data)));
    for (final path in [
      'media/r1/img.jpg',
      'media/r1/img_thumb.jpg',
      'media/r1/pdf.pdf',
    ]) {
      archive.add(ArchiveFile.bytes('files/$path', [1]));
    }
    final file = File('${temp.path}/old.ligymedical')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await BackupService(db, ImageStorage.atRoot(temp.path)).restore(file.path);
    final point = (await db.watchOneSeries('me', 'esr').first)!.points.single;
    expect(point.date, '2026-04-26');
    expect(point.recordId, 'r1');
    final drug = (await db.watchDrugs('me').first).single;
    expect(drug.name, '阿达木');
    expect((await db.watchInjectionPlan('me').first)!.drugId, drug.id);
    expect((await db.watchInjections('me').first).single.drug, '阿达木');
    final attachments = (await db.watchRecord('r1').first)!.attachments;
    expect(attachments.map((a) => a.name), ['', '体检报告.pdf']);
  });
}
