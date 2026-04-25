import 'package:flutter/material.dart';
import '../../../models/ai_config_model.dart';

class EmbeddingEditDialog extends StatefulWidget {
  final AiConfig config;
  const EmbeddingEditDialog({super.key, required this.config});

  static Future<AiConfig?> show(BuildContext context, AiConfig config) {
    return showDialog<AiConfig?>(
      context: context,
      builder: (_) => EmbeddingEditDialog(config: config),
    );
  }

  @override
  State<EmbeddingEditDialog> createState() => _EmbeddingEditDialogState();
}

class _EmbeddingEditDialogState extends State<EmbeddingEditDialog> {
  late final TextEditingController _modelController;
  late final TextEditingController _urlController;
  late String _type;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.config.model);
    _urlController = TextEditingController(text: widget.config.baseUrl ?? "");
    _type = widget.config.type;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("修改 Embedding 設定"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: "服務類別"),
              items: const [
                DropdownMenuItem(value: "google", child: Text("Google (推薦)")),
                DropdownMenuItem(value: "openai", child: Text("OpenAI 相容")),
              ],
              onChanged: (val) {
                if (val != null) setDialogState(() => _type = val);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: "模型 ID"),
            ),
            const SizedBox(height: 16),
            if (_type == 'openai')
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: "中轉網址 (Base URL)",
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                AiConfig(
                  id: widget.config.id,
                  name: widget.config.name,
                  type: _type,
                  model: _modelController.text,
                  apiKey: widget.config.apiKey,
                  baseUrl: _urlController.text.isNotEmpty
                      ? _urlController.text
                      : null,
                ),
              );
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }
}
