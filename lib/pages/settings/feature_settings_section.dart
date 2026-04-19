import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FeatureSettingsSection extends StatelessWidget {
  final bool isPreviewRankEnabled;
  final ValueChanged<bool> onPreviewRankChanged;

  const FeatureSettingsSection({
    super.key,
    required this.isPreviewRankEnabled,
    required this.onPreviewRankChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey("feature"),
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle(context, "功能設定"),
        _buildSettingCard(
          context,
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
            value: isPreviewRankEnabled,
            onChanged: onPreviewRankChanged,
            activeColor: colorScheme.accentBlue,
          ),
        ),
      ],
    );
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