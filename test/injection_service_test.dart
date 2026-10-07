import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/core/database/app_database.dart';
import 'package:ligy_medical/core/media/image_storage.dart';
import 'package:ligy_medical/features/injections/application/injection_service.dart';
import 'package:ligy_medical/features/records/application/record_service.dart';

import 'support/fake_image_compress.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late ImageStorage storage;
  late InjectionService service;

  setUp(() async {
    FakeImageCompress.install();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('ligy_medical_injection');
    storage = ImageStorage.atRoot(root.path);
    service = InjectionService(db, storage);
    await db.upsertProfile(
      id: 'me',
      name: '我',
      colorIndex: 0,
      injectionEnabled: true,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  String photo(String name) =>
      (File('${root.path}/$name')..writeAsBytesSync([1, 2, 3])).path;

  InjectionDraft injection({
    List<InjectionPhotoEntry> kept = const [],
    List<String> added = const [],
  }) => InjectionDraft(
    id: 'i1',
    profileId: 'me',
    date: '2026-10-05',
    drug: '阿达木',
    site: '左腹',
    place: '',
    note: '',
    keptPhotos: kept,
    newPhotoPaths: added,
  );

  DrugDraft drug(
    String id,
    String name, {
    List<InjectionPhotoEntry> kept = const [],
    List<String> added = const [],
  }) => DrugDraft(
    id: id,
    profileId: 'me',
    name: name,
    keptPhotos: kept,
    newPhotoPaths: added,
  );

  Future<bool> exists(String relativePath) =>
      File('${root.path}/$relativePath').exists();

  test('一针的照片随保存落盘，移除的照片连文件一起删，删这一针清掉整个目录', () async {
    await service.saveInjection(
      injection(added: [photo('a.jpg'), photo('b.jpg')]),
    );
    var photos = await db.photoList(injectionId: 'i1');
    expect(photos, hasLength(2));
    for (final p in photos) {
      expect(await exists(p.path), isTrue);
      expect(await exists(p.thumbnailPath), isTrue);
    }

    final [first, second] = photos;
    await service.saveInjection(
      injection(kept: [second], added: [photo('c.jpg')]),
    );
    photos = await db.photoList(injectionId: 'i1');
    expect(photos.first.id, second.id, reason: '保留的照片排在新加的前面');
    expect(photos, hasLength(2));
    expect(await exists(first.path), isFalse);
    expect(await exists(first.thumbnailPath), isFalse);

    await service.deleteInjection('i1');
    expect(await db.photoList(injectionId: 'i1'), isEmpty);
    expect(await Directory('${root.path}/$kMediaDirName/i1').exists(), isFalse);
  });

  test('药品重名时不写，也不留下新照片的文件', () async {
    expect(await service.saveDrug(drug('d1', '阿达木')), isTrue);
    expect(
      await service.saveDrug(drug('d2', '阿达木', added: [photo('x.jpg')])),
      isFalse,
    );
    expect((await db.watchDrugs('me').first).map((d) => d.id), ['d1']);
    final rejected = Directory('${root.path}/$kMediaDirName/d2');
    expect(!rejected.existsSync() || rejected.listSync().isEmpty, isTrue);

    // 改名为自己原来的名字、或改成没人用的名字都可以。
    expect(await service.saveDrug(drug('d1', '阿达木')), isTrue);
    expect(await service.saveDrug(drug('d1', '修美乐')), isTrue);
    expect((await db.watchDrugs('me').first).single.name, '修美乐');
  });

  test('删除计划正在用的药品：计划变成未选药品，照片删掉，打过的记录不动', () async {
    await service.saveDrug(drug('d1', '阿达木', added: [photo('box.jpg')]));
    final box = (await db.photoList(drugId: 'd1')).single;
    await db.saveInjectionPlan(
      profileId: 'me',
      drugId: 'd1',
      intervalDays: 14,
      sites: const ['左腹'],
      note: '',
    );
    await service.saveInjection(injection(added: [photo('shot.jpg')]));

    await service.deleteDrug('d1');
    expect(await db.watchDrugs('me').first, isEmpty);
    expect((await db.watchInjectionPlan('me').first)!.drugId, isNull);
    expect(await db.photoList(drugId: 'd1'), isEmpty);
    expect(await exists(box.path), isFalse);
    expect((await db.watchInjections('me').first).single.drug, '阿达木');
    expect(await db.photoList(injectionId: 'i1'), hasLength(1));
  });

  test('删除档案时注射照片和药品照片的文件一起清掉', () async {
    await service.saveInjection(injection(added: [photo('shot.jpg')]));
    await service.saveDrug(drug('d1', '阿达木', added: [photo('box.jpg')]));

    await RecordService(db, storage).deleteProfile('me');
    expect(await db.watchInjectionPhotos('me').first, isEmpty);
    expect(await db.watchDrugs('me').first, isEmpty);
    final media = Directory('${root.path}/$kMediaDirName');
    expect(await media.list().toList(), isEmpty);
  });
}
