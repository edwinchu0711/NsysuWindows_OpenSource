import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ai_config_model.dart';
import '../../services/ai/ai_client.dart';
import '../../theme/app_theme.dart';
import 'dialogs/ai_config_dialog.dart';
import 'dialogs/embedding_edit_dialog.dart';
import 'dialogs/model_info_dialog.dart';
import 'widgets/model_settings_widgets.dart';

export 'widgets/model_settings_widgets.dart' show SimpleConfigStatus;

class ModelSettingsSection extends StatefulWidget {
  final bool isAdvancedModelMode;
  final List<AiConfig> aiConfigs;
  final AiConfig embeddingConfig;
  final bool isEmbeddingInitialized;
  final bool isEmbeddingEditing;
  final String? selectedSimpleModel;
  final SimpleConfigStatus simpleConfigStatus;
  final ValueChanged<bool> onAdvancedModeChanged;
  final VoidCallback onReload;

  const ModelSettingsSection({
    super.key,
    required this.isAdvancedModelMode,
    required this.aiConfigs,
    required this.embeddingConfig,
    required this.isEmbeddingInitialized,
    required this.isEmbeddingEditing,
    required this.selectedSimpleModel,
    required this.simpleConfigStatus,
    required this.onAdvancedModeChanged,
    required this.onReload,
  });

  @override
  State<ModelSettingsSection> createState() => _ModelSettingsSectionState();
}

