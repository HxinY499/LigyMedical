import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

/// 一个人的健康档案。
@DataClassName('ProfileEntry')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// [kProfileAccents] 的下标：档案标识色，也是进入该档案后的主题色。
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

  /// 附件名称，用户可改。PDF 默认是原始文件名，图片默认为空（不显示名称）。
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
/// 指标的一次数值。可以来自某条记录（[recordId] 非空），也可以在指标页单独添加。
class IndicatorValues extends Table {
  TextColumn get id => text()();

  /// 来自哪条记录；单独添加的数值为 null。删记录时连带删掉它带来的数值。
  TextColumn get recordId =>
      text().nullable().references(Records, #id, onDelete: KeyAction.cascade)();
  TextColumn get indicatorId =>
      text().references(Indicators, #id, onDelete: KeyAction.cascade)();
  RealColumn get value => real()();

  /// `yyyy-MM-dd`。来自记录的数值随记录日期同步（记录每次保存都会重写它的数值）。
  TextColumn get date => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 档案里维护的药品。注射计划从这里选，记录注射时作为选项。同一档案内按名称唯一。
@DataClassName('DrugEntry')
class Drugs extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {profileId, name},
  ];
}

/// 注射计划，每个档案至多一份。
@DataClassName('InjectionPlanEntry')
class InjectionPlans extends Table {
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();

  /// 计划用的药品；删掉那个药品后变为 null。
  TextColumn get drugId =>
      text().nullable().references(Drugs, #id, onDelete: KeyAction.setNull)();
  IntColumn get intervalDays => integer().withDefault(const Constant(14))();

  /// 常用部位，按显示顺序以换行分隔。记录注射时作为快捷选项。
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

  /// 当时打的药品名。存名字而不是药品 id：药品改名、删除都不改写已打过的记录。
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

/// 注射相关的照片：某一针的照片（[injectionId]）或某个药品的照片（[drugId]），
/// 两者恰有一个非空。
@DataClassName('InjectionPhotoEntry')
class InjectionPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get injectionId => text().nullable().references(
    Injections,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get drugId =>
      text().nullable().references(Drugs, #id, onDelete: KeyAction.cascade)();

  /// 相对 support 目录的路径。
  TextColumn get path => text()();
  TextColumn get thumbnailPath => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

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
    required this.valueId,
    required this.recordId,
    required this.date,
    required this.value,
  });

  final String valueId;

  /// 来自哪条记录；单独添加的为 null。
  final String? recordId;

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
    required this.drugs,
    required this.injectionPlans,
    required this.injections,
    required this.injectionPhotos,
  });

  final List<ProfileEntry> profiles;
  final List<RecordEntry> records;
  final List<AttachmentEntry> attachments;
  final List<FieldDefEntry> fieldDefs;
  final List<FieldValueEntry> fieldValues;
  final List<IndicatorEntry> indicators;
  final List<IndicatorValueEntry> indicatorValues;
  final List<DrugEntry> drugs;
  final List<InjectionPlanEntry> injectionPlans;
  final List<InjectionEntry> injections;
  final List<InjectionPhotoEntry> injectionPhotos;

  /// 附件与注射照片在 support 目录下的全部相对路径（含缩略图）。
  List<String> get filePaths => [
    for (final attachment in attachments) ...[
      attachment.path,
      ?attachment.thumbnailPath,
    ],
    for (final photo in injectionPhotos) ...[photo.path, photo.thumbnailPath],
  ];

  Map<String, Object> toJson() => {
    'profiles': [for (final row in profiles) row.toJson()],
    'records': [for (final row in records) row.toJson()],
    'attachments': [for (final row in attachments) row.toJson()],
    'fieldDefs': [for (final row in fieldDefs) row.toJson()],
    'fieldValues': [for (final row in fieldValues) row.toJson()],
    'indicators': [for (final row in indicators) row.toJson()],
    'indicatorValues': [for (final row in indicatorValues) row.toJson()],
    'drugs': [for (final row in drugs) row.toJson()],
    'injectionPlans': [for (final row in injectionPlans) row.toJson()],
    'injections': [for (final row in injections) row.toJson()],
    'injectionPhotos': [for (final row in injectionPhotos) row.toJson()],
  };

