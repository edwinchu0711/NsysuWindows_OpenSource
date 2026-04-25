import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../widgets/model_settings_widgets.dart';

class ModelInfoDialog extends StatelessWidget {
  const ModelInfoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ModelInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: colorScheme.accentBlue),
          const SizedBox(width: 12),
          const Text("模型特色介紹"),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModelDescItem(
            "Gemini 3.1 Flash-Lite",
            "Google 的輕量旗艦，具備極佳的推理能力與超長上下文處理，特別適合處理複雜邏輯與大量文本摘要，\n使用額度高（預估每日200次），有時會遇到API 流量限制的問題，導致回復速度很慢。",
          ),
          SizedBox(height: 16),
          ModelDescItem(
            "Flash-Lite-Latest",
            "目前穩定性最高且維護成本極簡的模型，不同期間會是不同的模型，因此使用額度不定（預估每日200次），有時會遇到API 流量限制的問題，導致回復速度很慢。",
          ),
          SizedBox(height: 16),
          ModelDescItem(
            "Flash-Latest",
            "目前穩定性最高且維護成本較少的模型，不同期間會是不同的模型，因此使用額度不定（預估每日10次）。",
          ),
          SizedBox(height: 16),
          ModelDescItem(
            "Gemma 4",
            "基於 Google 開源架構優化的模型，但也是這三種模型中推理能力最弱的，可以應付最基本的問答，回復速度最慢，但額度非常多（預估每日700次）。",
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("確定"),
        ),
      ],
    );
  }
}
