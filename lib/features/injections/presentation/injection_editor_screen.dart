import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../application/injection_service.dart';
import 'drug_choice_field.dart';
import 'injection_photo_field.dart';

class InjectionEditorScreen extends ConsumerStatefulWidget {
  const InjectionEditorScreen({
    super.key,
    required this.profileId,
    this.entry,
    this.initialDate,
  });

  final String profileId;

  /// null 表示新建。
  final InjectionEntry? entry;

  /// 新建时的默认日期（日历上点空白日补记）。
  final DateTime? initialDate;

  @override
  ConsumerState<InjectionEditorScreen> createState() =>
      _InjectionEditorScreenState();
}

class _InjectionEditorScreenState extends ConsumerState<InjectionEditorScreen> {
  late final String _id = widget.entry?.id ?? const Uuid().v4();
  late DateTime _date;
  String? _drug;
  late final TextEditingController _place;
  late final TextEditingController _note;
  String? _site;
  List<String> _recentPlaces = const [];

  /// 已保存的照片。编辑时要等读出来才能保存，否则会把它们当成被删掉。
  List<InjectionPhotoEntry>? _kept;
  final List<String> _pending = [];

  /// 新建时默认选计划的药品，要等计划和药品列表读出来才填得上，只填一次。
  bool _seeded = false;
  bool _saving = false;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _date = entry != null
        ? dateFromKey(entry.date)
        : dateOnly(widget.initialDate ?? DateTime.now());
    _drug = entry?.drug.isEmpty ?? true ? null : entry!.drug;
    _place = TextEditingController(text: entry?.place ?? '');
    _note = TextEditingController(text: entry?.note ?? '');
    _site = entry?.site.isEmpty ?? true ? null : entry!.site;
    _seeded = _editing;
    _loadRecentPlaces();
    if (_editing) {
      _loadPhotos();
    } else {
      _kept = [];
    }
  }

  Future<void> _loadRecentPlaces() async {
    final places = await ref
        .read(databaseProvider)
        .recentInjectionPlaces(widget.profileId);
    if (mounted) setState(() => _recentPlaces = places);
  }

  Future<void> _loadPhotos() async {
    final photos = await ref.read(databaseProvider).photoList(injectionId: _id);
    if (mounted) setState(() => _kept = [...photos]);
  }

  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  void _seedDefaults(InjectionPlanEntry? plan, List<DrugEntry> drugs) {
    if (_seeded) return;
    _seeded = true;
    _drug = drugs.where((drug) => drug.id == plan?.drugId).firstOrNull?.name;
  }

  Future<void> _save() async {
    final kept = _kept;
    if (kept == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(injectionServiceProvider)
          .saveInjection(
            InjectionDraft(
              id: _id,
              profileId: widget.profileId,
              date: dateKey(_date),
              drug: _drug ?? '',
              site: _site ?? '',
              place: _place.text.trim(),
              note: _note.text.trim(),
              keptPhotos: kept,
              newPhotoPaths: _pending,
            ),
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
    final confirmed = await showAppConfirmDialog(
      context,
      message: '删除这条注射记录？',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) return;
    await ref.read(injectionServiceProvider).deleteInjection(_id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(injectionPlanProvider(widget.profileId));
    final drugs = ref.watch(drugsProvider(widget.profileId)).value;
    final plan = planAsync.value;
    final sites = plan?.siteList ?? splitSites(kDefaultInjectionSites);
    if (!planAsync.isLoading && drugs != null) {
      _seedDefaults(plan, drugs);
    }
    // 记录里的部位 / 药品不在当前列表里（改过计划、药品改名或删了）时也要能看到并保留它。
    final siteOptions = [
      ...sites,
      if (_site != null && !sites.contains(_site)) _site!,
    ];
    final drugNames = [
      for (final drug in drugs ?? const <DrugEntry>[]) drug.name,
    ];
    final drugOptions = [
      ...drugNames,
      if (_drug != null && !drugNames.contains(_drug)) _drug!,
    ];
    final kept = _kept;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: AppTopBar(
        title: _editing ? '编辑注射' : '记录注射',
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
                DateField(
                  value: _date,
                  onChanged: (value) => setState(() => _date = value),
                ),
                const SizedBox(height: 20),
                DrugChoiceField(
                  profileId: widget.profileId,
                  names: drugOptions,
                  selected: _drug,
                  onChanged: (name) => setState(() => _drug = name),
                ),
                const SizedBox(height: 20),
                const FormSectionLabel('部位'),
                ChoiceChips(
                  labels: siteOptions,
                  selected: _site,
                  onTap: (site) =>
                      setState(() => _site = _site == site ? null : site),
                ),
                const SizedBox(height: 20),
                AppTextField(controller: _place, label: const Text('地点 / 执行人')),
                if (_recentPlaces.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: _place,
                    builder: (context, _) => ChoiceChips(
                      labels: _recentPlaces,
                      selected: _place.text.trim(),
                      onTap: (place) => _place.text = place,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  controller: _note,
                  label: const Text('备注'),
                  multiline: true,
                  minLines: 2,
                  maxLines: 6,
                ),
                if (kept != null) ...[
                  const SizedBox(height: 24),
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
