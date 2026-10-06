import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// 一个人的健康档案。
@DataClassName('ProfileEntry')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// [kProfileColors] 的下标。
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// 是否在档案里显示「注射」模块。
  BoolColumn get injectionEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 一次就诊或体检。
@DataClassName('RecordEntry')
class Records extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();

  /// [RecordKind] 的下标。
  IntColumn get kind => integer().withDefault(const Constant(0))();

  /// `yyyy-MM-dd` 业务日期。
  TextColumn get date => text()();
  TextColumn get hospital => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AttachmentEntry')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get recordId =>
      text().references(Records, #id, onDelete: KeyAction.cascade)();

  /// [AttachmentKind] 的下标。
  IntColumn get kind => integer()();

  /// 相对 support 目录的路径。
  TextColumn get path => text()();

  /// 只有图片有缩略图。
  TextColumn get thumbnailPath => text().nullable()();

  /// 原始文件名，PDF 列表里显示用。
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get sizeBytes => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 用户自定义的记录字段（所有记录共用，纯文本）。
@DataClassName('FieldDefEntry')
class FieldDefs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FieldValueEntry')
class FieldValues extends Table {
  TextColumn get recordId =>
      text().references(Records, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldId =>
      text().references(FieldDefs, #id, onDelete: KeyAction.cascade)();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {recordId, fieldId};
}

/// 指标字典：同一档案内按名称唯一，趋势图按它归集。
@DataClassName('IndicatorEntry')
class Indicators extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get unit => text().withDefault(const Constant(''))();
  RealColumn get refLow => real().nullable()();
  RealColumn get refHigh => real().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {profileId, name},
  ];
}

@DataClassName('IndicatorValueEntry')
class IndicatorValues extends Table {
  TextColumn get id => text()();
  TextColumn get recordId =>
      text().references(Records, #id, onDelete: KeyAction.cascade)();
  TextColumn get indicatorId =>
      text().references(Indicators, #id, onDelete: KeyAction.cascade)();
  RealColumn get value => real()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 注射计划，每个档案至多一份。
@DataClassName('InjectionPlanEntry')
class InjectionPlans extends Table {
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get drug => text().withDefault(const Constant(''))();
  IntColumn get intervalDays => integer().withDefault(const Constant(14))();

  /// 轮换部位，按轮换顺序以换行分隔。
  TextColumn get sites =>
      text().withDefault(const Constant(kDefaultInjectionSites))();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {profileId};
}

@DataClassName('InjectionEntry')
class Injections extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();

  /// `yyyy-MM-dd` 实际注射日期。
  TextColumn get date => text()();
  TextColumn get drug => text().withDefault(const Constant(''))();
  TextColumn get site => text().withDefault(const Constant(''))();

  /// 地点 / 执行人，自由文本。
  TextColumn get place => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

const kDefaultInjectionSites = '左腹\n右腹\n左臂\n右臂';

enum RecordKind {
  visit('就诊'),
  checkup('体检');

  const RecordKind(this.label);

  final String label;

  static RecordKind of(int index) =>
      index >= 0 && index < values.length ? values[index] : visit;
}

enum AttachmentKind { image, pdf }

extension RecordEntryKind on RecordEntry {
  RecordKind get recordKind => RecordKind.of(kind);
}

extension InjectionPlanSites on InjectionPlanEntry {
  List<String> get siteList => splitSites(sites);
}

List<String> splitSites(String raw) => raw
    .split('\n')
    .map((site) => site.trim())
    .where((site) => site.isNotEmpty)
    .toList();

/// 指标的一个数据点：来自某条记录。
class IndicatorPoint {
  const IndicatorPoint({
    required this.recordId,
    required this.date,
    required this.value,
  });

  final String recordId;

  /// `yyyy-MM-dd`
  final String date;
  final double value;
}

/// 指标 + 它在本档案内的全部数据点（按日期升序）。
class IndicatorSeries {
  const IndicatorSeries({required this.indicator, required this.points});

  final IndicatorEntry indicator;
  final List<IndicatorPoint> points;
}

/// 记录里的一行指标（带指标字典信息）。
class RecordIndicator {
  const RecordIndicator({required this.indicator, required this.value});

  final IndicatorEntry indicator;
  final IndicatorValueEntry value;
}

/// 列表和详情页用的完整记录。
class RecordBundle {
  const RecordBundle({
    required this.record,
    required this.attachments,
    required this.indicators,
    required this.fields,
  });

  final RecordEntry record;
  final List<AttachmentEntry> attachments;
  final List<RecordIndicator> indicators;

  /// fieldId → 值，只含非空值。
  final Map<String, String> fields;
}

/// 全部数据的一份快照，备份导出 / 恢复用。
class DataSnapshot {
  const DataSnapshot({
    required this.profiles,
    required this.records,
    required this.attachments,
    required this.fieldDefs,
    required this.fieldValues,
    required this.indicators,
    required this.indicatorValues,
    required this.injectionPlans,
    required this.injections,
  });

  final List<ProfileEntry> profiles;
  final List<RecordEntry> records;
  final List<AttachmentEntry> attachments;
  final List<FieldDefEntry> fieldDefs;
  final List<FieldValueEntry> fieldValues;
  final List<IndicatorEntry> indicators;
  final List<IndicatorValueEntry> indicatorValues;
  final List<InjectionPlanEntry> injectionPlans;
  final List<InjectionEntry> injections;

  /// 附件在 support 目录下的全部相对路径（含缩略图）。
  List<String> get filePaths => [
    for (final attachment in attachments) ...[
      attachment.path,
      ?attachment.thumbnailPath,
    ],
  ];

  Map<String, Object> toJson() => {
    'profiles': [for (final row in profiles) row.toJson()],
    'records': [for (final row in records) row.toJson()],
    'attachments': [for (final row in attachments) row.toJson()],
    'fieldDefs': [for (final row in fieldDefs) row.toJson()],
    'fieldValues': [for (final row in fieldValues) row.toJson()],
    'indicators': [for (final row in indicators) row.toJson()],
    'indicatorValues': [for (final row in indicatorValues) row.toJson()],
    'injectionPlans': [for (final row in injectionPlans) row.toJson()],
    'injections': [for (final row in injections) row.toJson()],
  };

  factory DataSnapshot.fromJson(Map<String, Object?> json) {
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) {
      final list = json[key];
      if (list is! List) throw FormatException('备份缺少 $key');
      return [
        for (final item in list) parse((item as Map).cast<String, dynamic>()),
      ];
    }

    return DataSnapshot(
      profiles: rows('profiles', ProfileEntry.fromJson),
      records: rows('records', RecordEntry.fromJson),
      attachments: rows('attachments', AttachmentEntry.fromJson),
      fieldDefs: rows('fieldDefs', FieldDefEntry.fromJson),
      fieldValues: rows('fieldValues', FieldValueEntry.fromJson),
      indicators: rows('indicators', IndicatorEntry.fromJson),
      indicatorValues: rows('indicatorValues', IndicatorValueEntry.fromJson),
      injectionPlans: rows('injectionPlans', InjectionPlanEntry.fromJson),
      injections: rows('injections', InjectionEntry.fromJson),
    );
  }
}

@DriftDatabase(
  tables: [
    Profiles,
    Records,
    Attachments,
    FieldDefs,
    FieldValues,
    Indicators,
    IndicatorValues,
    InjectionPlans,
    Injections,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'ligy_medical'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'CREATE INDEX idx_records_profile_date ON records(profile_id, date)',
      );
      await customStatement(
        'CREATE INDEX idx_injections_profile_date '
        'ON injections(profile_id, date)',
      );
      await customStatement(
        'CREATE INDEX idx_indicator_values_indicator '
        'ON indicator_values(indicator_id)',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 先发一次当前值，之后 [tables] 任一变动就重新加载。
  ///
  /// 列表要的数据跨好几张表（记录 + 附件 + 指标），单表 `watch()` 只盯得住
  /// 其中一张，附件或指标单独变化时界面不会刷新。
  Stream<T> _watch<T>(
    Set<ResultSetImplementation> tables,
    Future<T> Function() load,
  ) async* {
    yield await load();
    await for (final _ in tableUpdates(TableUpdateQuery.onAllTables(tables))) {
      yield await load();
    }
  }

  // ------------------------------------------------------------------ 档案

  Stream<List<ProfileEntry>> watchProfiles() {
    final query = select(profiles)
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch();
  }

  Stream<ProfileEntry?> watchProfile(String id) {
    return (select(
      profiles,
    )..where((row) => row.id.equals(id))).watchSingleOrNull();
  }

  Future<void> upsertProfile({
    required String id,
    required String name,
    required int colorIndex,
    required bool injectionEnabled,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (select(
      profiles,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      final maxSort = profiles.sortOrder.max();
      final result = await (selectOnly(
        profiles,
      )..addColumns([maxSort])).getSingle();
      await into(profiles).insert(
        ProfilesCompanion.insert(
          id: id,
          name: name,
          colorIndex: Value(colorIndex),
          injectionEnabled: Value(injectionEnabled),
          sortOrder: Value((result.read(maxSort) ?? -1) + 1),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await (update(profiles)..where((row) => row.id.equals(id))).write(
        ProfilesCompanion(
          name: Value(name),
          colorIndex: Value(colorIndex),
          injectionEnabled: Value(injectionEnabled),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// 档案卡片上的概要：记录条数、最近一次记录日期。
  Stream<({int count, String? latest})> watchProfileSummary(String id) {
    final count = records.id.count();
    final latest = records.date.max();
    final query = selectOnly(records)
      ..addColumns([count, latest])
      ..where(records.profileId.equals(id));
    return query.watchSingle().map(
      (row) => (count: row.read(count) ?? 0, latest: row.read(latest)),
    );
  }

  // ------------------------------------------------------------------ 记录

  Future<RecordBundle?> _loadBundle(String recordId) async {
    final record = await (select(
      records,
    )..where((row) => row.id.equals(recordId))).getSingleOrNull();
    if (record == null) return null;
    final bundles = await _bundlesFor([record]);
    return bundles.single;
  }

  Future<List<RecordBundle>> _bundlesFor(List<RecordEntry> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toList();
    final attachmentRows =
        await (select(attachments)
              ..where((row) => row.recordId.isIn(ids))
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    final indicatorRows =
        await (select(indicatorValues).join([
                innerJoin(
                  indicators,
                  indicators.id.equalsExp(indicatorValues.indicatorId),
                ),
              ])
              ..where(indicatorValues.recordId.isIn(ids))
              ..orderBy([OrderingTerm.asc(indicatorValues.sortOrder)]))
            .get();
    final fieldRows = await (select(
      fieldValues,
    )..where((row) => row.recordId.isIn(ids))).get();

    final attachmentsByRecord = <String, List<AttachmentEntry>>{};
    for (final row in attachmentRows) {
      attachmentsByRecord.putIfAbsent(row.recordId, () => []).add(row);
    }
    final indicatorsByRecord = <String, List<RecordIndicator>>{};
    for (final row in indicatorRows) {
      final value = row.readTable(indicatorValues);
      indicatorsByRecord
          .putIfAbsent(value.recordId, () => [])
          .add(
            RecordIndicator(indicator: row.readTable(indicators), value: value),
          );
    }
    final fieldsByRecord = <String, Map<String, String>>{};
    for (final row in fieldRows) {
      fieldsByRecord.putIfAbsent(row.recordId, () => {})[row.fieldId] =
          row.value;
    }
    return [
      for (final row in rows)
        RecordBundle(
          record: row,
          attachments: attachmentsByRecord[row.id] ?? const [],
          indicators: indicatorsByRecord[row.id] ?? const [],
          fields: fieldsByRecord[row.id] ?? const {},
        ),
    ];
  }

  Set<ResultSetImplementation> get _recordTables => {
    records,
    attachments,
    indicatorValues,
    indicators,
    fieldValues,
  };

  /// 档案下的全部记录，日期倒序。
  Stream<List<RecordBundle>> watchRecords(String profileId) {
    return _watch(_recordTables, () async {
      final rows =
          await (select(records)
                ..where((row) => row.profileId.equals(profileId))
                ..orderBy([
                  (row) => OrderingTerm.desc(row.date),
                  (row) => OrderingTerm.desc(row.createdAt),
                ]))
              .get();
      return _bundlesFor(rows);
    });
  }

  Stream<RecordBundle?> watchRecord(String recordId) {
    return _watch(_recordTables, () => _loadBundle(recordId));
  }

  // ------------------------------------------------------------------ 自定义字段

  Stream<List<FieldDefEntry>> watchFieldDefs() {
    final query = select(fieldDefs)
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch();
  }

  Future<List<FieldDefEntry>> fieldDefList() {
    final query = select(fieldDefs)
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.get();
  }

  Future<void> addFieldDef({required String id, required String name}) async {
    final maxSort = fieldDefs.sortOrder.max();
    final result = await (selectOnly(
      fieldDefs,
    )..addColumns([maxSort])).getSingle();
    await into(fieldDefs).insert(
      FieldDefsCompanion.insert(
        id: id,
        name: name,
        sortOrder: Value((result.read(maxSort) ?? -1) + 1),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> renameFieldDef(String id, String name) {
    return (update(fieldDefs)..where((row) => row.id.equals(id))).write(
      FieldDefsCompanion(name: Value(name)),
    );
  }

  /// 删除字段会连带删掉所有记录里这一项的值（外键级联）。
  Future<void> deleteFieldDef(String id) {
    return (delete(fieldDefs)..where((row) => row.id.equals(id))).go();
  }

  Future<void> reorderFieldDefs(List<String> ids) async {
    await transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (update(fieldDefs)..where((row) => row.id.equals(ids[i]))).write(
          FieldDefsCompanion(sortOrder: Value(i)),
        );
      }
    });
  }

  // ------------------------------------------------------------------ 指标

  Future<List<IndicatorEntry>> indicatorList(String profileId) {
    final query = select(indicators)
      ..where((row) => row.profileId.equals(profileId))
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.get();
  }

  Future<List<IndicatorSeries>> _loadSeries(
    String profileId, {
    String? indicatorId,
  }) async {
    final query =
        select(indicatorValues).join([
            innerJoin(
              indicators,
              indicators.id.equalsExp(indicatorValues.indicatorId),
            ),
            innerJoin(records, records.id.equalsExp(indicatorValues.recordId)),
          ])
          ..where(indicators.profileId.equals(profileId))
          ..orderBy([
            OrderingTerm.asc(records.date),
            OrderingTerm.asc(records.createdAt),
          ]);
    if (indicatorId != null) {
      query.where(indicators.id.equals(indicatorId));
    }
    final rows = await query.get();
    final byIndicator = <String, (IndicatorEntry, List<IndicatorPoint>)>{};
    for (final row in rows) {
      final indicator = row.readTable(indicators);
      final value = row.readTable(indicatorValues);
      final record = row.readTable(records);
      byIndicator
          .putIfAbsent(indicator.id, () => (indicator, []))
          .$2
          .add(
            IndicatorPoint(
              recordId: record.id,
              date: record.date,
              value: value.value,
            ),
          );
    }
    final series = [
      for (final entry in byIndicator.values)
        IndicatorSeries(indicator: entry.$1, points: entry.$2),
    ];
    // 最近测过的排前面：常看的指标总是最近查过的那几项。
    series.sort((a, b) => b.points.last.date.compareTo(a.points.last.date));
    return series;
  }

  Set<ResultSetImplementation> get _seriesTables => {
    indicators,
    indicatorValues,
    records,
  };

  Stream<List<IndicatorSeries>> watchIndicatorSeries(String profileId) {
    return _watch(_seriesTables, () => _loadSeries(profileId));
  }

  Stream<IndicatorSeries?> watchOneSeries(
    String profileId,
    String indicatorId,
  ) {
    return _watch(_seriesTables, () async {
      final series = await _loadSeries(profileId, indicatorId: indicatorId);
      return series.isEmpty ? null : series.single;
    });
  }

  Future<void> updateIndicator({
    required String id,
    required String unit,
    required double? refLow,
    required double? refHigh,
  }) {
    return (update(indicators)..where((row) => row.id.equals(id))).write(
      IndicatorsCompanion(
        unit: Value(unit),
        refLow: Value(refLow),
        refHigh: Value(refHigh),
      ),
    );
  }

  /// 改名。新名字在同一档案里已存在时，把数据并入那个指标并删掉自己。
  ///
  /// 返回最终承载数据的指标 id（合并时是目标指标的 id）。
  Future<String> renameIndicator(String id, String name) {
    return transaction(() async {
      final source = await (select(
        indicators,
      )..where((row) => row.id.equals(id))).getSingle();
      if (source.name == name) return id;
      final target =
          await (select(indicators)..where(
                (row) =>
                    row.profileId.equals(source.profileId) &
                    row.name.equals(name),
              ))
              .getSingleOrNull();
      if (target == null) {
        await (update(indicators)..where((row) => row.id.equals(id))).write(
          IndicatorsCompanion(name: Value(name)),
        );
        return id;
      }
      await (update(indicatorValues)
            ..where((row) => row.indicatorId.equals(id)))
          .write(IndicatorValuesCompanion(indicatorId: Value(target.id)));
      await (delete(indicators)..where((row) => row.id.equals(id))).go();
      return target.id;
    });
  }

  /// 删掉没有任何数据点的指标。录错的名字不该一直留在自动补全里。
  Future<void> pruneIndicators(String profileId) {
    return customStatement(
      'DELETE FROM indicators WHERE profile_id = ? AND id NOT IN '
      '(SELECT DISTINCT indicator_id FROM indicator_values)',
      [profileId],
    );
  }

  // ------------------------------------------------------------------ 注射

  Stream<InjectionPlanEntry?> watchInjectionPlan(String profileId) {
    return (select(
      injectionPlans,
    )..where((row) => row.profileId.equals(profileId))).watchSingleOrNull();
  }

  Future<void> saveInjectionPlan({
    required String profileId,
    required String drug,
    required int intervalDays,
    required List<String> sites,
    required String note,
  }) {
    return into(injectionPlans).insertOnConflictUpdate(
      InjectionPlansCompanion.insert(
        profileId: profileId,
        drug: Value(drug),
        intervalDays: Value(intervalDays),
        sites: Value(sites.join('\n')),
        note: Value(note),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 注射记录，日期倒序。
  Stream<List<InjectionEntry>> watchInjections(String profileId) {
    final query = select(injections)
      ..where((row) => row.profileId.equals(profileId))
      ..orderBy([
        (row) => OrderingTerm.desc(row.date),
        (row) => OrderingTerm.desc(row.createdAt),
      ]);
    return query.watch();
  }

  Future<void> saveInjection({
    required String id,
    required String profileId,
    required String date,
    required String drug,
    required String site,
    required String place,
    required String note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (select(
      injections,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      await into(injections).insert(
        InjectionsCompanion.insert(
          id: id,
          profileId: profileId,
          date: date,
          drug: Value(drug),
          site: Value(site),
          place: Value(place),
          note: Value(note),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await (update(injections)..where((row) => row.id.equals(id))).write(
        InjectionsCompanion(
          date: Value(date),
          drug: Value(drug),
          site: Value(site),
          place: Value(place),
          note: Value(note),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> deleteInjection(String id) {
    return (delete(injections)..where((row) => row.id.equals(id))).go();
  }

  // ------------------------------------------------------------------ 备份

  /// 全库快照。在一个事务里读，保证各表之间一致。
  Future<DataSnapshot> exportSnapshot() {
    return transaction(
      () async => DataSnapshot(
        profiles: await select(profiles).get(),
        records: await select(records).get(),
        attachments: await select(attachments).get(),
        fieldDefs: await select(fieldDefs).get(),
        fieldValues: await select(fieldValues).get(),
        indicators: await select(indicators).get(),
        indicatorValues: await select(indicatorValues).get(),
        injectionPlans: await select(injectionPlans).get(),
        injections: await select(injections).get(),
      ),
    );
  }

  /// 用快照整体替换全部数据。插入顺序按外键依赖：父表在前。
  Future<void> replaceAllData(DataSnapshot data) {
    return transaction(() async {
      // 删档案会级联删掉记录、指标、注射；字段定义独立，单独删。
      await delete(profiles).go();
      await delete(fieldDefs).go();
      await batch((batch) {
        batch.insertAll(profiles, data.profiles);
        batch.insertAll(fieldDefs, data.fieldDefs);
        batch.insertAll(records, data.records);
        batch.insertAll(attachments, data.attachments);
        batch.insertAll(fieldValues, data.fieldValues);
        batch.insertAll(indicators, data.indicators);
        batch.insertAll(indicatorValues, data.indicatorValues);
        batch.insertAll(injectionPlans, data.injectionPlans);
        batch.insertAll(injections, data.injections);
      });
    });
  }

  /// 最近用过的地点 / 执行人，去重，最近的在前。
  Future<List<String>> recentInjectionPlaces(String profileId) async {
    final rows = await customSelect(
      'SELECT place, MAX(date) AS last FROM injections '
      "WHERE profile_id = ? AND place != '' "
      'GROUP BY place ORDER BY last DESC LIMIT 6',
      variables: [Variable.withString(profileId)],
      readsFrom: {injections},
    ).get();
    return [for (final row in rows) row.read<String>('place')];
  }
}
