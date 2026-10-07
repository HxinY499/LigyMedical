import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/media/image_storage.dart';

/// 一次注射的表单内容。
class InjectionDraft {
  const InjectionDraft({
    required this.id,
    required this.profileId,
    required this.date,
    required this.drug,
    required this.site,
    required this.place,
    required this.note,
    required this.keptPhotos,
    required this.newPhotoPaths,
  });

  final String id;
  final String profileId;

  /// `yyyy-MM-dd`
  final String date;
  final String drug;
  final String site;
  final String place;
  final String note;

  /// 编辑时保留下来的旧照片（按显示顺序）。
  final List<InjectionPhotoEntry> keptPhotos;

  /// 新选的照片在相册 / 相机缓存里的路径。
  final List<String> newPhotoPaths;
}

/// 一个药品的表单内容。
class DrugDraft {
  const DrugDraft({
    required this.id,
    required this.profileId,
    required this.name,
    required this.keptPhotos,
    required this.newPhotoPaths,
  });

  final String id;
  final String profileId;
  final String name;
  final List<InjectionPhotoEntry> keptPhotos;
  final List<String> newPhotoPaths;
}

/// 注射与药品的保存、删除，连同它们的照片。
///
/// 和记录附件同一个顺序：先把新照片写进最终目录 → 事务写库 → 失败则删掉本次
/// 新写的文件；成功后再删被移除的旧照片文件。
class InjectionService {
  InjectionService(this._db, this._storage);

  final AppDatabase _db;
  final ImageStorage _storage;
  static const _uuid = Uuid();

  Future<void> saveInjection(InjectionDraft draft) {
    return _saveWithPhotos(
      profileId: draft.profileId,
      injectionId: draft.id,
      drugId: null,
      kept: draft.keptPhotos,
      newPaths: draft.newPhotoPaths,
      write: () async {
        await _db.saveInjection(
          id: draft.id,
          profileId: draft.profileId,
          date: draft.date,
          drug: draft.drug,
          site: draft.site,
          place: draft.place,
          note: draft.note,
        );
        return true;
      },
    );
  }

  /// 同一档案里已有同名药品时返回 false，什么都不写。
  Future<bool> saveDrug(DrugDraft draft) {
    return _saveWithPhotos(
      profileId: draft.profileId,
      injectionId: null,
      drugId: draft.id,
      kept: draft.keptPhotos,
      newPaths: draft.newPhotoPaths,
      write: () => _db.saveDrug(
        id: draft.id,
        profileId: draft.profileId,
        name: draft.name,
      ),
    );
  }

  /// 删一针：照片行随外键级联删掉，文件目录单独清。
  Future<void> deleteInjection(String id) async {
    await _db.deleteInjection(id);
    await _storage.deleteOwnerDirectory(id);
  }

  /// 删药品：照片按各自路径删（早期的药品照片不在药品自己的目录下）。
  Future<void> deleteDrug(String id) async {
    final photos = await _db.photoList(drugId: id);
    await _db.deleteDrug(id);
    await _deleteFiles(_photoFiles(photos));
    await _storage.deleteOwnerDirectory(id);
  }

  /// [injectionId] 与 [drugId] 恰有一个非空，是这批照片的归属。
  ///
  /// [write] 返回 false 表示不写（如药品重名），此时整笔回滚并返回 false。
  Future<bool> _saveWithPhotos({
    required String profileId,
    required String? injectionId,
    required String? drugId,
    required List<InjectionPhotoEntry> kept,
    required List<String> newPaths,
    required Future<bool> Function() write,
  }) async {
    final owner = (injectionId ?? drugId)!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final storedPaths = <String>[];
    final newRows = <InjectionPhotosCompanion>[];
    try {
      for (final source in newPaths) {
        final photoId = _uuid.v4();
        final stored = await _storage.storeImage(
          sourcePath: source,
          ownerId: owner,
          fileId: photoId,
        );
        storedPaths
          ..add(stored.imagePath)
          ..add(stored.thumbnailPath);
        newRows.add(
          InjectionPhotosCompanion.insert(
            id: photoId,
            profileId: profileId,
            injectionId: Value(injectionId),
            drugId: Value(drugId),
            path: stored.imagePath,
            thumbnailPath: stored.thumbnailPath,
            sizeBytes: stored.sizeBytes,
            createdAt: now,
          ),
        );
      }
    } on Object {
      await _deleteFiles(storedPaths);
      rethrow;
    }

    final removed = <InjectionPhotoEntry>[];
    try {
      await _db.transaction(() async {
        if (!await write()) throw const _Rejected();
        final photos = _db.injectionPhotos;
        final existing = await _db.photoList(
          injectionId: injectionId,
          drugId: drugId,
        );
        final keptIds = kept.map((photo) => photo.id).toSet();
        removed.addAll(existing.where((photo) => !keptIds.contains(photo.id)));
        if (removed.isNotEmpty) {
          await (_db.delete(photos)..where(
                (row) => row.id.isIn(removed.map((photo) => photo.id).toList()),
              ))
              .go();
        }
        var order = 0;
        for (final photo in kept) {
          await (_db.update(photos)..where((row) => row.id.equals(photo.id)))
              .write(InjectionPhotosCompanion(sortOrder: Value(order++)));
        }
        for (final row in newRows) {
          await _db
              .into(photos)
              .insert(row.copyWith(sortOrder: Value(order++)));
        }
      });
    } on _Rejected {
      await _deleteFiles(storedPaths);
      return false;
    } on Object {
      await _deleteFiles(storedPaths);
      rethrow;
    }

    await _deleteFiles(_photoFiles(removed));
    return true;
  }

  List<String> _photoFiles(List<InjectionPhotoEntry> photos) => [
    for (final photo in photos) ...[photo.path, photo.thumbnailPath],
  ];

  Future<void> _deleteFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        await _storage.deleteFile(path);
      } on Object {
        // 删不掉的残件不影响数据正确性。
      }
    }
  }
}

/// [InjectionService._saveWithPhotos] 里 `write` 拒绝写入时用来回滚事务。
class _Rejected implements Exception {
  const _Rejected();
}
