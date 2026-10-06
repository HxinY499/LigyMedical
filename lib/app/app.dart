import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../core/appearance/appearance.dart';
import '../core/preferences/default_profile.dart';
import '../core/theme/app_theme.dart';
import '../core/update/update_banner.dart';
import '../features/profiles/presentation/profile_screen.dart';
import '../features/profiles/presentation/profiles_screen.dart';
import '../features/profiles/presentation/profile_theme.dart';

class LigyMedicalApp extends ConsumerWidget {
  const LigyMedicalApp({super.key});

  /// 首页挂着更新提示层：启动检查在这里发起，发现新版本从这里弹浮层。
  /// 启动档案压在它上面时浮层照样弹在最顶层。
  static const _home = UpdateNotificationLayer(child: ProfilesScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appearanceProvider);
    return MaterialApp(
      title: '健康档案',
      debugShowCheckedModeBanner: false,
      theme: buildMaterialTheme(Brightness.light, config),
      darkTheme: buildMaterialTheme(Brightness.dark, config),
      themeMode: config.themeMode.materialMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        FLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => _ThemedShell(config: config, child: child!),
      // 设了启动档案时，初始栈直接是「列表 + 档案」两层：第一帧就是档案页，
      // 不会先闪一下列表再滑进去，返回仍回到列表。只在启动时读一次。
      // 与 `home` 互斥，所以首页也在这里给出。
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _home),
      onGenerateInitialRoutes: (_) {
        final profileId = ref.read(defaultProfileProvider);
        return [
          MaterialPageRoute<void>(builder: (_) => _home),
          if (profileId != null)
            profileRoute<void>(
              profileId,
              (_) => ProfileScreen(profileId: profileId),
            ),
        ];
      },
    );
  }
}

/// 把 Material 主题解析出的亮度接到 forui、系统状态栏与字号上。
///
/// 必须是 MaterialApp 的**子级**：`themeMode.system` 下真正生效的亮度
/// 只有在它下面 `Theme.of(context)` 才拿得到。
class _ThemedShell extends StatelessWidget {
  const _ThemedShell({required this.config, required this.child});

  final AppearanceConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.systemOverlayStyle,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: _DensityTextScaler(
            media.textScaler,
            config.density.textScale,
          ),
        ),
        child: FTheme(
          data: foruiThemeFor(colors.brightness, config),
          child: FToaster(child: child),
        ),
      ),
    );
  }
}

/// 在系统字号之上再乘一个应用自己的密度倍率，不吃掉用户的系统字号设置。
class _DensityTextScaler extends TextScaler {
  const _DensityTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize * factor);

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _DensityTextScaler &&
          other.base == base &&
          other.factor == factor);

  @override
  int get hashCode => Object.hash(base, factor);
}
