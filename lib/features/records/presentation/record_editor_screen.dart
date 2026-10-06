import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../application/record_service.dart';
import 'record_detail_screen.dart';
import 'record_widgets.dart';

class RecordEditorScreen extends ConsumerStatefulWidget {
  const RecordEditorScreen({super.key, required this.profileId, this.bundle});

  final String profileId;

  /// null 表示新建。
  final RecordBundle? bundle;

  @override
  ConsumerState<RecordEditorScreen> createState() => _RecordEditorScreenState();
}

/// 编辑器里的一行指标。三个输入框各一个 controller。
class _IndicatorRowState {
  _IndicatorRowState({String name = '', String value = '', String unit = ''})
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value),
      unit = TextEditingController(text: unit);

  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController unit;

  bool get isBlank =>
      name.text.trim().isEmpty &&
      value.text.trim().isEmpty &&
      unit.text.trim().isEmpty;

  void dispose() {
    name.dispose();
    value.dispose();
    unit.dispose();
  }
}

class _RecordEditorScreenState extends ConsumerState<RecordEditorScreen> {
  final _picker = ImagePicker();

  late RecordKind _kind;
  late DateTime _date;
  late final TextEditingController _hospital;
  late final TextEditingController _content;
  final Map<String, TextEditingController> _fields = {};
  final List<_IndicatorRowState> _indicators = [];
  late final List<AttachmentEntry> _kept;
  final List<PendingAttachment> _pending = [];

  /// 本档案已有的指标，供快捷添加和自动补单位。
  List<IndicatorEntry> _knownIndicators = const [];
  bool _saving = false;

  bool get _editing => widget.bundle != null;

  @override
  void initState() {
    super.initState();
    final bundle = widget.bundle;
    final record = bundle?.record;
    _kind = record?.recordKind ?? RecordKind.visit;
    _date = record == null
        ? dateOnly(DateTime.now())
        : dateFromKey(record.date);
    _hospital = TextEditingController(text: record?.hospital ?? '');
    _content = TextEditingController(text: record?.content ?? '');
    for (final entry
        in bundle?.fields.entries ?? const <MapEntry<String, String>>[]) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    for (final item in bundle?.indicators ?? const <RecordIndicator>[]) {
      _indicators.add(
        _IndicatorRowState(
          name: item.indicator.name,
          value: formatNumber(item.value.value),
          unit: item.indicator.unit,
        ),
      );
    }
    _kept = [...?bundle?.attachments];
    _loadKnownIndicators();
  }

  Future<void> _loadKnownIndicators() async {
    final list = await ref
        .read(databaseProvider)
        .indicatorList(widget.profileId);
    if (mounted) setState(() => _knownIndicators = list);
  }

