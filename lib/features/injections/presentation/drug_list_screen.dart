import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../profiles/presentation/profile_theme.dart';
import '../../records/presentation/record_widgets.dart';
import 'drug_editor_screen.dart';

/// 档案的药品列表。注射计划只能从这里选药品。
class DrugListScreen extends ConsumerWidget {
  const DrugListScreen({super.key, required this.profileId});

  final String profileId;

  void _open(BuildContext context, [DrugEntry? drug]) {
    Navigator.of(context).push(
      profileRoute<void>(
        profileId,
        (_) => DrugEditorScreen(profileId: profileId, drug: drug),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final drugs = ref.watch(drugsProvider(profileId)).value;
    final photos = ref.watch(injectionPhotosProvider(profileId)).value ?? [];
    final photosByDrug = <String, List<InjectionPhotoEntry>>{};
    for (final photo in photos) {
      final drugId = photo.drugId;
      if (drugId != null) photosByDrug.putIfAbsent(drugId, () => []).add(photo);
    }
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      floatingActionButton: AppFab(
        onPressed: () => _open(context),
        tooltip: '添加药品',
      ),
      body: AppTopBar(
        title: '药品',
        slivers: [
          if (drugs == null)
            const SliverToBoxAdapter()
          else if (drugs.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(icon: FLucideIcons.pill, title: '还没有药品'),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + bottom),
              sliver: SliverToBoxAdapter(
                child: SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final drug in drugs) ...[
                        if (drug != drugs.first)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            color: colors.lineSoft,
                          ),
                        _DrugRow(
                          drug: drug,
                          photos: photosByDrug[drug.id] ?? const [],
                          onTap: () => _open(context, drug),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrugRow extends StatelessWidget {
  const _DrugRow({
    required this.drug,
    required this.photos,
    required this.onTap,
  });

  final DrugEntry drug;
  final List<InjectionPhotoEntry> photos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            if (photos.isEmpty)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.fill,
                  borderRadius: context.radii.blockAll,
                ),
                child: Icon(FLucideIcons.pill, size: 18, color: colors.muted),
              )
            else
              LocalThumbnail(
                relativePath: photos.first.thumbnailPath,
                size: 40,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drug.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: colors.ink,
                    ),
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${photos.length} 张照片',
                      style: TextStyle(fontSize: 12.5, color: colors.inactive),
                    ),
                  ],
                ],
              ),
            ),
            Icon(FLucideIcons.chevronRight, size: 18, color: colors.faint),
          ],
        ),
      ),
    );
  }
}
