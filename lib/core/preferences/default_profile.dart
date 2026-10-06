import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 打开应用时直接进入的档案 id；null 表示停在档案列表。
///
/// 只存在本机，不进备份：「这台手机主要看谁的档案」是设备习惯，不是数据。
/// 指向的档案被删掉或恢复的备份里没有它时，启动照常停在列表。
const _prefsKey = 'default_profile_id';

String? readDefaultProfileId(SharedPreferences prefs) =>
    prefs.getString(_prefsKey);

class DefaultProfileController extends Notifier<String?> {
  DefaultProfileController() : _seed = null;

  /// 用 `main.dart` 在 runApp 之前读好的值构造：启动跳转要在第一帧就知道去哪。
  DefaultProfileController.seeded(String? seed) : _seed = seed;

  final String? _seed;

  @override
  String? build() => _seed;

  Future<void> set(String? profileId) async {
    state = profileId;
    final prefs = await SharedPreferences.getInstance();
    if (profileId == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, profileId);
    }
  }
}

final defaultProfileProvider =
    NotifierProvider<DefaultProfileController, String?>(
      DefaultProfileController.new,
    );
