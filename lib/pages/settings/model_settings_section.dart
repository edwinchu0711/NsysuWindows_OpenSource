import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ai_config_model.dart';
import '../../services/ai/ai_client.dart';
import '../../theme/app_theme.dart';

enum SimpleConfigStatus { disabled, enabled, justUpdated }

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
                        child: _buildModeToggleItem(
                          label: "簡易模式",
                          isSelected: !_isAdvancedModelMode,
                          onTap: () => widget.onAdvancedModeChanged(false),
                        ),
                      ),
                      Expanded(
                        child: _buildModeToggleItem(
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
          _buildSectionTitle(context, "新手教學"),
          _buildTutorialCard(isTop: false),
        ],
      ],
    );
  }

  List<Widget> _buildSimpleModeContent(ColorScheme colorScheme) {
    return [
      if (_aiConfigs.isEmpty) ...[
        _buildSectionTitle(context, "新手教學"),
        _buildTutorialCard(isTop: true),
        const SizedBox(height: 16),
      ],
      _buildSectionTitle(context, "Google API 設定"),
      _buildSettingCard(
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
                    onPressed: _showSimpleModelInfoDialog,
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
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
                      if (m == 'gemini-3.1-flash-lite-preview')
                        label = "Gemini 3.1 Flash-Lite";
                      if (m == 'gemini-flash-lite-latest')
                        label = "Flash-Lite-Latest";
                      if (m == 'gemini-flash-latest') label = "Flash-Latest";
                      if (m == 'gemma-4-31b-it') label = "Gemma 4";
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected)
                            setState(() => _selectedSimpleModel = m);
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
                _buildTestResultCard(_simpleTestMessage!, _isSimpleTestSuccess),
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
                  _buildSimpleConfigBadge(colorScheme),
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
      _buildSettingCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "簡易模式下，API 金鑰將自動套用於 Embedding 與預設 AI 模型。",
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
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
      _buildSectionTitle(context, "Embedding 數據向量化設定"),
      _buildEmbeddingConfigCard(),
      const SizedBox(height: 24),
      _buildSectionTitle(context, "AI 模型清單"),
      _buildAiConfigsList(),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ElevatedButton.icon(
          onPressed: () => _editAiConfig(null),
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

    return _buildSettingCard(
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
              controller: TextEditingController(text: _embeddingConfig.apiKey),
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
                  child: TextField(
                    controller: TextEditingController(
                      text:
                          "${_embeddingConfig.type == 'google' ? 'Google' : 'OpenAI'} / ${_embeddingConfig.model}",
                    ),
                    enabled: _isEmbeddingEditing,
                    decoration: InputDecoration(
                      labelText: "模型與服務類型",
                      prefixIcon: const Icon(Icons.layers_rounded),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.borderColor,
                          width: 1,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    onPressed: () => _editCurrentEmbedding(),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text("變更"),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_embeddingTestMessage != null)
              _buildTestResultCard(
                _embeddingTestMessage!,
                _isEmbeddingTestSuccess,
              ),
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

  Widget _buildAiConfigsList() {
    if (_aiConfigs.isEmpty) {
      return _buildSettingCard(
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

    return _buildSettingCard(
      child: Column(
        children: _aiConfigs.asMap().entries.map((entry) {
          final index = entry.key;
          final config = entry.value;
          final colorScheme = Theme.of(context).colorScheme;
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  config.type == 'google'
                      ? Icons.auto_awesome
                      : Icons.api_rounded,
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
                      "${config.type == 'google' ? 'Google' : '自訂'} - ${config.model}",
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
                        onPressed: () => _editAiConfig(config),
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

    // Persist to SharedPreferences
    _saveAiConfigs();
    _saveEmbeddingConfig();
    


    widget.onReload();

    // Notify parent to persist
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

  void _editCurrentEmbedding() {
    final TextEditingController modelController = TextEditingController(
      text: _embeddingConfig.model,
    );
    final TextEditingController urlController = TextEditingController(
      text: _embeddingConfig.baseUrl ?? "",
    );
    String type = _embeddingConfig.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("修改 Embedding 設定"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: "服務類別"),
                items: const [
                  DropdownMenuItem(value: "google", child: Text("Google (推薦)")),
                  DropdownMenuItem(value: "openai", child: Text("OpenAI 相容")),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => type = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(labelText: "模型 ID"),
              ),
              const SizedBox(height: 16),
              if (type == 'openai')
                TextField(
                  controller: urlController,
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
                setState(() {
                  _embeddingConfig = AiConfig(
                    id: _embeddingConfig.id,
                    name: _embeddingConfig.name,
                    type: type,
                    model: modelController.text,
                    apiKey: _embeddingConfig.apiKey,
                    baseUrl: urlController.text.isNotEmpty
                        ? urlController.text
                        : null,
                  );
                  _isEmbeddingEditing = false;
                });
                _saveEmbeddingConfig();
                Navigator.pop(context);
              },
              child: const Text("確定"),
            ),
          ],
        ),
      ),
    );
  }

  void _editAiConfig(AiConfig? existing) {
    final TextEditingController nameController = TextEditingController(
      text: existing?.name ?? "",
    );
    final TextEditingController modelController = TextEditingController(
      text:
          existing?.model ??
          (existing?.type == 'openai' ? "" : "gemini-flash-lite-latest"),
    );
    final TextEditingController keyController = TextEditingController(
      text: existing?.apiKey ?? "",
    );
    final TextEditingController urlController = TextEditingController(
      text: existing?.baseUrl ?? "",
    );
    String type = existing?.type ?? "google";
    bool isTesting = false;
    String? testResultMessage;
    bool? isTestSuccess;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  existing == null
                      ? Icons.add_circle_outline_rounded
                      : Icons.edit_note_rounded,
                  color: colorScheme.accentBlue,
                ),
                const SizedBox(width: 12),
                Text(existing == null ? "新增 AI 模型" : "編輯 AI 模型"),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: InputDecoration(
                        labelText: "服務類別",
                        prefixIcon: const Icon(Icons.category_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "google",
                          child: Text("Google Gemini (推薦)"),
                        ),
                        DropdownMenuItem(
                          value: "openai",
                          child: Text("自訂 OpenAI 相容服務"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            type = val;
                            if (type == 'google' &&
                                modelController.text.isEmpty) {
                              modelController.text = "gemini-flash-lite-latest";
                            } else if (type == 'openai' &&
                                urlController.text.isEmpty) {
                              urlController.text =
                                  "https://api.openai.com/v1/chat/completions";
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "名稱",
                        prefixIcon: const Icon(Icons.label_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Tooltip(
                          message: "幫您的模型取個好記的名字，例如：Flash",
                          child: Icon(Icons.help_outline_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyController,
                      decoration: InputDecoration(
                        labelText: "API 金鑰 (API KEY)",
                        helperText: keyController.text.isNotEmpty
                            ? "目前輸入的 Key: ${_maskApiKey(keyController.text)}"
                            : null,
                        prefixIcon: const Icon(Icons.key_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.accentBlue.withOpacity(0.05),
                        suffixIcon: const Tooltip(
                          message: "填入從網站申請的 API Key",
                          child: Icon(Icons.help_outline_rounded, size: 18),
                        ),
                      ),
                      obscureText: true,
                      onChanged: (val) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: modelController,
                      decoration: InputDecoration(
                        labelText: "模型 ID (Model Name)",
                        prefixIcon: const Icon(Icons.psychology_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Tooltip(
                          message: "例如：gemini-flash-lite-latest",
                          child: Icon(Icons.help_outline_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: "API Endpoint",
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText: type == 'google'
                            ? "通常不用填寫，系統已有預設值，若無法連線再自行修改"
                            : "請輸入相容服務的完整 API 位址",
                        suffixIcon: Tooltip(
                          message: type == 'google'
                              ? "Google 使用者通常留空即可"
                              : "提供相容服務的完整 URL",
                          child: const Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (testResultMessage != null)
                      _buildTestResultCard(testResultMessage!, isTestSuccess),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isTesting
                            ? null
                            : () async {
                                if (keyController.text.isEmpty) {
                                  setDialogState(() {
                                    testResultMessage = "請先輸入 API KEY";
                                    isTestSuccess = false;
                                  });
                                  return;
                                }
                                if (type == 'openai' &&
                                    urlController.text.isEmpty) {
                                  setDialogState(() {
                                    testResultMessage = "自訂模式下請提供 Base URL";
                                    isTestSuccess = false;
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  isTesting = true;
                                  testResultMessage = "正在連線測試中...";
                                  isTestSuccess = null;
                                });
                                final testConfig = AiConfig(
                                  id: "test",
                                  name: "Test",
                                  type: type,
                                  model: modelController.text,
                                  apiKey: keyController.text,
                                  baseUrl: urlController.text,
                                );
                                final client = AiClient(config: testConfig);
                                try {
                                  final res = await client.generateContent(
                                    [],
                                    "你好，請簡短回傳「連線成功」四個字。",
                                    temperature: 0.1,
                                    maxOutputTokens: 50,
                                  );
                                  setDialogState(() {
                                    testResultMessage =
                                        "連線成功！AI 回應內容：\n${res.text}";
                                    isTestSuccess = true;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    testResultMessage = "發生錯誤：$e";
                                    isTestSuccess = false;
                                  });
                                } finally {
                                  if (context.mounted)
                                    setDialogState(() => isTesting = false);
                                }
                              },
                        icon: isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.flash_on_rounded),
                        label: Text(isTesting ? "測試中..." : "立刻測試連線效果"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("取消"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty ||
                      modelController.text.isEmpty ||
                      keyController.text.isEmpty) {
                    setDialogState(() {
                      testResultMessage = "請填寫所有必要欄位";
                      isTestSuccess = false;
                    });
                    return;
                  }
                  if (type == 'openai' && urlController.text.isEmpty) {
                    setDialogState(() {
                      testResultMessage = "自訂模式下 Base URL 為必填項";
                      isTestSuccess = false;
                    });
                    return;
                  }
                  final newConfig = AiConfig(
                    id:
                        existing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: type,
                    model: modelController.text,
                    apiKey: keyController.text,
                    baseUrl: urlController.text,
                  );
                  setState(() {
                    if (existing == null) {
                      _aiConfigs.add(newConfig);
                    } else {
                      final idx = _aiConfigs.indexWhere(
                        (c) => c.id == existing.id,
                      );
                      if (idx != -1) _aiConfigs[idx] = newConfig;
                    }
                    _syncSimpleModeFromAiConfigs();
                  });
                  _saveAiConfigs();
                  widget.onReload();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text("儲存設定"),
              ),
              const SizedBox(width: 8),
            ],
          );
        },
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

  Widget _buildTutorialCard({bool isTop = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget card = _buildSettingCard(
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
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          _launchURL("https://aistudio.google.com/"),
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
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.accentBlue.withOpacity(
                    0.3 * _pulseAnimation.value,
                  ),
                  blurRadius: 15 * _pulseAnimation.value,
                  spreadRadius: 2 * _pulseAnimation.value,
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

  void _showSimpleModelInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModelDescItem(
                "Gemini 3.1 Flash-Lite",
                "Google 的輕量旗艦，具備極佳的推理能力與超長上下文處理，特別適合處理複雜邏輯與大量文本摘要，\n使用額度高（預估每日200次），有時會遇到API 流量限制的問題，導致回復速度很慢。",
              ),
              const SizedBox(height: 16),
              _buildModelDescItem(
                "Flash-Lite-Latest",
                "目前穩定性最高且維護成本極簡的模型，不同期間會是不同的模型，因此使用額度不定（預估每日200次），有時會遇到API 流量限制的問題，導致回復速度很慢。",
              ),
              const SizedBox(height: 16),
              _buildModelDescItem(
                "Flash-Latest",
                "目前穩定性最高且維護成本較少的模型，不同期間會是不同的模型，因此使用額度不定（預估每日10次）。",
              ),
              const SizedBox(height: 16),
              _buildModelDescItem(
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
      },
    );
  }

  Widget _buildModelDescItem(String title, String desc) {
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

  Widget _buildSimpleConfigBadge(ColorScheme colorScheme) {
    String label;
    Color bgColor;
    Color textColor;

    switch (_simpleConfigStatus) {
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
        bgColor = colorScheme.accentBlue.withOpacity(0.15);
        textColor = colorScheme.accentBlue;
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

  Widget _buildTestResultCard(String message, bool? isSuccess) {
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

  Widget _buildModeToggleItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
}
