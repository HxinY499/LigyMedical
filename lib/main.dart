import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/appearance/appearance.dart';
import 'core/media/image_storage.dart';
import 'core/preferences/default_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 两件预热互不依赖，并发跑：
  // - support 目录：列表缩略图要靠它同步拼出文件路径，否则首帧会闪。
  // - 偏好：深浅色和启动档案必须在第一帧之前就位。
  final warmUp = ImageStorage.warmUp();
  final prefs = await _loadPrefs();
  await warmUp;
  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) ...[
          appearanceProvider.overrideWith(
            () => AppearanceController.seeded(prefs.appearance),
          ),
          defaultProfileProvider.overrideWith(
            () => DefaultProfileController.seeded(prefs.defaultProfileId),
          ),
        ],
      ],
      child: const LigyMedicalApp(),
    ),
  );
}

Future<({AppearanceConfig appearance, String? defaultProfileId})?>
_loadPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return (
      appearance: await loadAppearanceConfig(prefs),
      defaultProfileId: readDefaultProfileId(prefs),
    );
  } on Exception {
    return null;
  }
}
