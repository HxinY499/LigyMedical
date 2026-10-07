import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/core/database/app_database.dart';
import 'package:ligy_medical/core/media/image_storage.dart';
import 'package:ligy_medical/features/injections/application/injection_schedule.dart';
import 'package:ligy_medical/features/records/application/record_service.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late RecordService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('ligy_medical_test');
    service = RecordService(db, ImageStorage.atRoot(root.path));
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

  RecordDraft draft({
    String? id,
    String date = '2026-04-26',
    List<IndicatorInput> indicators = const [],
    List<AttachmentEntry> kept = const [],
    List<PendingAttachment> pending = const [],
    Map<String, String> fields = const {},
  }) => RecordDraft(
    id: id,
    profileId: 'me',
    kind: RecordKind.visit,
    date: date,
    hospital: '第五医院',
    content: '抽血化验',
    fields: fields,
    indicators: indicators,
    keptAttachments: kept,
    newAttachments: pending,
  );

  test('同名指标跨记录归到同一条趋势线，按日期升序', () async {
    await service.save(
      draft(
        date: '2026-04-26',
        indicators: const [
          IndicatorInput(name: '血沉', value: 1, unit: 'mm/h'),
          IndicatorInput(name: 'C反应蛋白', value: 1.75, unit: 'mg/L'),
        ],
      ),
    );
    await service.save(
      draft(
        date: '2025-12-22',
        indicators: const [IndicatorInput(name: '血沉', value: 3, unit: '')],
      ),
    );

    final series = await db.watchIndicatorSeries('me').first;
    final esr = series.firstWhere((s) => s.indicator.name == '血沉');
    expect(esr.points.map((p) => p.date), ['2025-12-22', '2026-04-26']);
    expect(esr.points.map((p) => p.value), [3, 1]);
    expect(esr.indicator.unit, 'mm/h');
    expect(series, hasLength(2));
  });

  test('记录里删掉某项指标，指标本身保留（可能是在指标页单独建的）', () async {
    final id = await service.save(
      draft(
        indicators: const [IndicatorInput(name: 'ESR', value: 2, unit: '')],
      ),
    );
    await service.save(draft(id: id));
    final series = await db.watchIndicatorSeries('me').first;
    expect(series.single.indicator.name, 'ESR');
    expect(series.single.points, isEmpty);
  });

  test('单独添加的数值与记录里的数值合在一条趋势线上，只有后者能跳记录', () async {
    final indicatorId = await db.createIndicator(
      id: 'esr',
      profileId: 'me',
      name: '血沉',
      unit: 'mm/h',
      refLow: null,
      refHigh: 20,
    );
    expect(indicatorId, 'esr');
    expect(
      await db.createIndicator(
        id: 'dup',
        profileId: 'me',
        name: '血沉',
        unit: '',
        refLow: null,
        refHigh: null,
      ),
      isNull,
      reason: '同名指标不能重复建',
    );
    await db.saveStandaloneValue(
      id: 'v1',
      indicatorId: 'esr',
      date: '2026-03-01',
      value: 4,
    );
    final recordId = await service.save(
      draft(
        date: '2026-04-26',
        indicators: const [IndicatorInput(name: '血沉', value: 1, unit: '')],
      ),
    );

    var points = (await db.watchOneSeries('me', 'esr').first)!.points;
    expect(points.map((p) => p.date), ['2026-03-01', '2026-04-26']);
    expect(points.map((p) => p.recordId), [null, recordId]);

    // 改记录日期，它带来的数值日期跟着变。
    await service.save(
      draft(
        id: recordId,
        date: '2026-02-01',
        indicators: const [IndicatorInput(name: '血沉', value: 1, unit: '')],
      ),
    );
    points = (await db.watchOneSeries('me', 'esr').first)!.points;
    expect(points.map((p) => p.date), ['2026-02-01', '2026-03-01']);

    // 删记录只带走它自己的数值，单独添加的留下。
    final record = (await db.watchRecord(recordId).first)!.record;
    await service.delete(record);
    points = (await db.watchOneSeries('me', 'esr').first)!.points;
    expect(points.single.valueId, 'v1');

    await db.deleteIndicatorValue('v1');
    expect((await db.watchOneSeries('me', 'esr').first)!.points, isEmpty);
    await db.deleteIndicator('esr');
    expect(await db.watchOneSeries('me', 'esr').first, isNull);
  });

  test('改名为已有指标时合并数据', () async {
    await service.save(
      draft(
        date: '2026-01-01',
        indicators: const [IndicatorInput(name: 'ESR', value: 5, unit: '')],
      ),
    );
    await service.save(
      draft(
        date: '2026-02-01',
        indicators: const [IndicatorInput(name: '血沉', value: 3, unit: '')],
      ),
    );
    final list = await db.indicatorList('me');
    final esr = list.firstWhere((i) => i.name == 'ESR');
    final target = list.firstWhere((i) => i.name == '血沉');

    final resultId = await db.renameIndicator(esr.id, '血沉');

    expect(resultId, target.id);
    final series = await db.watchIndicatorSeries('me').first;
    expect(series, hasLength(1));
    expect(series.single.points.map((p) => p.value), [5, 3]);
  });

  test('PDF 附件落盘，删除记录时文件与数据一起清掉', () async {
    final source = File('${root.path}/report.pdf')..writeAsBytesSync([1, 2, 3]);
    final id = await service.save(
      draft(
        pending: [
          PendingAttachment(
            kind: AttachmentKind.pdf,
            sourcePath: source.path,
            name: '体检报告.pdf',
          ),
        ],
      ),
    );
    final bundle = await db.watchRecord(id).first;
    final pdf = bundle!.attachments.single;
    expect(pdf.name, '体检报告.pdf');
    expect(File('${root.path}/${pdf.path}').existsSync(), isTrue);

    await service.delete(bundle.record);
    expect(await db.watchRecord(id).first, isNull);
    expect(File('${root.path}/${pdf.path}').existsSync(), isFalse);
  });

  test('编辑时移除的附件文件会被删除', () async {
    final source = File('${root.path}/a.pdf')..writeAsBytesSync([1]);
    final id = await service.save(
      draft(
        pending: [
          PendingAttachment(
            kind: AttachmentKind.pdf,
            sourcePath: source.path,
            name: 'a.pdf',
          ),
        ],
      ),
    );
    final pdf = (await db.watchRecord(id).first)!.attachments.single;
    await service.save(draft(id: id));
    expect((await db.watchRecord(id).first)!.attachments, isEmpty);
    expect(File('${root.path}/${pdf.path}').existsSync(), isFalse);
  });

  test('附件名称：新附件按给的名称存，编辑时改名、清空都会写回', () async {
    final source = File('${root.path}/scan.pdf')..writeAsBytesSync([1]);
    final id = await service.save(
      draft(
        pending: [
          PendingAttachment(
            kind: AttachmentKind.pdf,
            sourcePath: source.path,
            name: 'scan.pdf',
          ).rename('血常规'),
        ],
      ),
    );
    final pdf = (await db.watchRecord(id).first)!.attachments.single;
    expect(pdf.name, '血常规');

    await service.save(
      draft(
        id: id,
        kept: [pdf.copyWith(name: '血常规 4月')],
      ),
    );
    expect((await db.watchRecord(id).first)!.attachments.single.name, '血常规 4月');
    await service.save(
      draft(
        id: id,
        kept: [pdf.copyWith(name: '')],
      ),
    );
    expect((await db.watchRecord(id).first)!.attachments.single.name, '');
  });

  test('自定义字段只存非空值，删字段级联删值', () async {
    await db.addFieldDef(id: 'f1', name: '科室');
    final id = await service.save(draft(fields: {'f1': ' 风湿免疫科 '}));
    expect((await db.watchRecord(id).first)!.fields, {'f1': '风湿免疫科'});
    await db.deleteFieldDef('f1');
    expect((await db.watchRecord(id).first)!.fields, isEmpty);
  });

  test('删除档案级联删除记录', () async {
    await service.save(draft());
    await service.deleteProfile('me');
    expect(await db.watchRecords('me').first, isEmpty);
  });

  group('注射排期', () {
    InjectionEntry entry(String date, String site) => InjectionEntry(
      id: date,
      profileId: 'me',
      date: date,
      drug: '阿达木',
      site: site,
      place: '',
      note: '',
      createdAt: 0,
      updatedAt: 0,
    );

    test('下次日期按最近一次实际日期顺延', () {
      final list = [entry('2026-09-18', '左腹'), entry('2026-08-30', '右腹')];
      expect(nextInjectionDate(list, 14), DateTime(2026, 10, 2));
      expect(nextInjectionDate(const [], 14), isNull);
    });

    test('预计注射日从最近一针起每隔一个间隔一直往后排', () {
      final last = DateTime(2026, 10, 5);
      expect(isProjectedInjectionDay(DateTime(2026, 10, 5), last, 14), isFalse);
      expect(isProjectedInjectionDay(DateTime(2026, 10, 19), last, 14), isTrue);
      expect(isProjectedInjectionDay(DateTime(2026, 11, 2), last, 14), isTrue);
      expect(isProjectedInjectionDay(DateTime(2027, 3, 22), last, 14), isTrue);
      expect(
        isProjectedInjectionDay(DateTime(2026, 10, 20), last, 14),
        isFalse,
      );
      expect(isProjectedInjectionDay(DateTime(2026, 9, 21), last, 14), isFalse);
      expect(
        isProjectedInjectionDay(DateTime(2026, 10, 19), null, 14),
        isFalse,
      );
      // 跨年不漂移：按日历日算，不按毫秒。
      expect(isProjectedInjectionDay(DateTime(2027, 1, 11), last, 14), isTrue);
    });

    test('间隔天数', () {
      final list = [entry('2026-05-17', ''), entry('2026-04-26', '')];
      expect(intervalBefore(list, 0), 21);
      expect(intervalBefore(list, 1), isNull);
    });
  });
}
