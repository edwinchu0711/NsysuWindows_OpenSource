import 'package:flutter/material.dart';

/// 全域應用主題定義
class AppTheme {
  AppTheme._();

  // ── 淺色主題 ──────────────────────────────────────────

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF2196F3),
      primaryContainer: Color(0xFFE3F2FD),
      secondary: Color(0xFF03A9F4),
      surface: Colors.white,
      onSurface: Color(0xFF1A1A1A),
      onPrimary: Colors.white,
    );

    return _buildTheme(colorScheme);
  }

  // ── 深色主題 ──────────────────────────────────────────

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF6B9BF5),
      primaryContainer: Color(0xFF1E2D4A),
      secondary: Color(0xFF4FC3F7),
      surface: Color(0xFF1E2432),
      onSurface: Color(0xFFE8EAF0),
      onPrimary: Colors.white,
    );

    return _buildTheme(colorScheme);
  }

  // ── 共用 ThemeData 構建器 ─────────────────────────────

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: false,
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF151A26) : const Color(0xFFFAFAFA), // Colors.grey[50]
      cardColor: colorScheme.surface,

      // 取消水波紋（與原有設定一致）
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,

      // Divider
      dividerColor: isDark ? Colors.white12 : Colors.black12,
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.black12,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E2432) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2432) : Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A),
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: isDark ? const Color(0xFFB0B8C8) : const Color(0xFF555555),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey[700],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF6B9BF5) : const Color(0xFF2196F3)),
        ),
        fillColor: isDark ? const Color(0xFF252B3B) : Colors.grey[100],
        filled: false,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2E3547) : const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withOpacity(0.5);
          }
          return isDark ? Colors.white24 : null;
        }),
      ),

      // DropdownMenu
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            isDark ? const Color(0xFF252B3B) : Colors.white,
          ),
        ),
      ),

      // Icon
      iconTheme: IconThemeData(
        color: isDark ? const Color(0xFFB0B8C8) : Colors.grey[700],
      ),

      // TextTheme
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: isDark ? const Color(0xFFB0B8C8) : const Color(0xFF555555)),
        bodySmall: TextStyle(color: isDark ? const Color(0xFF8890A8) : Colors.grey[600]),
        titleLarge: TextStyle(color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A)),
      ),

      // 按鈕主題（游標）
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          mouseCursor: WidgetStateProperty.resolveWith<MouseCursor?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return SystemMouseCursors.basic;
              }
              return SystemMouseCursors.click;
            },
          ),
        ),
      ),

      // 頁面轉場動畫（與原有設定一致）
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ── 主題語義顏色擴展 ──────────────────────────────────────

extension AppColors on ColorScheme {
  bool get isDark => brightness == Brightness.dark;

  /// 頁面背景色（淺色對齊原始 Colors.grey[50] = #FAFAFA）
  Color get pageBackground =>
      isDark ? const Color(0xFF151A26) : const Color(0xFFFAFAFA);

  /// 卡片 / 白色區塊背景
  Color get cardBackground =>
      isDark ? const Color(0xFF1E2432) : Colors.white;

  /// 次要卡片 / 下拉選單 / Input 背景（淺色對齊原始 Colors.grey[50]/[100]）
  Color get secondaryCardBackground =>
      isDark ? const Color(0xFF252B3B) : const Color(0xFFFAFAFA);

  /// 主要文字顏色（淺色對齊原始 Colors.black87 = #DE000000）
  Color get primaryText =>
      isDark ? const Color(0xFFE8EAF0) : Colors.black87;

  /// 次要文字（說明、subtitle）（淺色對齊原始 Colors.grey[600]）
  Color get subtitleText =>
      isDark ? const Color(0xFF8890A8) : Colors.grey.shade600;

  /// 中間文字（label, normal body）（淺色對齊原始 Colors.grey[700]~[800]）
  Color get bodyText =>
      isDark ? const Color(0xFFB0B8C8) : Colors.grey.shade700;

  /// 分隔線 / Border 色
  Color get borderColor =>
      isDark ? Colors.white12 : Colors.grey.shade200;

  /// Header 背景（白色 Header bar）
  Color get headerBackground =>
      isDark ? const Color(0xFF1E2432) : Colors.white;

  /// Scaffold 背景（與 pageBackground 相同，方便存取）
  Color get scaffoldBackground =>
      isDark ? const Color(0xFF151A26) : const Color(0xFFF8F9FA);

  /// 淡色 overlay（用於 ListView 行 hover、info box 等）
  Color get subtleBackground =>
      isDark ? const Color(0xFF252B3B) : Colors.grey.shade100;

  /// 表格標頭背景（原 _paleBlueColor = #F4F8FF）
  Color get timetableHeader =>
      isDark ? const Color(0xFF2D3548) : const Color(0xFFF4F8FF);

  /// 表格時段索引背景（側邊時段欄）
  Color get timetableSlot =>
      isDark ? const Color(0xFF252B3B) : const Color(0xFFF4F8FF);

  /// 成功狀態背景（例如：系統開放、加選成功）
  Color get successContainer =>
      isDark ? const Color(0xFF1B3921) : const Color(0xFFE8F5E9);

  /// 警告/提醒狀態背景（例如：非選課時段、異常處理）
  Color get warningContainer =>
      isDark ? const Color(0xFF3E2D1A) : const Color(0xFFFFF3E0);

  /// Icon 顏色（非強調）
  Color get iconColor =>
      isDark ? const Color(0xFFB0B8C8) : Colors.grey.shade600;

  /// 強調色（藍色）（淺色對齊原始 Colors.blue[700]）
  Color get accentBlue =>
      isDark ? const Color(0xFF6B9BF5) : Colors.blue.shade700;
}
