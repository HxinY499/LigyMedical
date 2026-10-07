import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../application/injection_service.dart';
import 'injection_photo_field.dart';

/// 新建 / 编辑一个药品：名称与照片（药盒、说明书等）。
class DrugEditorScreen extends ConsumerStatefulWidget {
  const DrugEditorScreen({super.key, required this.profileId, this.drug});

  final String profileId;

  /// null 表示新建。
  final DrugEntry? drug;

  @override
  ConsumerState<DrugEditorScreen> createState() => _DrugEditorScreenState();
}

class _DrugEditorScreenState extends ConsumerState<DrugEditorScreen> {
  late final String _id = widget.drug?.id ?? const Uuid().v4();
  late final _name = TextEditingController(text: widget.drug?.name ?? '');

  /// 已保存的照片。编辑时要等读出来才能保存，否则会把它们当成被删掉。
  List<InjectionPhotoEntry>? _kept;
  final List<String> _pending = [];
  bool _saving = false;

  bool get _editing => widget.drug != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _loadPhotos();
    } else {
      _kept = [];
    }
  }

  Future<void> _loadPhotos() async {
    final photos = await ref.read(databaseProvider).photoList(drugId: _id);
    if (mounted) setState(() => _kept = [...photos]);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kept = _kept;
    final name = _name.text.trim();
    if (kept == null) return;
    if (name.isEmpty) {
      showAppToast(context, message: '药品名称不能为空', level: AppToastLevel.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(injectionServiceProvider)
          .saveDrug(
            DrugDraft(
              id: _id,
              profileId: widget.profileId,
              name: name,
              keptPhotos: kept,
              newPhotoPaths: _pending,
            ),
          );
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _saving = false);
      showAppToast(context, message: '已有药品「$name」', level: AppToastLevel.error);
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
    final confirmed = await showAppConfirmDialog(
      context,
      message: '删除这个药品？\n它的照片会一起删除；已有的注射记录不受影响。',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) return;
    await ref.read(injectionServiceProvider).deleteDrug(_id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final kept = _kept;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppTopBar(
        title: _editing ? '编辑药品' : '添加药品',
        actions: [
          if (_editing)
            AppHeaderAction(
              icon: FLucideIcons.trash2,
              tooltip: '删除',
              onTap: _delete,
            ),
        ],
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
            sliver: SliverList.list(
              children: [
                AppTextField(controller: _name, label: const Text('名称')),
                if (kept != null) ...[
                  const SizedBox(height: 20),
                  InjectionPhotoField(
                    label: '照片',
                    kept: kept,
                    pending: _pending,
                    onRemoveKept: (photo) => setState(() => kept.remove(photo)),
                    onRemovePending: (path) =>
                        setState(() => _pending.remove(path)),
                    onPicked: (paths) => setState(() => _pending.addAll(paths)),
                  ),
                ],
                const SizedBox(height: 28),
                BottomActionButton(
                  label: '保存',
                  busy: _saving || kept == null,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
