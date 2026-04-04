import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModeKey = 'app_theme_mode'; // 'system' | 'light' | 'dark'

/// 全域主題通知器，用 SharedPreferences 持久化設定
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier._() : super(ThemeMode.system);

  static final ThemeNotifier instance = ThemeNotifier._();

  /// 初始化：從 SharedPreferences 讀取上次儲存的主題
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    if (saved == 'dark') {
      value = ThemeMode.dark;
    } else if (saved == 'light') {
      value = ThemeMode.light;
    } else {
      value = ThemeMode.system;
    }
  }

  /// 切換主題並持久化
  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    String modeStr;
    switch (mode) {
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }
    await prefs.setString(_kThemeModeKey, modeStr);
  }

  /// 快速判斷目前是否為深色 (不建議在有系統模式時使用，應優先使用 Theme.of(context).brightness)
  bool get isDark => value == ThemeMode.dark;

  /// 切換（toggle）僅在手動模式間切換
  Future<void> toggle() async {
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