  /// [version] 是备份格式版本，见 `BackupService.formatVersion`。
  factory DataSnapshot.fromJson(
    Map<String, Object?> json, {
    required int version,
  }) {
    _fillValueDates(json);
    if (version < 5) _clearImageNames(json);
    // 第 3 版才有注射照片，更早的备份里没有这一项。
    json['injectionPhotos'] ??= <Object>[];
    _buildLegacyDrugs(json);
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
      drugs: rows('drugs', DrugEntry.fromJson),
      injectionPlans: rows('injectionPlans', InjectionPlanEntry.fromJson),
      injections: rows('injections', InjectionEntry.fromJson),
      injectionPhotos: rows('injectionPhotos', InjectionPhotoEntry.fromJson),
    );
  }
}

/// 第 4 版之前没有药品列表：计划里的药品是一段文字，计划的照片直接挂在计划上。
///
/// 和数据库升级同一套规则：每个档案里计划的药品与打过的药品名各建一个药品，
/// 计划改为指向它，计划的照片归到计划的药品；计划没填药品时这些照片没有归属，丢弃。
void _buildLegacyDrugs(Map<String, Object?> json) {
  if (json['drugs'] != null) return;
  final plans = json['injectionPlans'];
  final injections = json['injections'];
  final photos = json['injectionPhotos'];
  if (plans is! List || injections is! List || photos is! List) return;

  final drugs = <Map<String, Object?>>[];
  final ids = <String, String>{};
  String? ensure(Object? profileId, Object? name) {
    if (profileId is! String || name is! String) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    return ids.putIfAbsent('$profileId\n$trimmed', () {
      final id = const Uuid().v4();
      drugs.add({
        'id': id,
        'profileId': profileId,
        'name': trimmed,
        'sortOrder': drugs.length,
        'createdAt': 0,
      });
      return id;
    });
  }

  final planDrug = <Object?, String?>{};
  for (final plan in plans) {
    if (plan is! Map) continue;
    final drugId = ensure(plan['profileId'], plan.remove('drug'));
    plan['drugId'] = drugId;
    planDrug[plan['profileId']] = drugId;
  }
  for (final injection in injections) {
    if (injection is Map) ensure(injection['profileId'], injection['drug']);
  }
  photos.removeWhere((photo) {
    if (photo is! Map || photo['injectionId'] != null) return false;
    final drugId = planDrug[photo['profileId']];
    photo['drugId'] = drugId;
    return drugId == null;
  });
  json['drugs'] = drugs;
}

/// 第 5 版之前图片附件的名称是相册给的文件名（如 `1000034567.jpg`），从未显示过；
/// 现在名称会显示出来，清空，免得每张老照片下面都挂一串数字。PDF 的文件名保留。
void _clearImageNames(Map<String, Object?> json) {
  final attachments = json['attachments'];
  if (attachments is! List) return;
  for (final attachment in attachments) {
    if (attachment is Map && attachment['kind'] == AttachmentKind.image.index) {
      attachment['name'] = '';
    }
  }
}

