import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class InterfaceSettingsSection extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const InterfaceSettingsSection({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey("interface"),
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle(context, "介面外觀"),
        _buildSettingCard(
          context,
          child: Column(
            children: [
              _buildThemeOption(context, ThemeMode.system, Icons.brightness_auto_rounded),
              Divider(height: 1, indent: 56, color: colorScheme.borderColor),
              _buildThemeOption(context, ThemeMode.light, Icons.light_mode_rounded),
              Divider(height: 1, indent: 56, color: colorScheme.borderColor),
              _buildThemeOption(context, ThemeMode.dark, Icons.dark_mode_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(BuildContext context, ThemeMode mode, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = themeMode == mode;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.accentBlue.withOpacity(0.05) : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? colorScheme.accentBlue : colorScheme.subtitleText),
        title: Text(
          _getThemeLabel(context, mode),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colorScheme.accentBlue : colorScheme.primaryText,
          ),
        ),
        trailing: Radio<ThemeMode>(
          value: mode,
          groupValue: themeMode,
          onChanged: (val) {
            if (val != null) onThemeChanged(val);
          },
          activeColor: colorScheme.accentBlue,
          visualDensity: VisualDensity.compact,
        ),
        onTap: () => onThemeChanged(mode),
      ),
    );
  }

  String _getThemeLabel(BuildContext context, ThemeMode mode) {
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

  Widget _buildSectionTitle(BuildContext context, String title) {
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

  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
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
}