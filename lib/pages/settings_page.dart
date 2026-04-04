import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUpdateAlertEnabled = true;
  bool _isPreviewRankEnabled = false;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isUpdateAlertEnabled = prefs.getBool('is_update_alert_enabled') ?? true;
      _isPreviewRankEnabled = prefs.getBool('is_preview_rank_enabled') ?? false;
      _themeMode = ThemeNotifier.instance.value;
    });
  }

  Future<void> _togglePreviewRank(bool value) async {
    setState(() => _isPreviewRankEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_preview_rank_enabled', value);

    if (value) {
      _showSnackBar("已開啟預覽名次功能，下次查詢成績時生效");
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await ThemeNotifier.instance.setThemeMode(mode);
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return "淺色模式";
      case ThemeMode.dark:
        return "深色模式";
      case ThemeMode.system:
        final brightness = MediaQuery.platformBrightnessOf(context);
        String status = "";
        if (brightness == Brightness.dark) {
          status = " (深色)";
        } else if (brightness == Brightness.light) {
          status = " (淺色)";
        } else {
          status = " (不明)";
        }
        return "系統$status";
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      body: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: isWide ? 0.75 : 1.0,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    children: [
                      _buildSectionTitle("介面外觀"),
                      _buildSettingCard(
                        child: Column(
                          children: [
                            _buildThemeOption(
                              ThemeMode.system,
                              Icons.brightness_auto_rounded,
                            ),
                            Divider(
                              height: 1,
                              indent: 56,
                              color: colorScheme.borderColor,
                            ),
                            _buildThemeOption(
                              ThemeMode.light,
                              Icons.light_mode_rounded,
                            ),
                            Divider(
                              height: 1,
                              indent: 56,
                              color: colorScheme.borderColor,
                            ),
                            _buildThemeOption(
                              ThemeMode.dark,
                              Icons.dark_mode_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle("功能設定"),
                      _buildSettingCard(
                        child: SwitchListTile.adaptive(
                          title: Text(
                            "預覽名次",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primaryText,
                            ),
                          ),
                          subtitle: Text(
                            "顯示尚未正式公布的參考名次 (查詢時間較長)",
                            style: TextStyle(color: colorScheme.subtitleText),
                          ),
                          value: _isPreviewRankEnabled,
                          onChanged: _togglePreviewRank,
                          activeColor: colorScheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: colorScheme.accentBlue,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _themeMode == mode;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.accentBlue.withOpacity(0.05)
            : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? colorScheme.accentBlue : colorScheme.subtitleText,
        ),
        title: Text(
          _getThemeLabel(mode),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? colorScheme.accentBlue
                : colorScheme.primaryText,
          ),
        ),
        trailing: Radio<ThemeMode>(
          value: mode,
          groupValue: _themeMode,
          onChanged: (val) {
            if (val != null) _setThemeMode(val);
          },
          activeColor: colorScheme.accentBlue,
          visualDensity: VisualDensity.compact,
        ),
        onTap: () => _setThemeMode(mode),
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.secondaryCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.borderColor, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colorScheme.primaryText,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          Text(
            "設定",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colorScheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