  @override
  void dispose() {
    _hospital.dispose();
    _content.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final row in _indicators) {
      row.dispose();
    }
    super.dispose();
  }

  TextEditingController _fieldController(String fieldId) =>
      _fields.putIfAbsent(fieldId, TextEditingController.new);

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
    if (mounted) {
      showAppToast(context, message: '已添加「$name」', description: '所有记录都会有这一项');
    }
  }

  // ------------------------------------------------------------------ 指标

  void _addIndicator([IndicatorEntry? known]) {
    setState(
      () => _indicators.add(
        _IndicatorRowState(name: known?.name ?? '', unit: known?.unit ?? ''),
      ),
    );
  }

  void _removeIndicator(int index) {
    setState(() => _indicators.removeAt(index).dispose());
  }

  /// 名字填成一个已有指标时，单位还空着就带出来。
  ///
  /// 同时刷新快捷添加区：已经填进来的指标不该再出现在那里。
  void _onIndicatorNameChanged(_IndicatorRowState row, String name) {
    setState(() {});
    if (row.unit.text.trim().isNotEmpty) return;
    final match = _knownIndicators
        .where((item) => item.name == name.trim())
        .firstOrNull;
    if (match != null && match.unit.isNotEmpty) row.unit.text = match.unit;
  }

  // ------------------------------------------------------------------ 附件

  Future<void> _pickImages(ImageSource source) async {
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final shot = await _picker.pickImage(source: source);
        picked = shot == null ? const [] : [shot];
      } else {
        picked = await _picker.pickMultiImage();
      }
      if (picked.isEmpty || !mounted) return;
      setState(() {
        for (final file in picked) {
          _pending.add(
            PendingAttachment(
              kind: AttachmentKind.image,
              sourcePath: file.path,
              name: file.name,
            ),
          );
        }
      });
    } on Exception catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        message: source == ImageSource.camera ? '无法打开相机' : '无法打开相册',
        description: '$error',
        level: AppToastLevel.error,
      );
    }
  }

  Future<void> _pickPdf() async {
    const typeGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    try {
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isEmpty || !mounted) return;
      setState(() {
        for (final file in files) {
          _pending.add(
            PendingAttachment(
              kind: AttachmentKind.pdf,
              sourcePath: file.path,
              name: file.name.isEmpty ? p.basename(file.path) : file.name,
            ),
          );
        }
      });
    } on Exception catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        message: '无法选择文件',
        description: '$error',
        level: AppToastLevel.error,
      );
    }
  }

  // ------------------------------------------------------------------ 保存

  /// 校验并收集指标；有问题时弹提示并返回 null。
  List<IndicatorInput>? _collectIndicators() {
    final result = <IndicatorInput>[];
    final names = <String>{};
    for (final row in _indicators) {
      if (row.isBlank) continue;
      final name = row.name.text.trim();
      if (name.isEmpty) {
        _error('有一行指标没填名称');
        return null;
      }
      final value = parseNumber(row.value.text);
      if (value == null) {
        _error('「$name」的数值不是数字', '非数字的结果请写在内容里');
        return null;
      }
      if (!names.add(name)) {
        _error('「$name」填了两次');
        return null;
      }
      result.add(
        IndicatorInput(name: name, value: value, unit: row.unit.text.trim()),
      );
    }
    return result;
  }

  void _error(String message, [String? description]) {
    showAppToast(
      context,
      message: message,
      description: description,
      level: AppToastLevel.error,
    );
  }

  Future<void> _save() async {
    final indicators = _collectIndicators();
    if (indicators == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(recordServiceProvider)
          .save(
            RecordDraft(
              id: widget.bundle?.record.id,
              profileId: widget.profileId,
              kind: _kind,
              date: dateKey(_date),
              hospital: _hospital.text.trim(),
              content: _content.text.trim(),
              fields: {
                for (final entry in _fields.entries)
                  entry.key: entry.value.text,
              },
              indicators: indicators,
              keptAttachments: _kept,
              newAttachments: _pending,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _error('保存失败', '$error');
    }
  }

  // ------------------------------------------------------------------ 界面

  @override
  Widget build(BuildContext context) {
    final fieldDefs = ref.watch(fieldDefsProvider).value ?? const [];
    final bottom = MediaQuery.paddingOf(context).bottom;
    final usedNames = _indicators.map((row) => row.name.text.trim()).toSet();
    final quickIndicators = _knownIndicators
        .where((item) => !usedNames.contains(item.name))
        .toList();

    return Scaffold(
      body: AppTopBar(
        title: _editing ? '编辑记录' : '新建记录',
        actions: [
          AppHeaderAction(
            icon: FLucideIcons.check,
            tooltip: '保存',
            onTap: _saving ? null : _save,
          ),
        ],
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
            sliver: SliverList.list(
              children: [
                AppTabs<RecordKind>(
                  values: RecordKind.values,
                  labelOf: (kind) => kind.label,
                  selected: _kind,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                const SizedBox(height: 18),
                DateField(
                  value: _date,
                  onChanged: (value) => setState(() => _date = value),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _hospital,
                  label: Text(_kind == RecordKind.checkup ? '体检机构' : '医院 / 医生'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _content,
                  label: const Text('内容'),
                  multiline: true,
                  minLines: 4,
                  maxLines: 14,
                ),
                for (final def in fieldDefs) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _fieldController(def.id),
                    label: Text(def.name),
                    multiline: true,
                    minLines: 1,
                    maxLines: 6,
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FormLinkButton(label: '添加字段', onTap: _addField),
                ),
                const SizedBox(height: 16),
                FormSectionLabel(
                  '指标',
                  trailing: FormLinkButton(
                    label: '新指标',
                    onTap: () => _addIndicator(),
                  ),
                ),
                for (var i = 0; i < _indicators.length; i++)
                  _IndicatorInputRow(
                    key: ObjectKey(_indicators[i]),
                    row: _indicators[i],
                    onNameChanged: (name) =>
                        _onIndicatorNameChanged(_indicators[i], name),
                    onRemove: () => _removeIndicator(i),
                  ),
                if (quickIndicators.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in quickIndicators)
                        AppChip(
                          label: item.name,
                          icon: FLucideIcons.plus,
                          onTap: () => _addIndicator(item),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const FormSectionLabel('附件'),
                if (_kept.isNotEmpty || _pending.isNotEmpty) ...[
                  _AttachmentEditor(
                    kept: _kept,
                    pending: _pending,
                    onRemoveKept: (item) => setState(() => _kept.remove(item)),
                    onRemovePending: (item) =>
                        setState(() => _pending.remove(item)),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppChip(
                      label: '拍照',
                      icon: FLucideIcons.camera,
                      onTap: () => _pickImages(ImageSource.camera),
                    ),
                    AppChip(
                      label: '相册',
                      icon: FLucideIcons.image,
                      onTap: () => _pickImages(ImageSource.gallery),
                    ),
                    AppChip(
                      label: 'PDF',
                      icon: FLucideIcons.fileText,
                      onTap: _pickPdf,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                BottomActionButton(
                  label: '保存',
                  busy: _saving,
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

class _IndicatorInputRow extends StatelessWidget {
  const _IndicatorInputRow({
    super.key,
    required this.row,
    required this.onNameChanged,
    required this.onRemove,
  });

  final _IndicatorRowState row;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: AppTextField(
              controller: row.name,
              hint: '名称',
              onChange: onNameChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: AppTextField(
              controller: row.value,
              hint: '数值',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: AppTextField(controller: row.unit, hint: '单位'),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              icon: Icon(FLucideIcons.x, size: 18, color: context.colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentEditor extends StatelessWidget {
  const _AttachmentEditor({
    required this.kept,
    required this.pending,
    required this.onRemoveKept,
    required this.onRemovePending,
  });

  final List<AttachmentEntry> kept;
  final List<PendingAttachment> pending;
  final ValueChanged<AttachmentEntry> onRemoveKept;
  final ValueChanged<PendingAttachment> onRemovePending;

  @override
  Widget build(BuildContext context) {
    final keptImages = kept.where((a) => a.kind == AttachmentKind.image.index);
    final keptPdfs = kept.where((a) => a.kind == AttachmentKind.pdf.index);
    final pendingImages = pending.where((a) => a.kind == AttachmentKind.image);
    final pendingPdfs = pending.where((a) => a.kind == AttachmentKind.pdf);
    final hasImages = keptImages.isNotEmpty || pendingImages.isNotEmpty;
    final hasPdfs = keptPdfs.isNotEmpty || pendingPdfs.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImages)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in keptImages)
                _RemovableThumb(
                  onRemove: () => onRemoveKept(item),
                  child: LocalThumbnail(
                    relativePath: item.thumbnailPath ?? item.path,
                    size: 76,
                  ),
                ),
              for (final item in pendingImages)
                _RemovableThumb(
                  onRemove: () => onRemovePending(item),
                  child: ClipRRect(
                    borderRadius: context.radii.blockAll,
                    child: Image.file(
                      File(item.sourcePath),
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      cacheWidth: 240,
                    ),
                  ),
                ),
            ],
          ),
        if (hasImages && hasPdfs) const SizedBox(height: 10),
        for (final item in keptPdfs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PdfTile(
              name: item.name,
              sizeBytes: item.sizeBytes,
              onTap: () => openStoredPdf(context, item.path),
              onRemove: () => onRemoveKept(item),
            ),
          ),
        for (final item in pendingPdfs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PdfTile(
              name: item.name,
              onTap: null,
              onRemove: () => onRemovePending(item),
            ),
          ),
      ],
    );
  }
}

class _RemovableThumb extends StatelessWidget {
  const _RemovableThumb({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xCC000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(FLucideIcons.x, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
