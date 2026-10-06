import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../indicators/presentation/indicator_edit_screen.dart';
import '../../indicators/presentation/indicator_screen.dart';
import '../../indicators/presentation/indicators_tab.dart';
import '../../injections/presentation/injection_editor_screen.dart';
import '../../injections/presentation/injection_plan_screen.dart';
import '../../injections/presentation/injections_tab.dart';
import '../../records/presentation/record_editor_screen.dart';
import '../../records/presentation/records_tab.dart';
import 'profile_editor_screen.dart';
import 'profile_theme.dart';

enum ProfileTab {
  records('记录'),
  indicators('指标'),
  injections('注射');

  const ProfileTab(this.label);

  final String label;
}

/// 单个档案：记录 / 指标 / 注射三个视图。
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ProfileTab _tab = ProfileTab.records;

  void _addRecord() {
    Navigator.of(context).push(
      profileRoute<void>(
        widget.profileId,
        (_) => RecordEditorScreen(profileId: widget.profileId),
      ),
    );
  }

  /// 新建指标后直接进入它，接着就能添加数值。
  Future<void> _addIndicator() async {
    final navigator = Navigator.of(context);
    final id = await navigator.push<String>(
      profileRoute<String>(
        widget.profileId,
        (_) => IndicatorEditScreen(profileId: widget.profileId),
      ),
    );
    if (id == null || !mounted) return;
    navigator.push(
      profileRoute<void>(
        widget.profileId,
        (_) => IndicatorScreen(profileId: widget.profileId, indicatorId: id),
      ),
    );
  }

  void _addInjection() {
    Navigator.of(context).push(
      profileRoute<void>(
        widget.profileId,
        (_) => InjectionEditorScreen(profileId: widget.profileId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileProvider(widget.profileId));
    final profile = async.value;
    if (profile == null) {
      return Scaffold(
        body: AppTopBar(
          title: '',
          slivers: [
            if (!async.isLoading)
              const SliverToBoxAdapter(
                child: EmptyState(icon: FLucideIcons.userX, title: '档案不存在'),
              ),
          ],
        ),
      );
    }
    final tabs = [
      ProfileTab.records,
      ProfileTab.indicators,
      if (profile.injectionEnabled) ProfileTab.injections,
    ];
    // 关掉注射模块后，停在注射页的状态要退回记录页。
    final tab = tabs.contains(_tab) ? _tab : ProfileTab.records;
    return Scaffold(
      body: AppTopBar(
        title: profile.name,
        actions: [
          if (tab == ProfileTab.injections)
            AppHeaderAction(
              icon: FLucideIcons.calendarCog,
              tooltip: '注射计划',
              onTap: () => Navigator.of(context).push(
                profileRoute<void>(
                  profile.id,
                  (_) => InjectionPlanScreen(
                    profileId: profile.id,
                    plan: ref.read(injectionPlanProvider(profile.id)).value,
                  ),
                ),
              ),
            ),
          AppHeaderAction(
            icon: FLucideIcons.userPen,
            tooltip: '编辑档案',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileEditorScreen(profile: profile),
              ),
            ),
          ),
        ],
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            sliver: SliverToBoxAdapter(
              child: AppTabs<ProfileTab>(
                values: tabs,
                labelOf: (value) => value.label,
                selected: tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
            ),
          ),
          switch (tab) {
            ProfileTab.records => RecordsTab(profileId: profile.id),
            ProfileTab.indicators => IndicatorsTab(profileId: profile.id),
            ProfileTab.injections => InjectionsTab(profileId: profile.id),
          },
          // 给悬浮按钮让出位置，最后一张卡不被挡住。
          SliverToBoxAdapter(
            child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: switch (tab) {
        ProfileTab.records => AppFab(onPressed: _addRecord, tooltip: '新建记录'),
        ProfileTab.injections => AppFab(
          onPressed: _addInjection,
          tooltip: '记录注射',
        ),
        ProfileTab.indicators => AppFab(
          onPressed: _addIndicator,
          tooltip: '新建指标',
        ),
      },
    );
  }
}
