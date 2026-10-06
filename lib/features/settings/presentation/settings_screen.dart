import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/appearance/appearance.dart';
import '../../../core/database/app_database.dart';
import '../../../core/preferences/default_profile.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../../shared/widgets/settings_widgets.dart';
import 'about_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;
  bool _restoring = false;

  // ------------------------------------------------------------------ 字段

  Future<void> _addField() async {
    final name = await showAppInputDialog(
      context,
      title: '添加字段',
      confirmLabel: '添加',
    );
    if (name == null) return;
    await ref
        .read(databaseProvider)
        .addFieldDef(id: const Uuid().v4(), name: name);
  }

  Future<void> _renameField(FieldDefEntry field) async {
    final name = await showAppInputDialog(
      context,
      title: '重命名字段',
      initial: field.name,
    );
    if (name == null || name == field.name) return;
    await ref.read(databaseProvider).renameFieldDef(field.id, name);
  }

  Future<void> _deleteField(FieldDefEntry field) async {
    final confirmed = await showAppConfirmDialog(
      context,
      message: '删除字段「${field.name}」？\n所有记录里这一项填过的内容都会一起删除。',
      confirmLabel: '删除',
    );
    if (!confirmed) return;
    await ref.read(databaseProvider).deleteFieldDef(field.id);
  }

  // ------------------------------------------------------------------ 启动档案

  Future<void> _pickDefaultProfile(List<ProfileEntry> profiles) async {
    const listValue = '';
    final current = ref.read(defaultProfileProvider) ?? listValue;
    final picked = await showOptionSheet<String>(
      context,
      title: '打开应用时进入',
      current: current,
      options: [
        const SheetOption(
          value: listValue,
          label: '档案列表',
          icon: FLucideIcons.layoutList,
        ),
        for (final profile in profiles)
          SheetOption(
            value: profile.id,
            label: profile.name,
            icon: FLucideIcons.user,
          ),
      ],
    );
    if (picked == null) return;
    await ref
        .read(defaultProfileProvider.notifier)
        .set(picked == listValue ? null : picked);
  }

  // ------------------------------------------------------------------ 备份

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await ref.read(backupServiceProvider).exportAndShare();
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: '导出失败',
          description: '$error',
          level: AppToastLevel.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restore() async {
    final service = ref.read(backupServiceProvider);
    final path = await service.pickBackupFile();
    if (path == null || !mounted) return;
    setState(() => _restoring = true);
    try {
      final preview = await service.inspect(path);
      if (!mounted) return;
      final created = preview.createdAt;
      final confirmed = await showAppConfirmDialog(
        context,
        message:
            '用这份备份覆盖当前全部数据？\n\n'
            '备份时间 ${dateKey(created).replaceAll('-', '.')} '
            '${formatClock(created)}\n'
            '${preview.profileCount} 个档案 · ${preview.recordCount} 条记录\n'
            '${preview.attachmentCount} 个附件 · ${preview.injectionCount} 次注射\n\n'
            '当前手机上的数据会被替换，无法撤销。',
        confirmLabel: '覆盖恢复',
      );
      if (!confirmed) return;
      await service.restore(path);
      // 附件目录整体换过了，按路径缓存的旧图要丢掉。
      PaintingBinding.instance.imageCache.clear();
      await _dropMissingDefaultProfile();
      if (mounted) {
        showAppToast(context, message: '恢复完成', level: AppToastLevel.success);
      }
    } on FormatException catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: '无法恢复',
          description: error.message,
          level: AppToastLevel.error,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message: '恢复失败，当前数据未改动',
          description: '$error',
          level: AppToastLevel.error,
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// 恢复的备份里没有当前设的启动档案时，退回档案列表。
  Future<void> _dropMissingDefaultProfile() async {
    final id = ref.read(defaultProfileProvider);
    if (id == null) return;
    final exists = await ref.read(databaseProvider).watchProfile(id).first;
    if (exists == null) {
      await ref.read(defaultProfileProvider.notifier).set(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fields = ref.watch(fieldDefsProvider).value ?? const [];
    final profiles = ref.watch(profilesProvider).value ?? const [];
    final themeMode = ref.watch(appThemeModeProvider);
    final defaultId = ref.watch(defaultProfileProvider);
    final defaultName = profiles
        .where((profile) => profile.id == defaultId)
        .firstOrNull
        ?.name;
    final busy = _exporting || _restoring;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppTopBar(
        title: '设置',
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottom),
            sliver: SliverList.list(
              children: [
                const SectionLabel('启动'),
                SettingsCard(
                  children: [
                    SettingsItem(
                      icon: FLucideIcons.house,
                      title: '打开应用时进入',
                      value: defaultName ?? '档案列表',
                      showChevron: true,
                      onTap: () => _pickDefaultProfile(profiles),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionLabel('记录字段'),
                SettingsCard(
                  children: [
                    for (final field in fields)
                      SettingsItem(
                        icon: FLucideIcons.textCursorInput,
                        title: field.name,
                        onTap: () => _renameField(field),
                        trailing: InkResponse(
                          onTap: () => _deleteField(field),
                          radius: 18,
                          child: Icon(
                            FLucideIcons.trash2,
                            size: 17,
                            color: colors.muted,
                          ),
                        ),
                      ),
                    SettingsItem(
                      icon: FLucideIcons.plus,
                      title: '添加字段',
                      accent: true,
                      onTap: _addField,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    '记录默认有日期、医院、内容、指标和附件。不够用时在这里加字段，所有记录共用；点字段名可重命名。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: colors.inactive,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionLabel('外观'),
                SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: AppTabs<AppThemeMode>(
                        values: AppThemeMode.values,
                        labelOf: (mode) => mode.label,
                        selected: themeMode,
                        onChanged: (mode) => ref
                            .read(appearanceProvider.notifier)
                            .setThemeMode(mode),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionLabel('数据'),
                SettingsCard(
                  children: [
                    SettingsItem(
                      icon: FLucideIcons.upload,
                      title: '导出备份',
                      subtitle: '全部档案、记录和附件打成一个文件',
                      trailing: _exporting ? const RowSpinner() : null,
                      showChevron: !_exporting,
                      onTap: busy ? null : _export,
                    ),
                    SettingsItem(
                      icon: FLucideIcons.download,
                      title: '从备份恢复',
                      subtitle: '覆盖当前全部数据',
                      trailing: _restoring ? const RowSpinner() : null,
                      showChevron: !_restoring,
                      onTap: busy ? null : _restore,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    '数据只保存在本机。换手机或卸载前先导出备份，存到网盘或电脑上。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: colors.inactive,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionLabel('关于'),
                const AboutCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
