import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../models/ai_config_model.dart';
import '../../../services/ai/ai_client.dart';
import '../../../theme/app_theme.dart';
import '../widgets/model_settings_widgets.dart';

String _maskApiKey(String key) {
  if (key.length <= 8) return "********";
  return "${key.substring(0, 4)}...${key.substring(key.length - 4)}";
}

class AiConfigDialog extends StatefulWidget {
  final AiConfig? existing;
  const AiConfigDialog({super.key, this.existing});

  static Future<AiConfig?> show(BuildContext context, {AiConfig? existing}) {
    return showDialog<AiConfig?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiConfigDialog(existing: existing),
    );
  }

  @override
  State<AiConfigDialog> createState() => _AiConfigDialogState();
}

class _AiConfigDialogState extends State<AiConfigDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelController;
  late final TextEditingController _keyController;
  late final TextEditingController _urlController;
  late String _type;
  bool _isTesting = false;
  String? _testResultMessage;
  bool? _isTestSuccess;
  bool _isFetchingModels = false;
  bool _showModels = false;
  List<dynamic> _availableModels = [];
  String? _modelsErrorMessage;
  String? _selectedProviderFilter;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? "");
    _modelController = TextEditingController(
      text:
          widget.existing?.model ??
          (widget.existing?.type == 'google'
              ? "gemini-flash-lite-latest"
              : (widget.existing?.type == 'nvidia'
                    ? "qwen/qwen3.5-122b-a10b"
                    : "")),
    );
    _keyController = TextEditingController(text: widget.existing?.apiKey ?? "");
    _urlController = TextEditingController(
      text:
          widget.existing?.baseUrl ??
          (widget.existing?.type == 'nvidia'
              ? "https://integrate.api.nvidia.com/v1/chat/completions"
              : ""),
    );
    _type = widget.existing?.type ?? "google";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _keyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _requiresBaseUrl => _type != 'google';
  bool get _requiresApiKey => _type != 'ollama_local';

  DropdownMenuItem<String> _buildProviderItem(
    String value,
    IconData icon,
    String label,
    ColorScheme colorScheme,
  ) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.accentBlue),
          const SizedBox(width: 12),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  AiConfig? _buildResult() {
    if (_nameController.text.isEmpty ||
        _modelController.text.isEmpty ||
        (_requiresApiKey && _keyController.text.isEmpty)) {
      setState(() {
        _testResultMessage = "請填寫所有必要欄位";
        _isTestSuccess = false;
      });
      return null;
    }
    if (_requiresBaseUrl && _urlController.text.isEmpty) {
      setState(() {
        _testResultMessage = "此服務類別需要填寫 Base URL";
        _isTestSuccess = false;
      });
      return null;
    }
    return AiConfig(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      type: _type,
      model: _modelController.text,
      apiKey: _keyController.text,
      baseUrl: _urlController.text,
    );
  }

  Future<void> _fetchModels() async {
    final apiKey = _keyController.text;
    final baseUrl = _urlController.text;
    if (_requiresApiKey && apiKey.isEmpty) {
      setState(() {
        _showModels = true;
        _isFetchingModels = false;
        _modelsErrorMessage = "請先輸入 API Key";
      });
      return;
    }
    if (_requiresBaseUrl && baseUrl.isEmpty) {
      setState(() {
        _showModels = true;
        _isFetchingModels = false;
        _modelsErrorMessage = "請先輸入 Base URL";
      });
      return;
    }
    setState(() {
      _showModels = true;
      _isFetchingModels = true;
      _modelsErrorMessage = null;
      _selectedProviderFilter = null;
    });

    try {
      List<dynamic> models = [];
      if (_type == 'google') {
        final response = await http
            .get(
              Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
              ),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['models'] as List? ?? [];
          models = list
              .where((m) {
                final supported =
                    m['supportedGenerationMethods'] as List? ?? [];
                return supported.contains('generateContent') &&
                    !supported.contains('embedContent');
              })
              .map((m) {
                final name = m['name']?.toString() ?? '';
                return {
                  'id': name.startsWith('models/') ? name.substring(7) : name,
                  'owned_by': 'Google',
                  'description': m['displayName'] ?? m['description'],
                };
              })
              .toList();
        } else {
          String errorMsg = "請求失敗 (${response.statusCode})";
          try {
            final errData = jsonDecode(response.body);
            if (errData['error'] != null) {
              final e = errData['error'];
              if (e is Map) {
                errorMsg = e['message']?.toString() ?? errorMsg;
              } else {
                errorMsg = e.toString();
              }
            }
          } catch (_) {}
          throw Exception(errorMsg);
        }
      } else {
        String modelsUrl = baseUrl;
        if (baseUrl.endsWith('/chat/completions')) {
          modelsUrl = baseUrl.replaceAll('/chat/completions', '/models');
        } else if (baseUrl.endsWith('/v1')) {
          modelsUrl = '$baseUrl/models';
        } else {
          modelsUrl = '$baseUrl/models';
        }

        final headers = <String, String>{
          "Content-Type": "application/json",
        };
        if (apiKey.isNotEmpty) {
          headers["Authorization"] = "Bearer $apiKey";
        }

        final response = await http
            .get(
              Uri.parse(modelsUrl),
              headers: headers,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          models = data['data'] as List? ?? [];
        } else {
          String errorMsg = "請求失敗 (${response.statusCode})";
          try {
            final errData = jsonDecode(response.body);
            if (errData['error'] != null) {
              final e = errData['error'];
              if (e is Map) {
                errorMsg = e['message']?.toString() ?? errorMsg;
              } else {
                errorMsg = e.toString();
              }
            }
          } catch (_) {}
          throw Exception(errorMsg);
        }
      }

      if (mounted) {
        setState(() {
          final uniqueModels = <String, dynamic>{};
          for (var m in models) {
            final id = m['id']?.toString() ?? '';
            if (id.isNotEmpty && !uniqueModels.containsKey(id)) {
              uniqueModels[id] = m;
            }
          }
          _availableModels = uniqueModels.values.toList();
          _isFetchingModels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingModels = false;
          _modelsErrorMessage = "發生錯誤：$e";
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_requiresApiKey && _keyController.text.isEmpty) {
      setState(() {
        _testResultMessage = "請先輸入 API KEY";
        _isTestSuccess = false;
      });
      return;
    }
    if (_requiresBaseUrl && _urlController.text.isEmpty) {
      setState(() {
        _testResultMessage = "此服務類別需要填寫 Base URL";
        _isTestSuccess = false;
      });
      return;
    }
    setState(() {
      _isTesting = true;
      _testResultMessage = "正在連線測試中...";
      _isTestSuccess = null;
    });
    final stopwatch = Stopwatch()..start();
    final testConfig = AiConfig(
      id: "test",
      name: "Test",
      type: _type,
      model: _modelController.text,
      apiKey: _keyController.text,
      baseUrl: _urlController.text,
    );
    final client = AiClient(config: testConfig);
    try {
      final res = await client
          .generateContent(
            [],
            "你好，請簡短回傳「連線成功」四個字。",
            temperature: 0.1,
            maxOutputTokens: 50,
          )
          .timeout(const Duration(seconds: 15));
      stopwatch.stop();
      final time = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);
      if (mounted) {
        setState(() {
          _testResultMessage = "連線成功！(耗時 $time 秒)\nAI 回應內容：\n${res.text}";
          _isTestSuccess = true;
        });
      }
    } catch (e) {
      stopwatch.stop();
      final time = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);
      if (mounted) {
        setState(() {
          if (e.toString().contains('Timeout')) {
            _testResultMessage = "連線逾時！(超過 15 秒未回應)";
          } else {
            _testResultMessage = "發生錯誤：$e\n(耗時 $time 秒)";
          }
          _isTestSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Widget _buildForm(ColorScheme colorScheme) {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _type,
              isExpanded: true,
              dropdownColor: colorScheme.surface,
              focusColor: Colors.transparent,
              decoration: InputDecoration(
                labelText: "服務類別",
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.accentBlue,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              items: [
                _buildProviderItem(
                  "google",
                  Icons.auto_awesome_rounded,
                  "Google Gemini (推薦)",
                  colorScheme,
                ),
                _buildProviderItem(
                  "nvidia",
                  Icons.memory_rounded,
                  "NVIDIA",
                  colorScheme,
                ),
                _buildProviderItem(
                  "openai",
                  Icons.cloud_rounded,
                  "OpenAI",
                  colorScheme,
                ),
                _buildProviderItem(
                  "openrouter",
                  Icons.router_rounded,
                  "OpenRouter",
                  colorScheme,
                ),
                _buildProviderItem(
                  "groq",
                  Icons.bolt_rounded,
                  "Groq",
                  colorScheme,
                ),
                _buildProviderItem(
                  "ollama_cloud",
                  Icons.cloud_queue_rounded,
                  "Ollama（Cloud）",
                  colorScheme,
                ),
                _buildProviderItem(
                  "ollama_local",
                  Icons.computer_rounded,
                  "Ollama（Local）",
                  colorScheme,
                ),
                _buildProviderItem(
                  "custom_openai",
                  Icons.tune_rounded,
                  "自訂 OpenAI 相容服務",
                  colorScheme,
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _testResultMessage = null;
                    _isTestSuccess = null;
                    _type = val;
                    switch (_type) {
                      case 'google':
                        if (_modelController.text.isEmpty) {
                          _modelController.text = "gemini-flash-lite-latest";
                        }
                        _urlController.text =
                            "https://generativelanguage.googleapis.com";
                      case 'nvidia':
                        if (_modelController.text.isEmpty ||
                            _modelController.text ==
                                "gemini-flash-lite-latest") {
                          _modelController.text = "qwen/qwen3.5-122b-a10b";
                        }
                        _urlController.text =
                            "https://integrate.api.nvidia.com/v1/chat/completions";
                      case 'openai':
                        _urlController.text =
                            "https://api.openai.com/v1/chat/completions";
                      case 'openrouter':
                        _urlController.text =
                            "https://openrouter.ai/api/v1/chat/completions";
                      case 'anthropic':
                        _urlController.text =
                            "https://api.anthropic.com/v1/chat/completions";
                      case 'groq':
                        _urlController.text =
                            "https://api.groq.com/openai/v1/chat/completions";
                      case 'ollama_cloud':
                        _urlController.text =
                            "https://ollama.com/v1/chat/completions";
                      case 'ollama_local':
                        _urlController.text =
                            "http://localhost:11434/v1/chat/completions";
                      case 'custom_openai':
                        _urlController.text = "";
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
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
              controller: _keyController,
              decoration: InputDecoration(
                labelText: "API 金鑰 (API KEY)",
                helperText: _keyController.text.isNotEmpty
                    ? "目前輸入的 Key: ${_maskApiKey(_keyController.text)}"
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
              onChanged: (_) => setState(() {
                _testResultMessage = null;
                _isTestSuccess = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
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
              onChanged: (_) => setState(() {
                _testResultMessage = null;
                _isTestSuccess = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: "API Endpoint",
                prefixIcon: const Icon(Icons.link_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperMaxLines: 3,
                helperText: _type == 'google'
                    ? "Google API通常不用填寫，系統已有預設值，若無法連線再自行修改"
                    : _type == 'nvidia'
                    ? "NVIDIA API通常不用填寫，系統已有預設值，若無法連線再自行修改"
                    : "請輸入相容服務的完整 API 位址",
                suffixIcon: Tooltip(
                  message: _type == 'google' || _type == 'nvidia'
                      ? "預設已有系統設定，通常留空或不需修改"
                      : "提供相容服務的完整 URL",
                  child: const Icon(Icons.help_outline_rounded, size: 18),
                ),
              ),
              onChanged: (_) => setState(() {
                _testResultMessage = null;
                _isTestSuccess = null;
              }),
            ),
            if (_type == 'google' ||
                _type == 'openai' ||
                _type == 'nvidia') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _fetchModels,
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text("查看可用模型"),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.accentBlue,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_testResultMessage != null)
              TestResultCard(_testResultMessage!, _isTestSuccess),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flash_on_rounded),
                label: Text(_isTesting ? "測試中..." : "立刻測試連線效果"),
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
    );
  }

  Widget _buildModelsPanel(ColorScheme colorScheme) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _type == 'nvidia' ? "NVIDIA NIM 模型" : "可用模型清單",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _showModels = false),
                tooltip: "關閉",
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isFetchingModels)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_modelsErrorMessage != null)
            Expanded(
              child: Center(
                child: Text(
                  _modelsErrorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_availableModels.isEmpty)
            const Expanded(
              child: Center(
                child: Text("找不到模型", style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            _buildModelsList(colorScheme),
        ],
      ),
    );
  }

  Widget _buildModelsList(ColorScheme colorScheme) {
    final List<String> providers =
        _availableModels
            .map((m) => m['owned_by']?.toString() ?? 'N/A')
            .toSet()
            .map(
              (p) => p.isNotEmpty
                  ? '${p[0].toUpperCase()}${p.substring(1)}'
                  : 'N/A',
            )
            .toList()
          ..sort();

    if (_selectedProviderFilter != null &&
        !providers.contains(_selectedProviderFilter)) {
      _selectedProviderFilter = null;
    }

    final displayedModels = _selectedProviderFilter == null
        ? _availableModels
        : _availableModels.where((m) {
            final p = m['owned_by']?.toString() ?? 'N/A';
            final fp = p.isNotEmpty
                ? '${p[0].toUpperCase()}${p.substring(1)}'
                : 'N/A';
            return fp == _selectedProviderFilter;
          }).toList();

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "提醒：部分模型可能無法使用或回應較久，建議套用後先測試連線，選擇回復速度快的。",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (providers.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: DropdownButtonFormField<String?>(
                value: _selectedProviderFilter,
                isExpanded: true,
                dropdownColor: colorScheme.surface,
                focusColor: Colors.transparent,
                decoration: InputDecoration(
                  labelText: "篩選 Provider",
                  prefixIcon: Icon(
                    Icons.filter_list_rounded,
                    color: colorScheme.accentBlue,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.accentBlue,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("全部 Provider"),
                  ),
                  ...providers.map(
                    (p) => DropdownMenuItem(value: p, child: Text(p)),
                  ),
                ],
                onChanged: (val) =>
                    setState(() => _selectedProviderFilter = val),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: displayedModels.length,
              itemBuilder: (context, index) {
                final model = displayedModels[index];
                final String rawProvider =
                    model['owned_by']?.toString() ?? 'N/A';
                final String provider = rawProvider.isNotEmpty
                    ? '${rawProvider[0].toUpperCase()}${rawProvider.substring(1)}'
                    : 'N/A';
                final String modelId = model['id']?.toString() ?? 'N/A';
                final bool isSelected = _modelController.text == modelId;

                return Card(
                  elevation: 0,
                  color: isSelected
                      ? colorScheme.accentBlue.withOpacity(0.05)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.accentBlue
                          : colorScheme.borderColor.withOpacity(0.5),
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _modelController.text = modelId;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  modelId,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected
                                        ? colorScheme.accentBlue
                                        : colorScheme.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.accentBlue.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    provider,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.accentBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 20,
                            color: isSelected
                                ? colorScheme.accentBlue
                                : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            widget.existing == null
                ? Icons.add_circle_outline_rounded
                : Icons.edit_note_rounded,
            color: colorScheme.accentBlue,
          ),
          const SizedBox(width: 12),
          Text(widget.existing == null ? "新增 AI 模型" : "編輯 AI 模型"),
        ],
      ),
      content: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: _showModels ? 850 : 500,
        height: 580,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildForm(colorScheme),
            if (_showModels) ...[
              const SizedBox(width: 16),
              Container(width: 1, color: colorScheme.borderColor),
              const SizedBox(width: 16),
              _buildModelsPanel(colorScheme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        ElevatedButton(
          onPressed: () {
            final result = _buildResult();
            if (result != null) Navigator.pop(context, result);
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
  }
}
