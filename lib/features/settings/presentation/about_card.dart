import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/update/update_controller.dart';
import '../../../core/update/update_progress.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/settings_widgets.dart';

/// 关于卡片：应用名 + 版本号 + 检查更新。
///
/// 版本号从原生 PackageInfo 读，不硬编码，发版后不会过时。
class AboutCard extends ConsumerStatefulWidget {
  const AboutCard({super.key});

  @override
  ConsumerState<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends ConsumerState<AboutCard> {
  String? _version;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await ref.read(updateServiceProvider).currentVersion();
    if (!mounted) return;
    setState(() => _version = version?.toString());
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final outcome = await ref
        .read(updateControllerProvider.notifier)
        .checkManually();
    if (!mounted) return;
    setState(() => _checking = false);
    if (outcome.isSilent) return;
    // 检查失败走 error 级别：查不到和「已是最新」是两回事。
    showAppToast(
      context,
      message: outcome.message,
      level: outcome.failed ? AppToastLevel.error : AppToastLevel.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final updateState = ref.watch(updateControllerProvider);
    final updateInfo = updateState.info;
    final offeringUpdate =
        updateInfo != null &&
        updateState.phase != UpdatePhase.idle &&
        updateState.phase != UpdatePhase.failed;
    final busy = _checking || updateState.isBusy;
    final downloading = updateState.isBusy;

    final String? subtitle;
    if (downloading) {
      subtitle = updateDownloadLabel(updateState);
    } else if (_checking) {
      subtitle = '正在检查…';
    } else if (offeringUpdate && updateInfo.apkSize > 0) {
      subtitle =
          '安装包 ${(updateInfo.apkSize / 1024 / 1024).toStringAsFixed(0)}MB';
    } else {
      subtitle = null;
    }

    final Widget? trailing;
    if (downloading) {
      trailing = SizedBox(
        width: 48,
        child: UpdateDownloadTrack(
          fraction: updateState.phase == UpdatePhase.verifying
              ? null
              : updateState.progress?.fraction,
          height: 6,
        ),
      );
    } else if (_checking) {
      trailing = const RowSpinner();
    } else {
      trailing = null;
    }

    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: context.radii.chipAll,
                ),
                alignment: Alignment.center,
                child: Icon(
                  FLucideIcons.heartPulse,
                  size: 17,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '健康档案',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _version == null ? '正在读取版本…' : '版本 $_version',
                      style: TextStyle(fontSize: 12, color: colors.inactive),
                    ),
                  ],
                ),
              ),
              if (offeringUpdate) const StatusPill(label: '新版本'),
            ],
          ),
        ),
        SettingsItem(
          icon: offeringUpdate
              ? FLucideIcons.cloudDownload
              : FLucideIcons.refreshCw,
          title: offeringUpdate ? '更新到 v${updateInfo.version}' : '检查更新',
          subtitle: subtitle,
          accent: offeringUpdate,
          trailing: trailing,
          showChevron: !busy,
          onTap: busy
              ? null
              : offeringUpdate
              ? () => ref
                    .read(updateControllerProvider.notifier)
                    .downloadAndInstall()
              : _checkUpdate,
        ),
      ],
    );
  }
}
