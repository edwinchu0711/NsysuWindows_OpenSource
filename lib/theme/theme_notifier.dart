import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModeKey = 'app_theme_mode'; // 'light' | 'dark'

/// 全域主題通知器，用 SharedPreferences 持久化設定
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier._() : super(ThemeMode.light);

  static final ThemeNotifier instance = ThemeNotifier._();

  /// 初始化：從 SharedPreferences 讀取上次儲存的主題
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    if (saved == 'dark') {
      value = ThemeMode.dark;
    } else {
      value = ThemeMode.light;
    }
  }

  /// 切換主題並持久化
  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  /// 快速判斷目前是否為深色
  bool get isDark => value == ThemeMode.dark;

  /// 切換（toggle）
  Future<void> toggle() async {
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
