import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/appearance/appearance.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import 'profile_avatar.dart';

/// 把档案的标识色设为子树的主题色：按钮、选中态、悬浮按钮、图表都跟着变。
///
/// 深浅、圆角、密度等其余外观照用全局设置，只换强调色。Material 主题与 forui
/// 主题要一起换，否则 forui 的按钮、输入框还是全局那支颜色。
/// 弹窗和底部浮层会从打开它的位置捕获主题，所以档案页里弹出的日期选择也跟着变。
class ProfileTheme extends ConsumerWidget {
  const ProfileTheme({
    super.key,
    required this.colorIndex,
    required this.child,
  });

  final int colorIndex;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref
        .watch(appearanceProvider)
        .copyWith(accent: profileAccent(colorIndex));
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: buildMaterialTheme(brightness, config),
      child: FTheme(data: foruiThemeFor(brightness, config), child: child),
    );
  }
}

/// 按档案 id 取标识色再套 [ProfileTheme]。档案改了颜色，已打开的页面立即跟着变。
class ProfileThemeScope extends ConsumerWidget {
  const ProfileThemeScope({
    super.key,
    required this.profileId,
    required this.child,
  });

  final String profileId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(profileId)).value;
    if (profile == null) return child;
    return ProfileTheme(colorIndex: profile.colorIndex, child: child);
  }
}

/// 打开属于某个档案的页面。页面整体包在该档案的主题里，页面内部不用关心颜色从哪来。
MaterialPageRoute<T> profileRoute<T>(String profileId, WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    builder: (_) => ProfileThemeScope(
      profileId: profileId,
      // Builder 让页面拿到的 context 在主题之下。
      child: Builder(builder: builder),
    ),
  );
}
