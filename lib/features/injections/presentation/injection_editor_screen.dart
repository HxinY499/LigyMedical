import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../application/injection_schedule.dart';

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
  late DateTime _date;
  late final TextEditingController _drug;
  late final TextEditingController _place;
  late final TextEditingController _note;
  String? _site;
  List<String> _recentPlaces = const [];

  /// 新建时的药品与部位默认值要等计划和历史读出来才填得上，只填一次。
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
    _drug = TextEditingController(text: entry?.drug ?? '');
    _place = TextEditingController(text: entry?.place ?? '');
    _note = TextEditingController(text: entry?.note ?? '');
    _site = entry?.site.isEmpty ?? true ? null : entry!.site;
    _seeded = _editing;
    _loadRecentPlaces();
  }

  Future<void> _loadRecentPlaces() async {
    final places = await ref
        .read(databaseProvider)
        .recentInjectionPlaces(widget.profileId);
    if (mounted) setState(() => _recentPlaces = places);
  }

  @override
  void dispose() {
    _drug.dispose();
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  void _seedDefaults(
    InjectionPlanEntry? plan,
    List<InjectionEntry> injections,
    List<String> sites,
  ) {
    if (_seeded) return;
    _seeded = true;
    final last = injections.firstOrNull;
    final drug = (plan?.drug ?? '').isNotEmpty ? plan!.drug : last?.drug ?? '';
    _drug.text = drug;
    _site = suggestSite(sites, last?.site);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseProvider)
          .saveInjection(
            id: widget.entry?.id ?? const Uuid().v4(),
            profileId: widget.profileId,
            date: dateKey(_date),
            drug: _drug.text.trim(),
            site: _site ?? '',
            place: _place.text.trim(),
            note: _note.text.trim(),
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
    await ref.read(databaseProvider).deleteInjection(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(injectionPlanProvider(widget.profileId));
    final injections = ref.watch(injectionsProvider(widget.profileId)).value;
    final plan = planAsync.value;
    final sites = plan?.siteList ?? splitSites(kDefaultInjectionSites);
    if (!planAsync.isLoading && injections != null) {
      _seedDefaults(plan, injections, sites);
    }
    final others = injections
        ?.where((entry) => entry.id != widget.entry?.id)
        .toList();
    final suggested = others == null
        ? null
        : suggestSite(sites, others.firstOrNull?.site);
    // 手填过不在轮换表里的部位（改过计划）时也要能看到并保留它。
    final siteOptions = [
      ...sites,
      if (_site != null && !sites.contains(_site)) _site!,
    ];
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
                const SizedBox(height: 16),
                AppTextField(controller: _drug, label: const Text('药品')),
                const SizedBox(height: 20),
                const FormSectionLabel('部位'),
                ChoiceChips(
                  labels: siteOptions,
                  selected: _site,
                  highlighted: suggested,
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
                const SizedBox(height: 28),
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