class _ModelSettingsSectionState extends State<ModelSettingsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late TextEditingController _simpleApiKeyController;
  late TextEditingController _simpleModelIdController;
  late TextEditingController _embeddingApiKeyController;
  String? _selectedSimpleModel;
  SimpleConfigStatus _simpleConfigStatus = SimpleConfigStatus.disabled;
  List<AiConfig> _aiConfigs = [];
  AiConfig _embeddingConfig = AiConfig(
    id: 'embedding_default',
    name: 'Embedding 模型',
    type: 'google',
    model: 'gemini-embedding-2-preview',
    apiKey: '',
  );
  bool _isAdvancedModelMode = false;
  bool _isEmbeddingEditing = false;

  bool _isSimpleTesting = false;
  String? _simpleTestMessage;
  bool? _isSimpleTestSuccess;
  bool _isSimpleSaveSuccess = false;

  bool _isEmbeddingTesting = false;
  String? _embeddingTestMessage;
  bool? _isEmbeddingTestSuccess;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _simpleApiKeyController = TextEditingController();
    _simpleModelIdController = TextEditingController();
    _embeddingApiKeyController = TextEditingController();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant ModelSettingsSection old) {
    super.didUpdateWidget(old);
    if (old.aiConfigs != widget.aiConfigs ||
        old.embeddingConfig != widget.embeddingConfig ||
        old.selectedSimpleModel != widget.selectedSimpleModel ||
        old.simpleConfigStatus != widget.simpleConfigStatus ||
        old.isAdvancedModelMode != widget.isAdvancedModelMode ||
        old.isEmbeddingEditing != widget.isEmbeddingEditing) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _aiConfigs = widget.aiConfigs;
    _embeddingConfig = widget.embeddingConfig;
    _embeddingApiKeyController.text = _embeddingConfig.apiKey;
    _selectedSimpleModel = widget.selectedSimpleModel;
    _simpleConfigStatus = widget.simpleConfigStatus;
    _isAdvancedModelMode = widget.isAdvancedModelMode;
    _isEmbeddingEditing = widget.isEmbeddingEditing;
    _syncSimpleModeFromAiConfigs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _simpleApiKeyController.dispose();
    _simpleModelIdController.dispose();
    _embeddingApiKeyController.dispose();
    super.dispose();
  }

  void _syncSimpleModeFromAiConfigs() {
    bool hasTarget = false;
    if (_aiConfigs.isNotEmpty) {
      final firstGoogle = _aiConfigs.firstWhere(
        (c) => c.type == 'google',
        orElse: () =>
            AiConfig(id: '', name: '', type: '', model: '', apiKey: ''),
      );
      if (firstGoogle.id.isNotEmpty) {
        hasTarget = true;
        _simpleApiKeyController.text = firstGoogle.apiKey;
        if ([
          'gemini-3.1-flash-lite-preview',
          'gemini-flash-lite-latest',
          'gemini-flash-latest',
          'gemma-4-31b-it',
        ].contains(firstGoogle.model)) {
          _selectedSimpleModel = firstGoogle.model;
        } else {
          _selectedSimpleModel = 'other';
          _simpleModelIdController.text = firstGoogle.model;
        }
      }
    }

    if (!hasTarget) {
      if (_embeddingConfig.apiKey.isNotEmpty) {
        _simpleApiKeyController.text = _embeddingConfig.apiKey;
      } else {
        _simpleApiKeyController.text = '';
      }
      _selectedSimpleModel = null;
      _simpleModelIdController.text = '';
    }

    final primaryGoogle = _aiConfigs
        .where((c) => c.id == 'primary_google')
        .firstOrNull;
    if (primaryGoogle != null && primaryGoogle.apiKey.isNotEmpty) {
      _simpleConfigStatus = SimpleConfigStatus.enabled;
    } else {
      _simpleConfigStatus = SimpleConfigStatus.disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey("model"),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          height: 52,
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
            color: colorScheme.isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / 2;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    left: _isAdvancedModelMode ? segmentWidth + 4 : 4,
                    top: 4,
                    bottom: 4,
                    width: segmentWidth - 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.isDark
                            ? const Color(0xFF6B9BF5).withOpacity(0.2)
                            : const Color(0xFFE3F2FD).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.isDark
                              ? const Color(0xFF6B9BF5).withOpacity(0.3)
                              : const Color(0xFF90CAF9).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ModeToggleItem(
                          label: "簡易模式",
                          isSelected: !_isAdvancedModelMode,
                          onTap: () => widget.onAdvancedModeChanged(false),
                        ),
                      ),
                      Expanded(
                        child: ModeToggleItem(
                          label: "進階模式",
                          isSelected: _isAdvancedModelMode,
                          onTap: () => widget.onAdvancedModeChanged(true),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        if (!_isAdvancedModelMode)
          ..._buildSimpleModeContent(colorScheme)
        else
          ..._buildAdvancedModeContent(colorScheme),
        const SizedBox(height: 32),
        if (_isAdvancedModelMode == false && _aiConfigs.isNotEmpty) ...[
          const SectionTitle("新手教學"),
          TutorialCard(
            isTop: false,
            pulseAnimation: _pulseAnimation,
            onLinkTap: () => _launchURL("https://aistudio.google.com/"),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildSimpleModeContent(ColorScheme colorScheme) {
    return [
      if (_aiConfigs.isEmpty) ...[
        const SectionTitle("新手教學"),
        TutorialCard(
          isTop: true,
          pulseAnimation: _pulseAnimation,
          onLinkTap: () => _launchURL("https://aistudio.google.com/"),
        ),
        const SizedBox(height: 16),
      ],
      const SectionTitle("Google API 設定"),
      SettingCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "本介面僅限設定 Google 系列模型，若需設定 OpenAI 或其他模型，請切換至「進階模式」。",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Google API 金鑰",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _simpleApiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "貼上您的 API Key",
                  helperText: _simpleApiKeyController.text.isNotEmpty
                      ? "目前輸入的 Key: ${_maskApiKey(_simpleApiKeyController.text)}"
                      : null,
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.pageBackground,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    "選擇 AI 模型",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => ModelInfoDialog.show(context),
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: colorScheme.accentBlue,
                    tooltip: "查看模型詳細介紹",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedSimpleModel == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "請選擇一個模型",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                      'gemini-3.1-flash-lite-preview',
                      'gemini-flash-lite-latest',
                      'gemini-flash-latest',
                      'gemma-4-31b-it',
                    ].map((m) {
                      final isSelected = _selectedSimpleModel == m;
                      String label = m;
                      if (m == 'gemini-3.1-flash-lite-preview') {
                        label = "Gemini 3.1 Flash-Lite";
                      }
                      if (m == 'gemini-flash-lite-latest') {
                        label = "Flash-Lite-Latest";
                      }
                      if (m == 'gemini-flash-latest') {
                        label = "Flash-Latest";
                      }
                      if (m == 'gemma-4-31b-it') {
                        label = "Gemma 4";
                      }
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedSimpleModel = m);
                          }
                        },
                        selectedColor: colorScheme.accentBlue,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : colorScheme.primaryText,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),
              if (_simpleTestMessage != null)
                TestResultCard(_simpleTestMessage!, _isSimpleTestSuccess),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSimpleTesting ? null : _testSimpleConnection,
                    icon: _isSimpleTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flash_on_rounded, size: 18),
                    label: Text(_isSimpleTesting ? "連線中..." : "連線測試"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.accentBlue,
                      side: BorderSide(color: colorScheme.accentBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SimpleConfigBadge(_simpleConfigStatus),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSimpleSaveSuccess ? null : _saveSimpleConfig,
                    icon: Icon(
                      _isSimpleSaveSuccess
                          ? Icons.check_circle_rounded
                          : Icons.save_rounded,
                      size: 18,
                    ),
                    label: Text(_isSimpleSaveSuccess ? "已儲存" : "儲存設定"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSimpleSaveSuccess
                          ? Colors.green
                          : colorScheme.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      SettingCard(
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "簡易模式下，API 金鑰將自動套用於 Embedding 與預設 AI 模型。",
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "若遇到模型無法使用，可以嘗試換個模型再試試看。",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAdvancedModeContent(ColorScheme colorScheme) {
    return [
      const SectionTitle("Embedding 數據向量化設定"),
      _buildEmbeddingConfigCard(),
      const SizedBox(height: 24),
      const SectionTitle("AI 模型清單"),
      NvidiaBanner(
        onLinkTap: () =>
            _launchURL("https://build.nvidia.com/settings/api-keys"),
      ),
      const SizedBox(height: 12),
      _buildAiConfigsList(),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ElevatedButton.icon(
          onPressed: () => _handleEditAiConfig(null),
          icon: const Icon(Icons.add_rounded),
          label: const Text("新增 AI 模型"),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.accentBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildEmbeddingConfigCard() {
    if (!widget.isEmbeddingInitialized) return const SizedBox();
    final colorScheme = Theme.of(context).colorScheme;

    return SettingCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Embedding 模型用於處理 RAG 與語義搜尋。建議使用預設值。",
              style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "一定要填寫 Google AI Studio 的 API Key 才可以進行 Embedding",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _embeddingApiKeyController,
              decoration: InputDecoration(
                labelText: "API Key",
                hintText: "請輸入 Google AI Studio API Key",
                helperText: _embeddingConfig.apiKey.isNotEmpty
                    ? "目前設定的 Key: ${_maskApiKey(_embeddingConfig.apiKey)}"
                    : null,
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  onPressed: () {},
                  tooltip: "儲存",
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _embeddingConfig = AiConfig(
                    id: _embeddingConfig.id,
                    name: _embeddingConfig.name,
                    type: _embeddingConfig.type,
                    model: _embeddingConfig.model,
                    apiKey: val,
                    baseUrl: _embeddingConfig.baseUrl,
                  );
                });
                _saveEmbeddingConfig();
              },
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${_embeddingConfig.type == 'google' ? 'Google' : 'OpenAI'} / ${_embeddingConfig.model}",
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isEmbeddingEditing)
                  TextButton.icon(
                    onPressed: _showEmbeddingModifyWarning,
                    icon: const Icon(Icons.edit_off_rounded, size: 18),
                    label: const Text("修改"),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.accentBlue,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _handleEditEmbedding(),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text("變更"),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_embeddingTestMessage != null)
              TestResultCard(_embeddingTestMessage!, _isEmbeddingTestSuccess),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isEmbeddingTesting
                    ? null
                    : _testEmbeddingConnection,
                icon: _isEmbeddingTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green,
                        ),
                      )
                    : const Icon(Icons.cable_rounded, size: 18),
                label: Text(_isEmbeddingTesting ? "測試中..." : "測試連線"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.isDark
                      ? Colors.green.withOpacity(0.2)
                      : Colors.green[50],
                  foregroundColor: Colors.green,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'google':
        return Icons.auto_awesome;
      case 'nvidia':
        return Icons.memory_rounded;
      case 'openai':
        return Icons.cloud_rounded;
      case 'openrouter':
        return Icons.router_rounded;
      case 'anthropic':
        return Icons.chat_rounded;
      case 'groq':
        return Icons.bolt_rounded;
      case 'ollama_cloud':
        return Icons.cloud_queue_rounded;
      case 'ollama_local':
        return Icons.computer_rounded;
      case 'custom_openai':
        return Icons.tune_rounded;
      default:
        return Icons.api_rounded;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'google':
        return 'Google';
      case 'nvidia':
        return 'NVIDIA';
      case 'openai':
        return 'OpenAI';
      case 'openrouter':
        return 'OpenRouter';
      case 'anthropic':
        return 'Anthropic';
      case 'groq':
        return 'Groq';
      case 'ollama_cloud':
        return 'Ollama (Cloud)';
      case 'ollama_local':
        return 'Ollama (Local)';
      case 'custom_openai':
        return '自訂 OpenAI';
      default:
        return '自訂';
    }
  }

  Widget _buildAiConfigsList() {
    if (_aiConfigs.isEmpty) {
      return SettingCard(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              "尚未設定任何 AI 模型\n請點擊下方按鈕新增",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return SettingCard(
      child: Column(
        children: _aiConfigs.asMap().entries.map((entry) {
          final index = entry.key;
          final config = entry.value;
          final colorScheme = Theme.of(context).colorScheme;
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  _getTypeIcon(config.type),
                  color: colorScheme.accentBlue,
                ),
                title: Row(
                  children: [
                    Text(
                      config.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    if (config.id == 'primary_google') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          "簡易模式",
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${_getTypeLabel(config.type)} - ${config.model}",
                      style: TextStyle(color: colorScheme.subtitleText),
                    ),
                    Text(
                      "Key: ${_maskApiKey(config.apiKey)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.subtitleText.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (config.id != 'primary_google')
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        onPressed: () => _handleEditAiConfig(config),
                        tooltip: "編輯",
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteAiConfig(index),
                      tooltip: "刪除",
                    ),
                  ],
                ),
              ),
              if (index < _aiConfigs.length - 1)
                Divider(height: 1, indent: 56, color: colorScheme.borderColor),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleEditAiConfig(AiConfig? existing) async {
    final result = await AiConfigDialog.show(context, existing: existing);
    if (result != null && mounted) {
      setState(() {
        if (existing == null) {
          _aiConfigs.add(result);
        } else {
          final idx = _aiConfigs.indexWhere((c) => c.id == existing.id);
          if (idx != -1) _aiConfigs[idx] = result;
        }
        _syncSimpleModeFromAiConfigs();
      });
      await _saveAiConfigs();
      widget.onReload();
    }
  }

  Future<void> _handleEditEmbedding() async {
    final result = await EmbeddingEditDialog.show(context, _embeddingConfig);
    if (result != null && mounted) {
      setState(() {
        _embeddingConfig = result;
        _isEmbeddingEditing = false;
      });
      await _saveEmbeddingConfig();
    }
  }

  void _saveSimpleConfig() {
    final key = _simpleApiKeyController.text.trim();
    final modelId = _selectedSimpleModel ?? '';
    if (key.isEmpty) {
      _showSnackBar("請先輸入 API Key", isError: true);
      return;
    }
    if (modelId.isEmpty) {
      _showSnackBar("請先選擇一個模型", isError: true);
      return;
    }

    String modelName = "Google";
    if (_selectedSimpleModel == 'gemini-3.1-flash-lite-preview') {
      modelName = "Gemini 3.1 Flash-Lite";
    } else if (_selectedSimpleModel == 'gemini-flash-lite-latest') {
      modelName = "Flash-Lite-Latest";
    } else if (_selectedSimpleModel == 'gemini-flash-latest') {
      modelName = "Flash-Latest";
    } else if (_selectedSimpleModel == 'gemma-4-31b-it') {
      modelName = "Gemma 4";
    }

    final newEmbeddingConfig = AiConfig(
      id: _embeddingConfig.id,
      name: _embeddingConfig.name,
      type: 'google',
      model: _embeddingConfig.model,
      apiKey: key,
    );

    final newConfig = AiConfig(
      id: 'primary_google',
      name: modelName,
      type: 'google',
      model: modelId,
      apiKey: key,
    );

    List<AiConfig> updatedConfigs = List.from(_aiConfigs);
    int idx = updatedConfigs.indexWhere((c) => c.id == 'primary_google');
    if (idx != -1) {
      updatedConfigs[idx] = newConfig;
    } else {
      updatedConfigs.insert(0, newConfig);
    }

    setState(() {
      _embeddingConfig = newEmbeddingConfig;
      _aiConfigs = updatedConfigs;
      if (_simpleConfigStatus == SimpleConfigStatus.disabled) {
        _simpleConfigStatus = SimpleConfigStatus.enabled;
      } else {
        _simpleConfigStatus = SimpleConfigStatus.justUpdated;
      }
      _isSimpleSaveSuccess = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isSimpleSaveSuccess = false);
    });

    _saveAiConfigs();
    _saveEmbeddingConfig();
    widget.onReload();
  }

  Future<void> _testSimpleConnection() async {
    final key = _simpleApiKeyController.text;
    final modelId = _selectedSimpleModel ?? '';

    if (key.isEmpty) {
      setState(() {
        _simpleTestMessage = "請先輸入 API KEY";
        _isSimpleTestSuccess = false;
      });
      return;
    }

    setState(() {
      _isSimpleTesting = true;
      _simpleTestMessage = "正在連線測試中...";
      _isSimpleTestSuccess = null;
    });

    final testConfig = AiConfig(
      id: "simple_test",
      name: "Simple Test",
      type: 'google',
      model: modelId,
      apiKey: key,
    );
    final client = AiClient(config: testConfig);
    try {
      final res = await client.generateContent(
        [],
        "你好，請簡短回傳「連線成功」四個字。",
        temperature: 0.1,
        maxOutputTokens: 50,
      );
      if (mounted) {
        setState(() {
          _simpleTestMessage = "連線成功！AI 回應內容：\n${res.text}";
          _isSimpleTestSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _simpleTestMessage = "連線失敗：$e";
          _isSimpleTestSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isSimpleTesting = false);
    }
  }

  Future<void> _testEmbeddingConnection() async {
    if (_embeddingConfig.apiKey.isEmpty) {
      setState(() {
        _embeddingTestMessage = "請先輸入 API Key";
        _isEmbeddingTestSuccess = false;
      });
      return;
    }

    setState(() {
      _isEmbeddingTesting = true;
      _embeddingTestMessage = "正在測試 Embedding 連線...";
      _isEmbeddingTestSuccess = null;
    });

    try {
      final client = AiClient(config: _embeddingConfig);
      await client.embedText('test connection');
      if (mounted) {
        setState(() {
          _embeddingTestMessage = "連線成功！API 金鑰設定有效。";
          _isEmbeddingTestSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _embeddingTestMessage = "連線失敗：$e";
          _isEmbeddingTestSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isEmbeddingTesting = false);
    }
  }

  void _showEmbeddingModifyWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text("警告"),
          ],
        ),
        content: const Text("修改 Embedding 模型可能會導致系統無法正常處理語義搜尋或向量數據轉換。確定要繼續嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              setState(() => _isEmbeddingEditing = true);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text("解鎖修改"),
          ),
        ],
      ),
    );
  }

  void _deleteAiConfig(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("刪除模型"),
        content: Text("確定要刪除「${_aiConfigs[index].name}」嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _aiConfigs.removeAt(index);
                _syncSimpleModeFromAiConfigs();
              });
              _saveAiConfigs();
              widget.onReload();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除"),
          ),
        ],
      ),
    );
  }

  String _maskApiKey(String key) {
    if (key.length <= 8) return "********";
    return "${key.substring(0, 4)}...${key.substring(key.length - 4)}";
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString.trim());
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) _showSnackBar("無法開啟連結: $urlString", isError: true);
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

  Future<void> _saveAiConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_configs', AiConfig.encode(_aiConfigs));
  }

  Future<void> _saveEmbeddingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'embedding_config',
      jsonEncode(_embeddingConfig.toJson()),
    );
  }
}
