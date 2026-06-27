import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_provider.dart';
import '../core/theme/theme.dart';
import '../routing/app_router.dart';

/// Root application widget
class MeiConvertorApp extends ConsumerWidget {
  const MeiConvertorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Mei Converter',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: MeiTheme.light,
      themeMode: ThemeMode.light,

      // Router
      routerConfig: AppRouter.router,

      // Localizations
      locale: Locale(language.code),
      supportedLocales: AppLanguage.values.map((l) => Locale(l.code)),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: MeiColors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
