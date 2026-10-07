import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/core/backup/backup_service.dart';
import 'package:ligy_medical/core/database/app_database.dart';
import 'package:ligy_medical/core/media/image_storage.dart';
import 'package:ligy_medical/features/injections/application/injection_service.dart';
import 'package:ligy_medical/features/records/application/record_service.dart';

import 'support/fake_image_compress.dart';

void main() {
  // 「换机恢复」那条用例刻意同时开两个库。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;

  setUp(() async {
    FakeImageCompress.install();
    temp = await Directory.systemTemp.createTemp('ligy_medical_backup');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  /// 一台「手机」：独立的数据库 + 独立的 support 目录。
  Future<(AppDatabase, ImageStorage, BackupService, RecordService)> device(
    String name,
  ) async {
    final root = Directory('${temp.path}/$name')..createSync();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final storage = ImageStorage.atRoot(root.path);
    return (
      db,
      storage,
      BackupService(db, storage),
      RecordService(db, storage),
    );
  }

  Future<void> seed(
    AppDatabase db,
    ImageStorage storage,
    RecordService service,
  ) async {
    await db.upsertProfile(
      id: 'me',
      name: '我',
      colorIndex: 2,
      injectionEnabled: true,
    );
    await db.addFieldDef(id: 'dept', name: '科室');
    final pdf = File('${temp.path}/report.pdf')
      ..writeAsBytesSync(List.generate(2048, (i) => i % 256));
    await service.save(
      RecordDraft(
        id: 'r1',
        profileId: 'me',
        kind: RecordKind.checkup,
        date: '2026-04-26',
        hospital: '第五医院',
        content: '抽血化验',
        fields: const {'dept': '风湿免疫科'},
        indicators: const [
          IndicatorInput(name: '血沉', value: 1, unit: 'mm/h'),
          IndicatorInput(name: 'C反应蛋白', value: 1.75, unit: 'mg/L'),
        ],
        keptAttachments: const [],
        newAttachments: [
          PendingAttachment(
            kind: AttachmentKind.pdf,
            sourcePath: pdf.path,
            name: '体检报告.pdf',
          ),
        ],
      ),
    );
    final crp = (await db.indicatorList(
      'me',
    )).firstWhere((i) => i.name == 'C反应蛋白');
    await db.updateIndicator(id: crp.id, unit: 'mg/L', refLow: 0, refHigh: 1.7);
    final injections = InjectionService(db, storage);
    final box = File('${temp.path}/box.jpg')
      ..writeAsBytesSync(List.generate(512, (i) => (i * 3) % 256));
    await injections.saveDrug(
      DrugDraft(
        id: 'd1',
        profileId: 'me',
        name: '阿达木单抗',
        keptPhotos: const [],
        newPhotoPaths: [box.path],
      ),
    );
    await db.saveInjectionPlan(
      profileId: 'me',
      drugId: 'd1',
      intervalDays: 14,
      sites: const ['左腹', '右腹'],
      note: '感冒发烧不能打',
    );
    final shot = File('${temp.path}/shot.jpg')
      ..writeAsBytesSync(List.generate(1024, (i) => (i * 7) % 256));
    await injections.saveInjection(
      InjectionDraft(
        id: 'i1',
        profileId: 'me',
        date: '2026-09-18',
        drug: '阿达木单抗',
        site: '左腹',
        place: '自己打',
        note: '',
        keptPhotos: const [],
        newPhotoPaths: [shot.path],
      ),
    );
  }

  String fingerprint(DataSnapshot snapshot) => jsonEncode(snapshot.toJson());

  test('导出后改乱数据，恢复回到备份那一刻（数据与附件、注射照片文件）', () async {
    final (db, storage, backup, service) = await device('phone');
    await seed(db, storage, service);
    final before = await db.exportSnapshot();
    final files = {
      for (final path in before.filePaths)
        path: await (await storage.resolve(path)).readAsBytes(),
    };
    expect(before.drugs.single.name, '阿达木单抗');
    expect(before.injectionPhotos, hasLength(2), reason: '一张药品照片、一张注射照片');

    final file = File('${temp.path}/backup.ligymedical');
    await backup.writeBackupTo(file);

    final preview = await backup.inspect(file.path);
    expect(preview.profileCount, 1);
    expect(preview.recordCount, 1);
    expect(preview.attachmentCount, 1);
    expect(preview.injectionCount, 1);

    // 改乱：删记录（连带删附件文件）、加档案、删注射、删药品。
    await service.delete(before.records.single);
    await db.upsertProfile(
      id: 'mom',
      name: '妈妈',
      colorIndex: 1,
      injectionEnabled: false,
    );
    await InjectionService(db, storage).deleteInjection('i1');
    await InjectionService(db, storage).deleteDrug('d1');
    for (final path in files.keys) {
      expect(await (await storage.resolve(path)).exists(), isFalse);
    }

    await backup.restore(file.path);

    final after = await db.exportSnapshot();
    expect(fingerprint(after), fingerprint(before));
    for (final MapEntry(key: path, value: bytes) in files.entries) {
      expect(await (await storage.resolve(path)).readAsBytes(), bytes);
    }
    final series = await db.watchIndicatorSeries('me').first;
    expect(series.map((s) => s.indicator.name).toSet(), {'血沉', 'C反应蛋白'});
  });

  test('在一台全新的手机上恢复', () async {
    final (db1, storage1, backup1, service1) = await device('old');
    await seed(db1, storage1, service1);
    final file = File('${temp.path}/backup.ligymedical');
    await backup1.writeBackupTo(file);

    final (db2, storage2, backup2, _) = await device('new');
    await backup2.restore(file.path);

    expect(
      fingerprint(await db2.exportSnapshot()),
      fingerprint(await db1.exportSnapshot()),
    );
    final restored = await db2.exportSnapshot();
    for (final path in restored.filePaths) {
      expect(await (await storage2.resolve(path)).exists(), isTrue);
    }
  });

  test('附件文件丢失时拒绝导出', () async {
    final (db, storage, backup, service) = await device('phone');
    await seed(db, storage, service);
    final pdf = (await db.exportSnapshot()).attachments.single;
    await storage.deleteFile(pdf.path);
    expect(
      () => backup.writeBackupTo(File('${temp.path}/b.ligymedical')),
      throwsStateError,
    );
  });

  test('不是备份文件时报格式错误且不动现有数据', () async {
    final (db, storage, backup, service) = await device('phone');
    await seed(db, storage, service);
    final before = fingerprint(await db.exportSnapshot());
    final junk = File('${temp.path}/junk.ligymedical')
      ..writeAsStringSync('hello');
    expect(() => backup.restore(junk.path), throwsFormatException);
    expect(fingerprint(await db.exportSnapshot()), before);
  });

  test('附件路径越界的备份被拒绝', () async {
    final (db, storage, backup, service) = await device('phone');
    await seed(db, storage, service);
    final good = File('${temp.path}/good.ligymedical');
    await backup.writeBackupTo(good);

    final archive = ZipDecoder().decodeBytes(good.readAsBytesSync());
    final data =
        jsonDecode(utf8.decode(archive.findFile('data.json')!.content))
            as Map<String, dynamic>;
    (data['attachments'] as List).first['path'] = '../../evil.pdf';
    final tampered = Archive()
      ..add(archive.findFile('manifest.json')!)
      ..add(ArchiveFile.string('data.json', jsonEncode(data)));
    final bad = File('${temp.path}/bad.ligymedical')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(tampered));

    final before = fingerprint(await db.exportSnapshot());
    expect(() => backup.restore(bad.path), throwsFormatException);
    expect(fingerprint(await db.exportSnapshot()), before);
  });
}
