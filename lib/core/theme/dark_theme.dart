import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class DarkTheme {
  const DarkTheme._();

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryAlt,
      brightness: Brightness.dark,
      primary: AppColors.primaryAlt,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surfaceContainerHighest: AppColors.darkSurfaceMuted,
      outline: const Color(0xFF2E3F52),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: AppTypography.textTheme(AppColors.darkText),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.darkText,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        actionsIconTheme: const IconThemeData(color: AppColors.darkText),
        titleTextStyle: AppTypography.textTheme(AppColors.darkText).titleLarge,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: const Color(0xFF2E3F52), width: 0.5),
        ),
        shadowColor: AppColors.primaryAlt.withValues(alpha: 0.12),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceMuted,
        hintStyle: const TextStyle(color: AppColors.darkTextMuted),
        labelStyle: const TextStyle(color: AppColors.darkTextMuted),
        prefixIconColor: AppColors.darkTextMuted,
        suffixIconColor: AppColors.darkTextMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E3F52)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E3F52)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryAlt, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),

      // Dropdown menus
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.darkSurface),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppColors.darkSurfaceMuted,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: AppTypography.textTheme(AppColors.darkText).titleLarge,
        contentTextStyle: const TextStyle(color: AppColors.darkText),
        elevation: 8,
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        modalBackgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: Color(0xFF3E5068),
        elevation: 4,
      ),

      // Navigation rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface,
        unselectedIconTheme: const IconThemeData(color: AppColors.darkTextMuted),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.darkTextMuted),
        selectedIconTheme: const IconThemeData(color: AppColors.primaryAlt),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.primaryAlt,
          fontWeight: FontWeight.w700,
        ),
        indicatorColor: AppColors.primaryAlt.withValues(alpha: 0.15),
      ),

      // Bottom navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.primaryAlt.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryAlt);
          }
          return const IconThemeData(color: AppColors.darkTextMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: AppColors.primaryAlt, fontWeight: FontWeight.w700, fontSize: 11);
          }
          return const TextStyle(color: AppColors.darkTextMuted, fontSize: 11);
        }),
      ),

      // List tiles
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.darkText,
        iconColor: AppColors.darkTextMuted,
        tileColor: Colors.transparent,
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2E3F52),
        thickness: 0.5,
      ),

      // Icon
      iconTheme: const IconThemeData(color: AppColors.darkTextMuted),
      primaryIconTheme: const IconThemeData(color: AppColors.primaryAlt),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceMuted,
        labelStyle: const TextStyle(color: AppColors.darkText),
        iconTheme: const IconThemeData(color: AppColors.darkTextMuted),
        selectedColor: AppColors.primaryAlt.withValues(alpha: 0.2),
        side: const BorderSide(color: Color(0xFF2E3F52), width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryAlt;
          return AppColors.darkTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryAlt.withValues(alpha: 0.4);
          }
          return AppColors.darkSurfaceMuted;
        }),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E2F42),
        contentTextStyle: const TextStyle(color: AppColors.darkText),
        actionTextColor: AppColors.primaryAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Tooltips
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2F42),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2E3F52)),
        ),
        textStyle: const TextStyle(color: AppColors.darkText, fontSize: 12),
      ),

      // Elevated & filled buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primaryAlt,
          disabledForegroundColor: AppColors.darkTextMuted,
          disabledBackgroundColor: AppColors.darkSurfaceMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primaryAlt,
          disabledForegroundColor: AppColors.darkTextMuted,
          disabledBackgroundColor: AppColors.darkSurfaceMuted,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryAlt,
          side: const BorderSide(color: AppColors.primaryAlt),
          disabledForegroundColor: AppColors.darkTextMuted,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryAlt,
          disabledForegroundColor: AppColors.darkTextMuted,
        ),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryAlt,
        foregroundColor: Colors.white,
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryAlt,
        linearTrackColor: AppColors.darkSurfaceMuted,
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkSurface,
        textStyle: const TextStyle(color: AppColors.darkText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2E3F52), width: 0.5),
        ),
      ),
    );
  }
}
