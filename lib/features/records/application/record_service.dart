import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/media/image_storage.dart';

/// 编辑器里还没落盘的新附件。
class PendingAttachment {
  const PendingAttachment({
    required this.kind,
    required this.sourcePath,
    required this.name,
  });

  final AttachmentKind kind;
  final String sourcePath;

  /// 附件名称，可为空。
  final String name;

  PendingAttachment rename(String name) =>
      PendingAttachment(kind: kind, sourcePath: sourcePath, name: name);
}

/// 编辑器里的一行指标。
class IndicatorInput {
  const IndicatorInput({
    required this.name,
    required this.value,
    required this.unit,
  });

  final String name;
  final double value;
  final String unit;
}

class RecordDraft {
  const RecordDraft({
    required this.id,
    required this.profileId,
    required this.kind,
    required this.date,
    required this.hospital,
    required this.content,
    required this.fields,
    required this.indicators,
    required this.keptAttachments,
    required this.newAttachments,
  });

  /// null 表示新建。
  final String? id;
  final String profileId;
  final RecordKind kind;

  /// `yyyy-MM-dd`
  final String date;
  final String hospital;
  final String content;

  /// fieldId → 值。空值不入库。
  final Map<String, String> fields;
  final List<IndicatorInput> indicators;

  /// 编辑时保留下来的旧附件（按显示顺序，名称以这里为准）。
  final List<AttachmentEntry> keptAttachments;
  final List<PendingAttachment> newAttachments;
}

/// 记录的保存与删除。
///
/// SQLite 事务管不到文件系统，所以顺序固定为：
/// 先把新附件写进最终目录 → 事务写库 → 失败则删掉本次新写的文件；
/// 成功后再删被移除的旧附件文件。
class RecordService {
  RecordService(this._db, this._storage);

  final AppDatabase _db;
  final ImageStorage _storage;
  static const _uuid = Uuid();

  Future<String> save(RecordDraft draft) async {
    final recordId = draft.id ?? _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final storedPaths = <String>[];
    final newRows = <AttachmentsCompanion>[];
    try {
      for (final pending in draft.newAttachments) {
        final attachmentId = _uuid.v4();
        switch (pending.kind) {
          case AttachmentKind.image:
            final stored = await _storage.storeImage(
              sourcePath: pending.sourcePath,
              ownerId: recordId,
              fileId: attachmentId,
            );
            storedPaths
              ..add(stored.imagePath)
              ..add(stored.thumbnailPath);
            newRows.add(
              AttachmentsCompanion.insert(
                id: attachmentId,
                recordId: recordId,
                kind: AttachmentKind.image.index,
                path: stored.imagePath,
                thumbnailPath: Value(stored.thumbnailPath),
                name: Value(pending.name),
                sizeBytes: stored.sizeBytes,
                createdAt: now,
              ),
            );
          case AttachmentKind.pdf:
            final extension = p
                .extension(pending.sourcePath)
                .replaceFirst('.', '')
                .toLowerCase();
            final stored = await _storage.storeFile(
              sourcePath: pending.sourcePath,
              ownerId: recordId,
              fileId: attachmentId,
              extension: extension.isEmpty ? 'pdf' : extension,
            );
            storedPaths.add(stored.path);
            newRows.add(
              AttachmentsCompanion.insert(
                id: attachmentId,
                recordId: recordId,
                kind: AttachmentKind.pdf.index,
                path: stored.path,
                name: Value(pending.name),
                sizeBytes: stored.sizeBytes,
                createdAt: now,
              ),
            );
        }
      }
    } on Object {
      await _deleteFiles(storedPaths);
      rethrow;
    }

    final removed = <AttachmentEntry>[];
    try {
      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.records,
        )..where((row) => row.id.equals(recordId))).getSingleOrNull();
        final companion = RecordsCompanion(
          profileId: Value(draft.profileId),
          kind: Value(draft.kind.index),
          date: Value(draft.date),
          hospital: Value(draft.hospital),
          content: Value(draft.content),
          updatedAt: Value(now),
        );
        if (existing == null) {
          await _db
              .into(_db.records)
              .insert(
                companion.copyWith(id: Value(recordId), createdAt: Value(now)),
              );
        } else {
          await (_db.update(
            _db.records,
          )..where((row) => row.id.equals(recordId))).write(companion);
        }

