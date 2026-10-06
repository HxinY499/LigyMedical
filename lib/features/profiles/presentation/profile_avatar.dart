import 'package:flutter/material.dart';

/// 档案可选的标识色。顺序即存库下标，只能往后追加。
const kProfileColors = [
  Color(0xFF5190F2),
  Color(0xFFE5795F),
  Color(0xFF3FAE8C),
  Color(0xFFE5A62E),
  Color(0xFF9B7BE0),
  Color(0xFFE06C9F),
  Color(0xFF4DB3C7),
  Color(0xFF7D8C88),
];

Color profileColor(int index) =>
    kProfileColors[index.clamp(0, kProfileColors.length - 1)];

/// 头像：标识色实底圆角方块 + 白色首字（英文转大写）。
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
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: profileColor(colorIndex),
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
          color: Colors.white,
        ),
      ),
    );
  }
}
