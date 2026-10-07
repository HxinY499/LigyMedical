import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'drug_choice_field.dart';

/// 注射计划：药品（从药品列表里选）、间隔、常用部位、注意事项。
class InjectionPlanScreen extends ConsumerStatefulWidget {
  const InjectionPlanScreen({super.key, required this.profileId, this.plan});

  final String profileId;
  final InjectionPlanEntry? plan;

  @override
  ConsumerState<InjectionPlanScreen> createState() =>
      _InjectionPlanScreenState();
}

class _InjectionPlanScreenState extends ConsumerState<InjectionPlanScreen> {
  late String? _drugId = widget.plan?.drugId;
  late final _interval = TextEditingController(
    text: '${widget.plan?.intervalDays ?? 14}',
  );
  late final _note = TextEditingController(text: widget.plan?.note ?? '');
  late final List<String> _sites = [
    ...(widget.plan?.siteList ?? splitSites(kDefaultInjectionSites)),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _interval.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addSite() async {
    final site = await showAppInputDialog(
      context,
      title: '添加部位',
      confirmLabel: '添加',
    );
    if (site == null || _sites.contains(site)) return;
    setState(() => _sites.add(site));
  }

  Future<void> _save() async {
    final interval = int.tryParse(_interval.text.trim());
    if (interval == null || interval < 1 || interval > 365) {
      showAppToast(
        context,
        message: '间隔天数要填 1–365 的整数',
        level: AppToastLevel.error,
      );
      return;
    }
    // 选中的药品可能刚在药品列表里被删掉。
    final drugs = ref.read(drugsProvider(widget.profileId)).value ?? const [];
    final drugId = drugs.any((drug) => drug.id == _drugId) ? _drugId : null;
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseProvider)
          .saveInjectionPlan(
            profileId: widget.profileId,
            drugId: drugId,
            intervalDays: interval,
            sites: _sites,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final drugs = ref.watch(drugsProvider(widget.profileId)).value;
    final selectedName = drugs
        ?.where((drug) => drug.id == _drugId)
        .firstOrNull
        ?.name;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppTopBar(
        title: '注射计划',
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
            sliver: SliverList.list(
              children: [
                DrugChoiceField(
                  profileId: widget.profileId,
                  names: [
                    for (final drug in drugs ?? const <DrugEntry>[]) drug.name,
                  ],
                  selected: selectedName,
                  onChanged: (name) => setState(() {
                    _drugId = drugs
                        ?.where((drug) => drug.name == name)
                        .firstOrNull
                        ?.id;
                  }),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _interval,
                  label: const Text('间隔天数'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '下次注射 = 最近一次实际注射日期 + 间隔天数',
                    style: TextStyle(fontSize: 12, color: colors.inactive),
                  ),
                ),
                const SizedBox(height: 20),
                FormSectionLabel(
                  '常用部位（记录注射时可快速选择）',
                  trailing: FormLinkButton(label: '添加', onTap: _addSite),
                ),
                if (_sites.isNotEmpty)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (from, to) => setState(() {
                      _sites.insert(to, _sites.removeAt(from));
                    }),
                    children: [
                      for (var i = 0; i < _sites.length; i++)
                        _SiteRow(
                          key: ValueKey(_sites[i]),
                          index: i,
                          label: _sites[i],
                          onRemove: () => setState(() => _sites.removeAt(i)),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _note,
                  label: const Text('注意事项'),
                  multiline: true,
                  minLines: 2,
                  maxLines: 6,
                ),
                const SizedBox(height: 28),
                BottomActionButton(
                  label: '保存',
                  busy: _saving || drugs == null,
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

class _SiteRow extends StatelessWidget {
  const _SiteRow({
    super.key,
    required this.index,
    required this.label,
    required this.onRemove,
  });

  final int index;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        shape: context.radii.blockShape(side: BorderSide(color: colors.line)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    FLucideIcons.gripVertical,
                    size: 18,
                    color: colors.inactive,
                  ),
                ),
              ),
              Text(
                '${index + 1}.',
                style: TextStyle(fontSize: 14, color: colors.muted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: colors.ink),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(FLucideIcons.x, size: 18, color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
