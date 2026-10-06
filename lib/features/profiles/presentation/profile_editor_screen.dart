import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/preferences/default_profile.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/settings_widgets.dart';
import 'profile_avatar.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, this.profile});

  /// null 表示新建。
  final ProfileEntry? profile;

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  late int _colorIndex = widget.profile?.colorIndex ?? 0;
  late bool _injection = widget.profile?.injectionEnabled ?? false;
  bool _saving = false;

  bool get _editing => widget.profile != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppToast(context, message: '请填写称呼', level: AppToastLevel.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseProvider)
          .upsertProfile(
            id: widget.profile?.id ?? const Uuid().v4(),
            name: name,
            colorIndex: _colorIndex,
            injectionEnabled: _injection,
          );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        message: '保存失败',
        description: '$error',
        level: AppToastLevel.error,
      );
    }
  }

  Future<void> _delete() async {
    final profile = widget.profile!;
    final confirmed = await showAppConfirmDialog(
      context,
      message: '删除「${profile.name}」的档案？\n所有记录、指标和注射记录都会一起删除，无法恢复。',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) return;
    await ref.read(recordServiceProvider).deleteProfile(profile.id);
    if (ref.read(defaultProfileProvider) == profile.id) {
      await ref.read(defaultProfileProvider.notifier).set(null);
    }
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppTopBar(
        title: _editing ? '编辑档案' : '新建档案',
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
            sliver: SliverList.list(
              children: [
                Center(
                  child: ListenableBuilder(
                    listenable: _name,
                    builder: (context, _) => ProfileAvatar(
                      name: _name.text.trim(),
                      colorIndex: _colorIndex,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _name,
                  label: const Text('称呼'),
                  autofocus: !_editing,
                ),
                const SizedBox(height: 20),
                const FormSectionLabel('标识色'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < kProfileColors.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _colorIndex = i),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: kProfileColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _colorIndex
                                  ? colors.ink
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: i == _colorIndex
                              ? const Icon(
                                  FLucideIcons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const FormSectionLabel('模块'),
                SettingsCard(
                  children: [
                    SettingsItem(
                      icon: FLucideIcons.syringe,
                      title: '注射记录',
                      subtitle: '定期注射的药物，带列表和日历视图',
                      trailing: TrailingSwitch(
                        value: _injection,
                        onChange: (value) => setState(() => _injection = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                BottomActionButton(
                  label: '保存',
                  busy: _saving,
                  onPressed: _save,
                ),
                if (_editing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPress: _delete,
                      variant: AppButtonVariant.ghost,
                      child: Text(
                        '删除档案',
                        style: TextStyle(color: colors.danger),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
