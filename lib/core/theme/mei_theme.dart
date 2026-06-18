import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mei_colors.dart';
import 'mei_text_styles.dart';

/// Mei Convertor — Material 3 Theme Configuration
final class MeiTheme {
  const MeiTheme._();

  static ThemeData get light => _buildLightTheme();

  static ThemeData _buildLightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: MeiColors.sakuraDeep,
      onPrimary: MeiColors.white,
      primaryContainer: MeiColors.sakuraLighter,
      onPrimaryContainer: MeiColors.sakuraDeep,
      secondary: MeiColors.lavender,
      onSecondary: MeiColors.white,
      secondaryContainer: MeiColors.lavenderLighter,
      onSecondaryContainer: MeiColors.lavenderDark,
      tertiary: MeiColors.gray500,
      onTertiary: MeiColors.white,
      tertiaryContainer: MeiColors.gray100,
      onTertiaryContainer: MeiColors.gray700,
      error: MeiColors.error,
      onError: MeiColors.white,
      errorContainer: MeiColors.errorLight,
      onErrorContainer: MeiColors.error,
      surface: MeiColors.offWhite,
      onSurface: MeiColors.textPrimary,
      surfaceContainerHighest: MeiColors.surfaceVariant,
      onSurfaceVariant: MeiColors.textSecondary,
      outline: MeiColors.border,
      outlineVariant: MeiColors.divider,
      shadow: MeiColors.shadowMedium,
      scrim: Color(0x521C1A18),
      inverseSurface: MeiColors.gray800,
      onInverseSurface: MeiColors.offWhite,
      inversePrimary: MeiColors.sakuraLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MeiColors.offWhite,

      // Typography
      textTheme: const TextTheme(
        displayLarge: MeiTextStyles.displayLarge,
        displayMedium: MeiTextStyles.displayMedium,
        headlineLarge: MeiTextStyles.headlineLarge,
        headlineMedium: MeiTextStyles.headlineMedium,
        headlineSmall: MeiTextStyles.headlineSmall,
        titleLarge: MeiTextStyles.titleLarge,
        titleMedium: MeiTextStyles.titleMedium,
        titleSmall: MeiTextStyles.titleSmall,
        bodyLarge: MeiTextStyles.bodyLarge,
        bodyMedium: MeiTextStyles.bodyMedium,
        bodySmall: MeiTextStyles.bodySmall,
        labelLarge: MeiTextStyles.labelLarge,
        labelMedium: MeiTextStyles.labelMedium,
        labelSmall: MeiTextStyles.labelSmall,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: MeiColors.offWhite,
        foregroundColor: MeiColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: MeiTextStyles.headlineMedium,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(
          color: MeiColors.textPrimary,
          size: 22,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: MeiColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MeiColors.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MeiColors.sakuraDeep,
          foregroundColor: MeiColors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: MeiTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MeiColors.sakuraDeep,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: MeiTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MeiColors.textPrimary,
          side: const BorderSide(color: MeiColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: MeiTextStyles.labelLarge,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MeiColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MeiColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MeiColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MeiColors.sakuraDeep, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: MeiTextStyles.bodyMedium.copyWith(color: MeiColors.textTertiary),
        labelStyle: MeiTextStyles.bodyMedium.copyWith(color: MeiColors.textSecondary),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: MeiColors.gray100,
        selectedColor: MeiColors.sakuraLighter,
        disabledColor: MeiColors.gray100,
        labelStyle: MeiTextStyles.labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MeiColors.white,
        indicatorColor: MeiColors.sakuraLighter,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MeiTextStyles.labelSmall.copyWith(
              color: MeiColors.sakuraDark,
              fontWeight: FontWeight.w600,
            );
          }
          return MeiTextStyles.labelSmall.copyWith(
            color: MeiColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: MeiColors.sakuraDark, size: 22);
          }
          return const IconThemeData(color: MeiColors.gray400, size: 22);
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: MeiColors.divider,
        space: 1,
        thickness: 1,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MeiColors.gray800,
        contentTextStyle: MeiTextStyles.bodySmall.copyWith(color: MeiColors.offWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MeiColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: MeiColors.gray300,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: MeiColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: MeiTextStyles.headlineSmall,
        contentTextStyle: MeiTextStyles.bodyMedium.copyWith(color: MeiColors.textSecondary),
      ),

      // Switches and toggles
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return MeiColors.white;
          return MeiColors.gray300;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return MeiColors.sakuraDeep;
          return MeiColors.gray200;
        }),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MeiColors.sakuraDeep,
        linearTrackColor: MeiColors.sakuraLighter,
        circularTrackColor: MeiColors.sakuraLighter,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: MeiColors.textPrimary,
        size: 22,
      ),
    );
  }
}
