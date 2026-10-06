import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../injections/application/injection_schedule.dart';
import '../../settings/presentation/settings_screen.dart';
import 'profile_avatar.dart';
import 'profile_editor_screen.dart';
import 'profile_screen.dart';
import 'profile_theme.dart';

/// 首页：全部档案。
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  void _create(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileEditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppPageHeader(
        title: '健康档案',
        actions: [
          AppHeaderAction(
            icon: FLucideIcons.userPlus,
            tooltip: '新建档案',
            onTap: () => _create(context),
          ),
          AppHeaderAction(
            icon: FLucideIcons.settings2,
            tooltip: '设置',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        slivers: [
          ...profiles.when(
            loading: () => const [SliverToBoxAdapter()],
            error: (error, _) => [
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: FLucideIcons.circleAlert,
                  title: '读取失败',
                  detail: '$error',
                ),
              ),
            ],
            data: (items) => items.isEmpty
                ? [
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: FLucideIcons.bookUser,
                        title: '还没有档案',
                        action: AppButton(
                          onPress: () => _create(context),
                          prefix: const Icon(FLucideIcons.plus),
                          child: const Text('新建档案'),
                        ),
                      ),
                    ),
                  ]
                : [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottom),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _ProfileCard(profile: items[index]),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final ProfileEntry profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final summary = ref.watch(profileSummaryProvider(profile.id)).value;
    final latest = summary?.latest;
    final meta = [
      '${summary?.count ?? 0} 条记录',
      if (latest != null) '最近 ${formatDotDate(latest)}',
    ].join(' · ');
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        profileRoute<void>(
          profile.id,
          (_) => ProfileScreen(profileId: profile.id),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                ProfileAvatar(
                  name: profile.name,
                  colorIndex: profile.colorIndex,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (profile.injectionEnabled) _NextInjectionLine(profile: profile),
        ],
      ),
    );
  }
}

/// 卡片底部的注射条：与上半部分用一道发丝线分开，右侧倒计时胶囊。
class _NextInjectionLine extends ConsumerWidget {
  const _NextInjectionLine({required this.profile});

  final ProfileEntry profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final plan = ref.watch(injectionPlanProvider(profile.id)).value;
    final injections = ref.watch(injectionsProvider(profile.id)).value;
    if (injections == null) return const SizedBox.shrink();
    final next = nextInjectionDate(injections, plan?.intervalDays ?? 14);
    final overdue = next != null && next.isBefore(dateOnly(DateTime.now()));
    final tint = overdue ? colors.danger : colors.primary;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: colors.lineSoft),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Icon(FLucideIcons.syringe, size: 16, color: tint),
              const SizedBox(width: 10),
              Text('下次注射', style: TextStyle(fontSize: 13, color: colors.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  next == null ? '未开始' : formatDayWithWeekday(next),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: overdue ? colors.danger : colors.ink,
                  ),
                ),
              ),
              if (next != null)
                StatusPill(
                  label: formatRelativeDays(next),
                  tone: overdue ? StatusTone.danger : StatusTone.primary,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
