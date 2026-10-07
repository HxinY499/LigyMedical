import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../media/image_storage.dart';

/// 完整备份：全部数据 + 全部附件文件，打成一个 zip。
///
/// 包结构：
/// ```text
/// manifest.json   格式、版本、各类条数
/// data.json       全库快照（见 [DataSnapshot]）
/// files/media/... 附件、注射照片的原文件与缩略图，路径与 support 目录下一致
/// ```
///
/// 恢复是**整体覆盖**，不做合并：两份数据里同一次就诊可能各改过一遍，
/// 合并规则说不清，宁可让用户明确知道「恢复 = 回到备份那一刻」。
class BackupService {
  BackupService(this.database, this.imageStorage);

  final AppDatabase database;
  final ImageStorage imageStorage;

  /// - v1 → v2：指标数值可以不属于记录，多了自己的 `date`。v1 的包照样能恢复，
  ///   缺的日期按所属记录补（见 `DataSnapshot.fromJson`）。
  /// - v2 → v3：多了注射照片 `injectionPhotos`。老包没有这一项，按空恢复；
  ///   老版本应用拒收 v3，免得恢复时把照片悄悄丢掉。
  /// - v3 → v4：多了药品列表 `drugs`，计划改存 `drugId`。老包按计划和注射记录里的
  ///   药品名生成药品列表（见 `DataSnapshot.fromJson`）。
  /// - v4 → v5：附件名称由用户起。老包里图片的名称是相册文件名，恢复时清空。
  static const formatVersion = 5;
  static const _supportedVersions = {1, 2, 3, 4, formatVersion};
  static const _format = 'ligy-medical-backup';
  static const fileExtension = 'ligymedical';

