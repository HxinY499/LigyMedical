import 'package:flutter/material.dart';

import '../../../core/theme/app_accent.dart';
import '../../../core/theme/app_theme.dart';

/// 档案可选的标识色，同时就是进入该档案后的主题色。顺序即存库下标，只能往后追加。
///
/// 全部取「能当主题色用」的颜色：LigyTally 的六个预设（浅 / 深两支分别为白底和深底
/// 挑过），再加两支按预设平均亮度钉住的自选色。不收黄色、灰色这类主色——
/// 黄底按钮压不住白字，灰色分不出选中态。
const kProfileAccents = [
  AccentChoice.preset(AppAccent.blue),
  AccentChoice.preset(AppAccent.orange),
  AccentChoice.preset(AppAccent.teal),
  AccentChoice.custom(hue: 140, saturation: 0.5),
  AccentChoice.preset(AppAccent.purple),
  AccentChoice.preset(AppAccent.pink),
  AccentChoice.preset(AppAccent.indigo),
  AccentChoice.custom(hue: 30, saturation: 0.6),
];

AccentChoice profileAccent(int index) =>
    kProfileAccents[index.clamp(0, kProfileAccents.length - 1)];

Color profileColor(int index, Brightness brightness) =>
    profileAccent(index).primaryOf(brightness);

/// 头像：标识色实底圆角方块 + 首字（英文转大写）。
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    this.size = 46,
  });

  final String name;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: profileColor(colorIndex, brightness),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          // 深色下主色被提亮，白字对比不够，与悬浮按钮同一条规则。
          color: context.colors.isDark
              ? context.colors.canvasBase
              : Colors.white,
        ),
      ),
    );
  }
}
