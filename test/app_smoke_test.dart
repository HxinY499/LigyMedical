import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/app/app.dart';
import 'package:ligy_medical/core/appearance/appearance.dart';
import 'package:ligy_medical/core/database/app_database.dart';
import 'package:ligy_medical/core/media/image_storage.dart';
import 'package:ligy_medical/core/preferences/default_profile.dart';
import 'package:ligy_medical/core/providers.dart';
import 'package:ligy_medical/core/utils/ledger_date.dart';
import 'package:ligy_medical/features/records/application/record_service.dart';

Future<void> _seed(AppDatabase db) async {
  final service = RecordService(db, ImageStorage.atRoot('/tmp/ligy_medical_unused'));
  await db.upsertProfile(
    id: 'me',
    name: '我',
    colorIndex: 0,
    injectionEnabled: true,
  );
  await db.upsertProfile(
    id: 'mom',
    name: '妈妈',
    colorIndex: 1,
    injectionEnabled: false,
  );
  await db.addFieldDef(id: 'dept', name: '科室');
  for (final (date, esr, crp) in [
    ('2025-12-22', 3.0, 1.6),
    ('2026-04-26', 1.0, 1.75),
  ]) {
    await service.save(
      RecordDraft(
        id: null,
        profileId: 'me',
        kind: RecordKind.visit,
        date: date,
        hospital: '第五医院 刘焕',
        content: '抽血化验。大夫开了化瘀消痹胶囊，说疼的厉害了吃依托考昔，继续打针两周一次，能稳定半年就减量',
        fields: const {'dept': '风湿免疫科'},
        indicators: [
          IndicatorInput(name: '血沉', value: esr, unit: 'mm/h'),
          IndicatorInput(name: 'C反应蛋白', value: crp, unit: 'mg/L'),
        ],
        keptAttachments: const [],
        newAttachments: const [],
      ),
    );
  }
  final crp = (await db.indicatorList('me')).firstWhere((i) => i.name == 'C反应蛋白');
  await db.updateIndicator(id: crp.id, unit: 'mg/L', refLow: null, refHigh: 1.7);
  await db.saveInjectionPlan(
    profileId: 'me',
    drug: '阿达木单抗',
    intervalDays: 14,
    sites: const ['左腹', '右腹'],
    note: '感冒发烧嗓子疼等，都不能打，要往后延',
  );
  final today = dateOnly(DateTime.now());
  for (var i = 0; i < 5; i++) {
    await db.saveInjection(
      id: 'inj$i',
      profileId: 'me',
      date: dateKey(today.subtract(Duration(days: 14 * (5 - i) + (i == 2 ? 7 : 0)))),
      drug: '阿达木单抗',
      site: i.isEven ? '左腹' : '右腹',
      place: '自己打',
      note: i == 2 ? '嗓子疼延后了一周' : '',
    );
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('主要页面在手机宽度下都能渲染', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => _seed(db));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appearanceProvider.overrideWith(
            () => AppearanceController.seeded(AppearanceConfig.initial),
          ),
        ],
        child: const LigyMedicalApp(),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // 页头返回键是自绘的 AppHeaderAction，pageBack() 认不出来。
    Future<void> back() async {
      await tester.tap(find.byTooltip('返回').last);
      await settle();
    }

    await settle();
    expect(find.text('健康档案'), findsOneWidget);
    expect(find.text('妈妈'), findsOneWidget);
    expect(find.textContaining('2 条记录'), findsOneWidget);
    expect(find.textContaining('下次注射'), findsOneWidget);

    // 档案 → 记录
    // 头像首字也是「我」，点名字那一个。
    await tester.tap(find.text('我').last);
    await settle();
    expect(find.text('26'), findsOneWidget);
    expect(find.textContaining('C反应蛋白'), findsWidgets);

    // 记录详情
    await tester.tap(find.text('26'));
    await settle();
    expect(find.text('风湿免疫科'), findsOneWidget);
    expect(find.text('参考 ≤ 1.7'), findsOneWidget);

    // 编辑记录
    await tester.tap(find.byTooltip('编辑'));
    await settle();
    expect(find.text('编辑记录'), findsOneWidget);
    await back();
    await settle();
    await back();
    await settle();

    // 指标
    await tester.tap(find.text('指标'));
    await settle();
    expect(find.text('血沉'), findsOneWidget);
    await tester.tap(find.text('血沉'));
    await settle();
    expect(find.text('历史 · 2 次'), findsOneWidget);
    await back();
    await settle();

    // 注射：列表 + 日历
    await tester.tap(find.text('注射'));
    await settle();
    expect(find.text('下次注射 · 阿达木单抗'), findsOneWidget);
    expect(find.text('间隔21天'), findsOneWidget);
    await tester.tap(find.byTooltip('日历'));
    await settle();
    expect(find.textContaining('预计'), findsWidgets);

    // 记录注射
    await tester.tap(find.byTooltip('记录注射'));
    await settle();
    expect(find.text('记录注射'), findsOneWidget);
    await back();
    await settle();

    // 计划
    await tester.tap(find.byTooltip('注射计划'));
    await settle();
    expect(find.text('注射计划'), findsOneWidget);
    await back();
    await settle();

    // 新建记录
    await tester.tap(find.text('记录'));
    await settle();
    await tester.tap(find.byTooltip('新建记录'));
    await settle();
    expect(find.text('新建记录'), findsWidgets);
    await back();
    await settle();
    await back();
    await settle();

    // 设置
    await tester.tap(find.byTooltip('设置'));
    await settle();
    expect(find.text('科室'), findsOneWidget);
    expect(find.text('打开应用时进入'), findsOneWidget);

    // 卸载后 drift 会用零时长定时器清理 stream，冲掉它们，否则报定时器未决。
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('设了启动档案时直接进入该档案，返回回到列表', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => _seed(db));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appearanceProvider.overrideWith(
            () => AppearanceController.seeded(AppearanceConfig.initial),
          ),
          defaultProfileProvider.overrideWith(
            () => DefaultProfileController.seeded('me'),
          ),
        ],
        child: const LigyMedicalApp(),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('26'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('健康档案'), findsOneWidget);
    expect(find.text('妈妈'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