  Future<void> exportAndShare() async {
    final cache = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final file = File(p.join(cache.path, '健康档案备份-$stamp.$fileExtension'));
    await writeBackupTo(file);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: '健康档案备份',
      ),
    );
  }

  /// 把完整备份写成 zip 文件。从 [exportAndShare] 拆出来是为了可测。
  Future<void> writeBackupTo(File target) async {
    final snapshot = await database.exportSnapshot();
    final manifest = <String, Object>{
      'format': _format,
      'version': formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'profileCount': snapshot.profiles.length,
      'recordCount': snapshot.records.length,
      'attachmentCount': snapshot.attachments.length,
      'injectionCount': snapshot.injections.length,
    };

    // 缺文件直接失败：备份的承诺是「一字不差」，悄悄少打一份报告，
    // 用户要到换机恢复那天才会发现。
    final files = <({String path, Uint8List bytes})>[];
    for (final relativePath in snapshot.filePaths) {
      final file = await imageStorage.resolve(relativePath);
      if (!await file.exists()) {
        throw StateError('附件文件丢失：$relativePath');
      }
      files.add((
        path: _archivePath(relativePath),
        bytes: await file.readAsBytes(),
      ));
    }

    // zip 压缩是纯 CPU，附件多时在主 isolate 上会卡住界面。
    final manifestJson = jsonEncode(manifest);
    final dataJson = jsonEncode(snapshot.toJson());
    final encoded = await Isolate.run(
      () => zipBackupBytes(
        manifestJson: manifestJson,
        dataJson: dataJson,
        files: files,
      ),
    );
    await target.writeAsBytes(encoded, flush: true);
  }

  /// zip 内路径统一用 `/`。
  String _archivePath(String relativePath) =>
      'files/${relativePath.replaceAll('\\', '/')}';

  Future<String?> pickBackupFile() async {
    const typeGroup = XTypeGroup(
      label: '健康档案备份',
      mimeTypes: ['application/zip', 'application/octet-stream'],
      extensions: [fileExtension, 'zip'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    return file?.path;
  }

  Future<BackupPreview> inspect(String filePath) async {
    final archive = await _decode(filePath);
    final manifest = _jsonFile(archive, 'manifest.json');
    _validateManifest(manifest);
    return BackupPreview(
      createdAt: DateTime.parse(manifest['createdAt'] as String),
      profileCount: manifest['profileCount'] as int,
      recordCount: manifest['recordCount'] as int,
      attachmentCount: manifest['attachmentCount'] as int,
      injectionCount: manifest['injectionCount'] as int,
    );
  }

  /// 用备份整体覆盖当前数据。
  ///
  /// SQLite 事务管不到文件系统，所以顺序是：附件先解到暂存目录 → 事务替换
  /// 数据库 → 整体换 media 目录；换目录失败就把旧目录和旧数据都换回去。
  Future<void> restore(String filePath) async {
    final archive = await _decode(filePath);
    final manifest = _jsonFile(archive, 'manifest.json');
    _validateManifest(manifest);
    final snapshot = DataSnapshot.fromJson(
      _jsonFile(archive, 'data.json'),
      version: manifest['version'] as int,
    );
    if (snapshot.profiles.length != manifest['profileCount'] ||
        snapshot.records.length != manifest['recordCount'] ||
        snapshot.attachments.length != manifest['attachmentCount'] ||
        snapshot.injections.length != manifest['injectionCount']) {
      throw const FormatException('备份数据条数不一致，文件可能已损坏');
    }

    final support = await imageStorage.supportRoot();
    final stage = Directory(
      p.join(support, '.restore_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await stage.create(recursive: true);
    try {
      for (final relativePath in snapshot.filePaths) {
        await _extractTo(stage, archive, relativePath);
      }

      final previous = await database.exportSnapshot();
      await database.replaceAllData(snapshot);
      final currentMedia = Directory(p.join(support, kMediaDirName));
      final oldMedia = Directory(p.join(support, '.media_before_restore'));
      try {
        if (await oldMedia.exists()) await oldMedia.delete(recursive: true);
        if (await currentMedia.exists()) {
          await currentMedia.rename(oldMedia.path);
        }
        final stagedMedia = Directory(p.join(stage.path, kMediaDirName));
        if (await stagedMedia.exists()) {
          await stagedMedia.rename(currentMedia.path);
        }
      } catch (_) {
        if (await currentMedia.exists()) {
          await currentMedia.delete(recursive: true);
        }
        if (await oldMedia.exists()) await oldMedia.rename(currentMedia.path);
        await database.replaceAllData(previous);
        rethrow;
      }
      if (await oldMedia.exists()) await oldMedia.delete(recursive: true);
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<void> _extractTo(
    Directory stage,
    Archive archive,
    String relativePath,
  ) async {
    final normalized = p.normalize(relativePath);
    // 备份文件是外部输入：不校验就等于允许它往 support 目录外面写。
    if (p.isAbsolute(normalized) ||
        normalized.startsWith('..') ||
        !p.isWithin(kMediaDirName, normalized)) {
      throw const FormatException('备份包含非法附件路径');
    }
    final entry = archive.findFile(_archivePath(relativePath));
    if (entry == null || !entry.isFile) {
      throw FormatException('备份缺少附件：$relativePath');
    }
    final output = File(p.join(stage.path, normalized));
    await output.parent.create(recursive: true);
    await output.writeAsBytes(entry.content, flush: true);
  }

  Future<Archive> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    try {
      return ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw const FormatException('不是有效的备份文件');
    }
  }

  Map<String, Object?> _jsonFile(Archive archive, String name) {
    final file = archive.findFile(name);
    if (file == null || !file.isFile) {
      throw const FormatException('不是有效的备份文件');
    }
    final decoded = jsonDecode(utf8.decode(file.content));
    if (decoded is! Map) throw FormatException('$name 格式错误');
    return decoded.cast<String, Object?>();
  }

  void _validateManifest(Map<String, Object?> manifest) {
    if (manifest['format'] != _format) {
      throw const FormatException('不是健康档案的备份文件');
    }
    if (!_supportedVersions.contains(manifest['version'])) {
      throw const FormatException('备份来自更新版本的应用，请先升级');
    }
  }
}

class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.profileCount,
    required this.recordCount,
    required this.attachmentCount,
    required this.injectionCount,
  });

  final DateTime createdAt;
  final int profileCount;
  final int recordCount;
  final int attachmentCount;
  final int injectionCount;
}

/// 在后台 isolate 里把 JSON 和文件打成 zip。只收可发送的字符串和字节。
Uint8List zipBackupBytes({
  required String manifestJson,
  required String dataJson,
  required List<({String path, Uint8List bytes})> files,
}) {
  final archive = Archive();
  archive.add(ArchiveFile.string('manifest.json', manifestJson));
  archive.add(ArchiveFile.string('data.json', dataJson));
  for (final file in files) {
    archive.add(ArchiveFile.bytes(file.path, file.bytes));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