        await (_db.delete(
          _db.fieldValues,
        )..where((row) => row.recordId.equals(recordId))).go();
        for (final entry in draft.fields.entries) {
          final value = entry.value.trim();
          if (value.isEmpty) continue;
          await _db
              .into(_db.fieldValues)
              .insert(
                FieldValuesCompanion.insert(
                  recordId: recordId,
                  fieldId: entry.key,
                  value: value,
                ),
              );
        }

        await (_db.delete(
          _db.indicatorValues,
        )..where((row) => row.recordId.equals(recordId))).go();
        for (var i = 0; i < draft.indicators.length; i++) {
          final input = draft.indicators[i];
          final indicatorId = await _ensureIndicator(
            draft.profileId,
            input.name,
            input.unit,
            now,
          );
          await _db
              .into(_db.indicatorValues)
              .insert(
                IndicatorValuesCompanion.insert(
                  id: _uuid.v4(),
                  recordId: Value(recordId),
                  indicatorId: indicatorId,
                  value: input.value,
                  date: draft.date,
                  sortOrder: Value(i),
                ),
              );
        }

        final keptIds = draft.keptAttachments.map((a) => a.id).toSet();
        final oldAttachments = await (_db.select(
          _db.attachments,
        )..where((row) => row.recordId.equals(recordId))).get();
        for (final attachment in oldAttachments) {
          if (!keptIds.contains(attachment.id)) removed.add(attachment);
        }
        if (removed.isNotEmpty) {
          await (_db.delete(
                _db.attachments,
              )..where((row) => row.id.isIn(removed.map((a) => a.id).toList())))
              .go();
        }
        var order = 0;
        for (final kept in draft.keptAttachments) {
          await (_db.update(
            _db.attachments,
          )..where((row) => row.id.equals(kept.id))).write(
            AttachmentsCompanion(
              name: Value(kept.name),
              sortOrder: Value(order++),
            ),
          );
        }
        for (final row in newRows) {
          await _db
              .into(_db.attachments)
              .insert(row.copyWith(sortOrder: Value(order++)));
        }
      });
    } on Object {
      await _deleteFiles(storedPaths);
      rethrow;
    }

    await _deleteFiles([
      for (final attachment in removed) ...[
        attachment.path,
        ?attachment.thumbnailPath,
      ],
    ]);
    return recordId;
  }

  Future<void> delete(RecordEntry record) async {
    await (_db.delete(
      _db.records,
    )..where((row) => row.id.equals(record.id))).go();
    await _storage.deleteOwnerDirectory(record.id);
  }

  /// 删除档案：库里级联删光，再清掉每条记录的附件目录和全部注射、药品照片。
  Future<void> deleteProfile(String profileId) async {
    final recordIds =
        await (_db.selectOnly(_db.records)
              ..addColumns([_db.records.id])
              ..where(_db.records.profileId.equals(profileId)))
            .map((row) => row.read(_db.records.id)!)
            .get();
    // 照片按各自路径删：早期的药品照片不在药品自己的目录下。
    final photos = await (_db.select(
      _db.injectionPhotos,
    )..where((row) => row.profileId.equals(profileId))).get();
    await (_db.delete(
      _db.profiles,
    )..where((row) => row.id.equals(profileId))).go();
    for (final id in recordIds) {
      await _storage.deleteOwnerDirectory(id);
    }
    await _deleteFiles([
      for (final photo in photos) ...[photo.path, photo.thumbnailPath],
    ]);
    for (final photo in photos) {
      await _storage.deleteOwnerDirectory((photo.injectionId ?? photo.drugId)!);
    }
  }

  /// 按名称找指标，没有就建；指标还没有单位而这次填了，顺手补上。
  Future<String> _ensureIndicator(
    String profileId,
    String name,
    String unit,
    int now,
  ) async {
    final existing =
        await (_db.select(_db.indicators)..where(
              (row) => row.profileId.equals(profileId) & row.name.equals(name),
            ))
            .getSingleOrNull();
    if (existing != null) {
      if (existing.unit.isEmpty && unit.isNotEmpty) {
        await (_db.update(_db.indicators)
              ..where((row) => row.id.equals(existing.id)))
            .write(IndicatorsCompanion(unit: Value(unit)));
      }
      return existing.id;
    }
    final id = _uuid.v4();
    await _db
        .into(_db.indicators)
        .insert(
          IndicatorsCompanion.insert(
            id: id,
            profileId: profileId,
            name: name,
            unit: Value(unit),
            createdAt: now,
          ),
        );
    return id;
  }

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
