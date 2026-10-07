import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../profiles/presentation/profile_theme.dart';
import 'drug_list_screen.dart';

/// 「药品」分区：从药品列表里单选，标题右侧进药品列表维护。再点一次已选的取消。
class DrugChoiceField extends StatelessWidget {
  const DrugChoiceField({
    super.key,
    required this.profileId,
    required this.names,
    required this.selected,
    required this.onChanged,
  });

  final String profileId;
  final List<String> names;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSectionLabel(
          '药品',
          trailing: FormLinkButton(
            label: '管理药品',
            icon: FLucideIcons.pill,
            onTap: () => Navigator.of(context).push(
              profileRoute<void>(
                profileId,
                (_) => DrugListScreen(profileId: profileId),
              ),
            ),
          ),
        ),
        if (names.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '还没有药品',
              style: TextStyle(fontSize: 13.5, color: context.colors.inactive),
            ),
          )
        else
          ChoiceChips(
            labels: names,
            selected: selected,
            onTap: (name) => onChanged(name == selected ? null : name),
          ),
      ],
    );
  }
}
