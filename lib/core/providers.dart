import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/injections/application/injection_service.dart';
import '../features/records/application/record_service.dart';
import 'backup/backup_service.dart';
import 'database/app_database.dart';
import 'media/image_storage.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final imageStorageProvider = Provider<ImageStorage>((ref) => ImageStorage());

final recordServiceProvider = Provider<RecordService>((ref) {
  return RecordService(
    ref.watch(databaseProvider),
    ref.watch(imageStorageProvider),
  );
});

final injectionServiceProvider = Provider<InjectionService>((ref) {
  return InjectionService(
    ref.watch(databaseProvider),
    ref.watch(imageStorageProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider),
    ref.watch(imageStorageProvider),
  );
});

// ------------------------------------------------------------------ 订阅
//
// 页面一律通过这些 provider 订阅数据，不在 build 里直接 `db.watchXxx()`：
// 后者每次重建都会新开一条 stream，列表会闪回 loading。

final profilesProvider = StreamProvider<List<ProfileEntry>>(
  (ref) => ref.watch(databaseProvider).watchProfiles(),
);

final profileProvider = StreamProvider.autoDispose
    .family<ProfileEntry?, String>(
      (ref, id) => ref.watch(databaseProvider).watchProfile(id),
    );

final profileSummaryProvider = StreamProvider.autoDispose
    .family<({int count, String? latest}), String>(
      (ref, id) => ref.watch(databaseProvider).watchProfileSummary(id),
    );

final recordsProvider = StreamProvider.autoDispose
    .family<List<RecordBundle>, String>(
      (ref, profileId) => ref.watch(databaseProvider).watchRecords(profileId),
    );

final recordProvider = StreamProvider.autoDispose.family<RecordBundle?, String>(
  (ref, recordId) => ref.watch(databaseProvider).watchRecord(recordId),
);

final fieldDefsProvider = StreamProvider<List<FieldDefEntry>>(
  (ref) => ref.watch(databaseProvider).watchFieldDefs(),
);

final indicatorSeriesProvider = StreamProvider.autoDispose
    .family<List<IndicatorSeries>, String>(
      (ref, profileId) =>
          ref.watch(databaseProvider).watchIndicatorSeries(profileId),
    );

final oneSeriesProvider = StreamProvider.autoDispose
    .family<IndicatorSeries?, ({String profileId, String indicatorId})>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchOneSeries(key.profileId, key.indicatorId),
    );

final injectionPlanProvider = StreamProvider.autoDispose
    .family<InjectionPlanEntry?, String>(
      (ref, profileId) =>
          ref.watch(databaseProvider).watchInjectionPlan(profileId),
    );

final injectionsProvider = StreamProvider.autoDispose
    .family<List<InjectionEntry>, String>(
      (ref, profileId) =>
          ref.watch(databaseProvider).watchInjections(profileId),
    );

final drugsProvider = StreamProvider.autoDispose
    .family<List<DrugEntry>, String>(
      (ref, profileId) => ref.watch(databaseProvider).watchDrugs(profileId),
    );

final injectionPhotosProvider = StreamProvider.autoDispose
    .family<List<InjectionPhotoEntry>, String>(
      (ref, profileId) =>
          ref.watch(databaseProvider).watchInjectionPhotos(profileId),
    );
