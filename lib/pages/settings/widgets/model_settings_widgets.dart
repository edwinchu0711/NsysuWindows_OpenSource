import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../theme/app_theme.dart';

enum SimpleConfigStatus { disabled, enabled, justUpdated }

class SettingCard extends StatelessWidget {
  final Widget child;
  const SettingCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
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

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
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
}

class TestResultCard extends StatelessWidget {
  final String message;
  final bool? isSuccess;
  const TestResultCard(this.message, this.isSuccess, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: (isSuccess == true)
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isSuccess == true) ? Colors.green : Colors.red,
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            (isSuccess == true)
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            color: (isSuccess == true) ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: (isSuccess == true)
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModeToggleItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const ModeToggleItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.1,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? colorScheme.accentBlue
                : colorScheme.primaryText.withOpacity(0.7),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class SimpleConfigBadge extends StatelessWidget {
  final SimpleConfigStatus status;
  const SimpleConfigBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bgColor;
    Color textColor;

    switch (status) {
      case SimpleConfigStatus.disabled:
        label = "未啟用";
        bgColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
      case SimpleConfigStatus.enabled:
        label = "啟用";
        bgColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green;
      case SimpleConfigStatus.justUpdated:
        label = "更新成功";
        bgColor = Theme.of(context).colorScheme.accentBlue.withOpacity(0.15);
        textColor = Theme.of(context).colorScheme.accentBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

class TutorialCard extends StatelessWidget {
  final bool isTop;
  final Animation<double> pulseAnimation;
  final VoidCallback onLinkTap;
  const TutorialCard({
    super.key,
    this.isTop = false,
    required this.pulseAnimation,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget card = SettingCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  "如何獲取免費 API Key？",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                text: "1. 前往 ",
                style: const TextStyle(fontSize: 14),
                children: [
                  TextSpan(
                    text: "Google AI Studio 官方網站",
                    style: TextStyle(
                      color: colorScheme.accentBlue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onLinkTap,
                  ),
                  const TextSpan(text: "並登入。"),
                ],
              ),
            ),
            const Text("2. 點擊「Get API key」並建立一個新的 Key。"),
            const Text("3. 在此頁面欄位輸入該 Key ，再選擇一個模型即可。"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.recommend_rounded, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "推薦模型 ID：gemini-3.1-flash-lite-preview , gemini-flash-lite-latest",
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isTop) {
      return AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.accentBlue.withOpacity(
                    0.3 * pulseAnimation.value,
                  ),
                  blurRadius: 15 * pulseAnimation.value,
                  spreadRadius: 2 * pulseAnimation.value,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }
    return card;
  }
}

class ModelDescItem extends StatelessWidget {
  final String title;
  final String desc;
  const ModelDescItem(this.title, this.desc, {super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.accentBlue,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.primaryText,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class NvidiaBanner extends StatelessWidget {
  final VoidCallback onLinkTap;
  const NvidiaBanner({super.key, required this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SettingCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  "提升模型效能建議",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primaryText,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: "若追求更高效率的模型體驗，可至 "),
                  TextSpan(
                    text: "NVIDIA 官方網站",
                    style: TextStyle(
                      color: colorScheme.accentBlue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onLinkTap,
                  ),
                  const TextSpan(
                    text:
                        " 申請 API 金鑰（需先行註冊或登入），並於此頁面手動新增模型。\n各模型之處理速度存在差異，建議依實際需求進行測試。",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