/// 第 1 版备份里指标数值没有自己的日期（那时一律取所属记录的日期），按记录补上。
void _fillValueDates(Map<String, Object?> json) {
  final records = json['records'];
  final values = json['indicatorValues'];
  if (records is! List || values is! List) return;
  final dates = {
    for (final record in records)
      if (record is Map) record['id']: record['date'],
  };
  for (final value in values) {
    if (value is Map && value['date'] == null) {
      value['date'] = dates[value['recordId']];
    }
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
    Drugs,
    InjectionPlans,
    Injections,
    InjectionPhotos,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'ligy_medical'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

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
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // 指标数值可以不属于任何记录：record_id 改为可空，日期存在数值自己身上。
        // 老数据的日期从所属记录取。重建表会丢掉手建的索引，补建一次。
        await migrator.alterTable(
          TableMigration(
            indicatorValues,
            newColumns: [indicatorValues.date],
            columnTransformer: {
              indicatorValues.date: const CustomExpression<String>(
                '(SELECT date FROM records '
                'WHERE records.id = indicator_values.record_id)',
              ),
            },
          ),
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_indicator_values_indicator '
          'ON indicator_values(indicator_id)',
        );
      }
      if (from < 3) {
        await migrator.createTable(injectionPhotos);
      }
      if (from < 4) {
        // 药品从计划里的一段文字变成单独维护的列表。规则与老备份的转换一致
        // （见 `_buildLegacyDrugs`）：计划的药品和打过的药品名各建一个药品，
        // 计划改为指向它，计划的照片归到计划的药品，没有归属的丢弃。
        await migrator.createTable(drugs);
        final now = DateTime.now().millisecondsSinceEpoch;
        await customStatement(
          'INSERT OR IGNORE INTO drugs '
          '(id, profile_id, name, sort_order, created_at) '
          'SELECT lower(hex(randomblob(16))), profile_id, TRIM(drug), 0, ? '
          "FROM injection_plans WHERE TRIM(drug) != ''",
          [now],
        );
        await customStatement(
          'INSERT OR IGNORE INTO drugs '
          '(id, profile_id, name, sort_order, created_at) '
          'SELECT lower(hex(randomblob(16))), profile_id, TRIM(drug), 1, ? '
          "FROM injections WHERE TRIM(drug) != '' "
          'GROUP BY profile_id, TRIM(drug)',
          [now],
        );
        await migrator.alterTable(
          TableMigration(
            injectionPlans,
            newColumns: [injectionPlans.drugId],
            columnTransformer: {
              injectionPlans.drugId: const CustomExpression<String>(
                '(SELECT id FROM drugs '
                'WHERE drugs.profile_id = injection_plans.profile_id '
                'AND drugs.name = TRIM(injection_plans.drug))',
              ),
            },
          ),
        );
        // 第 3 版之前的库刚按新定义建了照片表，已经带 drug_id。
        if (from == 3) {
          await migrator.addColumn(injectionPhotos, injectionPhotos.drugId);
          await customStatement(
            'UPDATE injection_photos SET drug_id = '
            '(SELECT drug_id FROM injection_plans '
            'WHERE injection_plans.profile_id = injection_photos.profile_id) '
            'WHERE injection_id IS NULL',
          );
          await customStatement(
            'DELETE FROM injection_photos '
            'WHERE injection_id IS NULL AND drug_id IS NULL',
          );
        }
      }
      if (from < 5) {
        // 图片附件的名称改为用户自己起的；原来存的是相册文件名，清空（见 `_clearImageNames`）。
        await customStatement(
          "UPDATE attachments SET name = '' WHERE kind = ?",
          [AttachmentKind.image.index],
        );
      }
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
          .putIfAbsent(value.recordId!, () => [])
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

  /// 档案下的指标及其全部数值（按日期升序）。还没有数值的指标也在内。
  Future<List<IndicatorSeries>> _loadSeries(
    String profileId, {
    String? indicatorId,
  }) async {
    final indicatorQuery = select(indicators)
      ..where((row) => row.profileId.equals(profileId));
    if (indicatorId != null) {
      indicatorQuery.where((row) => row.id.equals(indicatorId));
    }
    final indicatorRows = await indicatorQuery.get();
    if (indicatorRows.isEmpty) return const [];

    final valueRows =
        await (select(indicatorValues)
              ..where(
                (row) => row.indicatorId.isIn([
                  for (final indicator in indicatorRows) indicator.id,
                ]),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.date),
                (row) => OrderingTerm.asc(row.sortOrder),
              ]))
            .get();
    final pointsByIndicator = <String, List<IndicatorPoint>>{};
    for (final value in valueRows) {
      pointsByIndicator
          .putIfAbsent(value.indicatorId, () => [])
          .add(
            IndicatorPoint(
              valueId: value.id,
              recordId: value.recordId,
              date: value.date,
              value: value.value,
            ),
          );
    }
    final series = [
      for (final indicator in indicatorRows)
        IndicatorSeries(
          indicator: indicator,
          points: pointsByIndicator[indicator.id] ?? const [],
        ),
    ];
    // 最近测过的排前面：常看的指标总是最近查过的那几项。还没数据的排最后，按创建顺序。
    series.sort((a, b) {
      if (a.points.isEmpty || b.points.isEmpty) {
        if (a.points.isEmpty && b.points.isEmpty) {
          return a.indicator.createdAt.compareTo(b.indicator.createdAt);
        }
        return a.points.isEmpty ? 1 : -1;
      }
      return b.points.last.date.compareTo(a.points.last.date);
    });
    return series;
  }

  Set<ResultSetImplementation> get _seriesTables => {
    indicators,
    indicatorValues,
  };

  Stream<List<IndicatorSeries>> watchIndicatorSeries(String profileId) {
    return _watch(_seriesTables, () => _loadSeries(profileId));
  }

  /// 指标被删掉（或合并进别的指标）时给 null。
  Stream<IndicatorSeries?> watchOneSeries(
    String profileId,
    String indicatorId,
  ) {
    return _watch(_seriesTables, () async {
      final series = await _loadSeries(profileId, indicatorId: indicatorId);
      return series.isEmpty ? null : series.single;
    });
  }

  /// 新建指标。同一档案里已有同名指标时返回 null，不建。
  Future<String?> createIndicator({
    required String id,
    required String profileId,
    required String name,
    required String unit,
    required double? refLow,
    required double? refHigh,
  }) async {
    final existing =
        await (select(indicators)..where(
              (row) => row.profileId.equals(profileId) & row.name.equals(name),
            ))
            .getSingleOrNull();
    if (existing != null) return null;
    await into(indicators).insert(
      IndicatorsCompanion.insert(
        id: id,
        profileId: profileId,
        name: name,
        unit: Value(unit),
        refLow: Value(refLow),
        refHigh: Value(refHigh),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return id;
  }

  /// 删除指标及它的全部数值，包括在记录里填写的那些。
  Future<void> deleteIndicator(String id) {
    return (delete(indicators)..where((row) => row.id.equals(id))).go();
  }

  Future<IndicatorValueEntry?> indicatorValue(String id) {
    return (select(
      indicatorValues,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  /// 在指标页单独添加或修改一次数值（不属于任何记录）。
  Future<void> saveStandaloneValue({
    required String id,
    required String indicatorId,
    required String date,
    required double value,
  }) {
    return into(indicatorValues).insertOnConflictUpdate(
      IndicatorValuesCompanion.insert(
        id: id,
        indicatorId: indicatorId,
        value: value,
        date: date,
      ),
    );
  }

  Future<void> deleteIndicatorValue(String id) {
    return (delete(indicatorValues)..where((row) => row.id.equals(id))).go();
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

  // ------------------------------------------------------------------ 注射

  Stream<InjectionPlanEntry?> watchInjectionPlan(String profileId) {
    return (select(
      injectionPlans,
    )..where((row) => row.profileId.equals(profileId))).watchSingleOrNull();
  }

  Future<void> saveInjectionPlan({
    required String profileId,
    required String? drugId,
    required int intervalDays,
    required List<String> sites,
    required String note,
  }) {
    return into(injectionPlans).insertOnConflictUpdate(
      InjectionPlansCompanion.insert(
        profileId: profileId,
        drugId: Value(drugId),
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

  /// 档案下的全部注射照片（药品的 + 每一针的），按显示顺序。
  Stream<List<InjectionPhotoEntry>> watchInjectionPhotos(String profileId) {
    final query = select(injectionPhotos)
      ..where((row) => row.profileId.equals(profileId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch();
  }

  /// 某一针或某个药品的照片，二者传其一。
  Future<List<InjectionPhotoEntry>> photoList({
    String? injectionId,
    String? drugId,
  }) {
    assert((injectionId == null) != (drugId == null));
    final query = select(injectionPhotos)
      ..where(
        (row) => injectionId != null
            ? row.injectionId.equals(injectionId)
            : row.drugId.equals(drugId!),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.get();
  }

  // ------------------------------------------------------------------ 药品

  Stream<List<DrugEntry>> watchDrugs(String profileId) {
    final query = select(drugs)
      ..where((row) => row.profileId.equals(profileId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch();
  }

  /// 新建或改名。同一档案里已有同名的其他药品时返回 false，不写。
  Future<bool> saveDrug({
    required String id,
    required String profileId,
    required String name,
  }) async {
    final clash =
        await (select(drugs)..where(
              (row) =>
                  row.profileId.equals(profileId) &
                  row.name.equals(name) &
                  row.id.equals(id).not(),
            ))
            .getSingleOrNull();
    if (clash != null) return false;
    final existing = await (select(
      drugs,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      await (update(drugs)..where((row) => row.id.equals(id))).write(
        DrugsCompanion(name: Value(name)),
      );
      return true;
    }
    final maxSort = drugs.sortOrder.max();
    final result =
        await (selectOnly(drugs)
              ..addColumns([maxSort])
              ..where(drugs.profileId.equals(profileId)))
            .getSingle();
    await into(drugs).insert(
      DrugsCompanion.insert(
        id: id,
        profileId: profileId,
        name: name,
        sortOrder: Value((result.read(maxSort) ?? -1) + 1),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return true;
  }

  /// 删除药品：它的照片行级联删掉，用它的计划变成未选药品；打过的记录不动。
  Future<void> deleteDrug(String id) {
    return (delete(drugs)..where((row) => row.id.equals(id))).go();
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
        drugs: await select(drugs).get(),
        injectionPlans: await select(injectionPlans).get(),
        injections: await select(injections).get(),
        injectionPhotos: await select(injectionPhotos).get(),
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
        batch.insertAll(drugs, data.drugs);
        batch.insertAll(injectionPlans, data.injectionPlans);
        batch.insertAll(injections, data.injections);
        batch.insertAll(injectionPhotos, data.injectionPhotos);
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
