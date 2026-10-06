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

  test('编辑时删掉的指标若无其他数据会被清理', () async {
    final id = await service.save(
      draft(indicators: const [IndicatorInput(name: 'ESR', value: 2, unit: '')]),
    );
    await service.save(draft(id: id));
    expect(await db.indicatorList('me'), isEmpty);
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
    final source = File('${root.path}/report.pdf')
      ..writeAsBytesSync([1, 2, 3]);
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

    test('部位按轮换表循环建议', () {
      const sites = ['左腹', '右腹', '左臂'];
      expect(suggestSite(sites, '左腹'), '右腹');
      expect(suggestSite(sites, '左臂'), '左腹');
      expect(suggestSite(sites, '大腿'), '左腹');
      expect(suggestSite(sites, null), '左腹');
      expect(suggestSite(const [], '左腹'), isNull);
    });

    test('预计注射日从最近一针起每隔一个间隔一直往后排', () {
      final last = DateTime(2026, 10, 5);
      expect(isProjectedInjectionDay(DateTime(2026, 10, 5), last, 14), isFalse);
      expect(isProjectedInjectionDay(DateTime(2026, 10, 19), last, 14), isTrue);
      expect(isProjectedInjectionDay(DateTime(2026, 11, 2), last, 14), isTrue);
      expect(isProjectedInjectionDay(DateTime(2027, 3, 22), last, 14), isTrue);
      expect(isProjectedInjectionDay(DateTime(2026, 10, 20), last, 14), isFalse);
      expect(isProjectedInjectionDay(DateTime(2026, 9, 21), last, 14), isFalse);
      expect(isProjectedInjectionDay(DateTime(2026, 10, 19), null, 14), isFalse);
      // 跨夏令时 / 跨年不漂移：按日历日算，不按毫秒。
      expect(isProjectedInjectionDay(DateTime(2027, 1, 11), last, 14), isTrue);
    });

    test('间隔天数', () {
      final list = [entry('2026-05-17', ''), entry('2026-04-26', '')];
      expect(intervalBefore(list, 0), 21);
      expect(intervalBefore(list, 1), isNull);
    });
  });
}
