import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../utils/utils.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_theme.dart';
import '../models/ai_config_model.dart';
import '../services/ai/ai_client.dart';
import '../services/local_course_service.dart';
import '../services/database_embedding_service.dart';
import '../services/course_query_service.dart';

enum SettingsCategory { interface, feature, model, database }

enum _SimpleConfigStatus { disabled, enabled, justUpdated }

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isPreviewRankEnabled = false;
  ThemeMode _themeMode = ThemeMode.system;
  List<AiConfig> _aiConfigs = [];
  SettingsCategory _selectedCategory = SettingsCategory.interface;
  late AiConfig _embeddingConfig;
  bool _isEmbeddingInitialized = false;
  bool _isEmbeddingEditing = false;

  // Database settings state
  bool _isCoursesDbExists = false;
  String _courseDbSemester = '';
  String _courseDbTimestamp = '';
  int _courseDbCourseCount = 0;
  bool _isDatabaseDbExists = false;
  String _databaseDbFilename = '';
  String _databaseDbEmbeddingModel = '';
  int _databaseDbChunkCount = 0;
  String _databaseDbCreatedDate = '';
  bool _isDatabaseDbAutoUpdate = true;
  List<Map<String, dynamic>> _availableDatabases = [];
  bool _isLoadingDatabases = false;
  String? _downloadingFilename;
  String? _selectedEmbeddingModel;
  List<String> _availableEmbeddingModels = [];
  int _maxDisplayedDatabases = 5;
  bool _isAdvancedModelMode = false;
  late TextEditingController _simpleApiKeyController;
  late TextEditingController _simpleModelIdController;
  String? _selectedSimpleModel; // null = no model selected yet
  bool _isSimpleTesting = false;
  String? _simpleTestMessage;
  bool? _isSimpleTestSuccess;
  bool _isCoursesDownloading = false;
  bool _isEmbeddingTesting = false;
  String? _embeddingTestMessage;
  bool? _isEmbeddingTestSuccess;
  // disabled = 未啟用, enabled = 啟用, justUpdated = 更新成功
  _SimpleConfigStatus _simpleConfigStatus = _SimpleConfigStatus.disabled;

  @override
  void initState() {
    super.initState();
    _simpleApiKeyController = TextEditingController();
    _simpleModelIdController = TextEditingController();
    _loadSettings();
    _fetchAvailableDatabases(); // Automatically fetch on start
  }

  @override
  void dispose() {
    _simpleApiKeyController.dispose();
    _simpleModelIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPreviewRankEnabled = prefs.getBool('is_preview_rank_enabled') ?? false;
      _themeMode = ThemeNotifier.instance.value;
      final configJson = prefs.getString('ai_configs') ?? '[]';
      _aiConfigs = AiConfig.decode(configJson);

      final embeddingJson = prefs.getString('embedding_config');
      if (embeddingJson != null) {
        _embeddingConfig = AiConfig.fromJson(jsonDecode(embeddingJson));
      } else {
        _embeddingConfig = AiConfig(
          id: 'embedding_default',
          name: 'Embedding 模型',
          type: 'google',
          model: 'gemini-embedding-2-preview',
          apiKey: '',
        );
      }
      _isEmbeddingInitialized = true;
      _isAdvancedModelMode = prefs.getBool('is_advanced_model_mode') ?? false;

      // Sync simple mode controllers from current configs
      if (_aiConfigs.isNotEmpty) {
        final firstGoogle = _aiConfigs.firstWhere(
          (c) => c.type == 'google',
          orElse: () =>
              AiConfig(id: '', name: '', type: '', model: '', apiKey: ''),
        );
        if (firstGoogle.id.isNotEmpty) {
          _simpleApiKeyController.text = firstGoogle.apiKey;
          if ([
            'gemini-3.1-flash-lite-preview',
            'gemini-flash-lite-latest',
            'gemma-4-31b-it',
          ].contains(firstGoogle.model)) {
            _selectedSimpleModel = firstGoogle.model;
          } else {
            _selectedSimpleModel = 'other';
            _simpleModelIdController.text = firstGoogle.model;
          }
        }
      } else if (_embeddingConfig.apiKey.isNotEmpty) {
        _simpleApiKeyController.text = _embeddingConfig.apiKey;
      }

      // Determine simple config status
      final primaryGoogle = _aiConfigs
          .where((c) => c.id == 'primary_google')
          .firstOrNull;
      if (primaryGoogle != null && primaryGoogle.apiKey.isNotEmpty) {
        _simpleConfigStatus = _SimpleConfigStatus.enabled;
      } else {
        _simpleConfigStatus = _SimpleConfigStatus.disabled;
      }
    });

    // Load database metadata (outside setState since we need async)
    final prefs2 = await SharedPreferences.getInstance();
    String courseDbSem = prefs2.getString('course_local_semester') ?? '';
    String courseDbTs = prefs2.getString('course_local_timestamp') ?? '';
    int courseDbCount = prefs2.getInt('course_db_course_count') ?? 0;
    String dbFilename = prefs2.getString('database_db_filename') ?? '';
    String dbEmbedModel = prefs2.getString('database_db_embedding_model') ?? '';
    int dbChunkCount = prefs2.getInt('database_db_chunk_count') ?? 0;
    String dbCreatedDate = prefs2.getString('database_db_created_date') ?? '';
    bool dbAutoUpdate = prefs2.getBool('database_db_auto_update') ?? true;
    String? selectedModel = prefs2.getString('selected_embedding_model');

    bool coursesDbExists = false;
    bool databaseDbExists = false;
    try {
      final dbPath = await Utils.getAppDbDirectory();
      coursesDbExists = await File(p.join(dbPath, "courses.db")).exists();
      databaseDbExists = await File(p.join(dbPath, "database.db")).exists();
    } catch (_) {
      coursesDbExists = LocalCourseService.instance.isInitialized;
      databaseDbExists = DatabaseEmbeddingService.instance.isInitialized;
    }

    // Query actual course count from DB if it exists
    int realCourseCount = courseDbCount;
    if (coursesDbExists) {
      try {
        realCourseCount = await LocalCourseService.instance.getCourseCount();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _courseDbSemester = courseDbSem;
        _courseDbTimestamp = courseDbTs;
        _courseDbCourseCount = realCourseCount;
        _databaseDbFilename = dbFilename;
        _databaseDbEmbeddingModel = dbEmbedModel;
        _databaseDbChunkCount = dbChunkCount;
        _databaseDbCreatedDate = dbCreatedDate;
        _isDatabaseDbAutoUpdate = dbAutoUpdate;
        _isCoursesDbExists = coursesDbExists;
        _isDatabaseDbExists = databaseDbExists;
        _selectedEmbeddingModel =
            selectedModel ?? (dbEmbedModel.isNotEmpty ? dbEmbedModel : null);
      });
    }
  }

  Future<void> _saveSelectedEmbeddingModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_embedding_model', model);
  }

  Future<void> _saveEmbeddingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'embedding_config',
      jsonEncode(_embeddingConfig.toJson()),
    );
  }

  Future<void> _saveAiConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_configs', AiConfig.encode(_aiConfigs));
  }

  void _syncSimpleConfigs() {
    final key = _simpleApiKeyController.text;
    final modelId = _selectedSimpleModel == 'other'
        ? _simpleModelIdController.text
        : _selectedSimpleModel ?? '';

    if (key.isEmpty && modelId.isEmpty) return;

    // Determine semantic name
    String modelName = "Google";
    if (_selectedSimpleModel == 'gemini-3.1-flash-lite-preview') {
      modelName = "Gemini 3.1 Flash-Lite";
    } else if (_selectedSimpleModel == 'gemini-flash-lite-latest') {
      modelName = "Flash";
    } else if (_selectedSimpleModel == 'gemma-4-31b-it') {
      modelName = "Gemma 4";
    }

    setState(() {
      // 1. Update Embedding Config
      _embeddingConfig = AiConfig(
        id: _embeddingConfig.id,
        name: _embeddingConfig.name,
        type: 'google',
        model: _embeddingConfig.model,
        apiKey: key,
      );

      // 2. Update/Create Primary Google Config
      int idx = _aiConfigs.indexWhere((c) => c.id == 'primary_google');
      final newConfig = AiConfig(
        id: 'primary_google',
        name: modelName,
        type: 'google',
        model: modelId,
        apiKey: key,
      );

      if (idx != -1) {
        _aiConfigs[idx] = newConfig;
      } else {
        _aiConfigs.insert(0, newConfig);
      }
    });

    _saveEmbeddingConfig();
    _saveAiConfigs();
  }

  Future<void> _testSimpleConnection() async {
    final key = _simpleApiKeyController.text;
    final modelId = _selectedSimpleModel == 'other'
        ? _simpleModelIdController.text
        : _selectedSimpleModel ?? '';

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
          _simpleTestMessage = "連線成功！AI 回應內容：\n$res";
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
      if (mounted) {
        setState(() => _isSimpleTesting = false);
      }
    }
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

  Future<void> _downloadCoursesDb() async {
    setState(() => _isCoursesDownloading = true);
    try {
      await CourseQueryService.instance.getCourses(forceRefresh: true);
      await _loadSettings(); // Reload metadata
      _showSnackBar("課程資料庫下載成功");
    } catch (e) {
      _showSnackBar("下載失敗: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isCoursesDownloading = false);
      }
    }
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sidebar Navigation
                      _buildLiquidGlassSidebar(isWide),

                      // Content Area
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildSelectedContent(),
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

  Widget _buildLiquidGlassSidebar(bool isWide) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;
    final width = isWide ? 200.0 : 120.0;

    const double itemHeight = 52.0;
    const double topPadding = 16.0;

    final categories = SettingsCategory.values;
    final icons = <IconData>[
      Icons.palette_rounded,
      Icons.settings_suggest_rounded,
      Icons.psychology_rounded,
      Icons.storage_rounded,
    ];
    final labels = <String>["介面設定", "功能設定", "模型設定", "資料庫"];

    final selectedIndex = categories.indexOf(_selectedCategory);

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1E2432).withOpacity(0.7),
                        const Color(0xFF252B3B).withOpacity(0.5),
                      ]
                    : [
                        Colors.white.withOpacity(0.6),
                        const Color(0xFFF0F4FF).withOpacity(0.4),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Animated sliding indicator
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  top: topPadding + selectedIndex * itemHeight + 4,
                  left: 8,
                  right: 8,
                  height: itemHeight - 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF6B9BF5).withOpacity(0.2)
                          : const Color(0xFFE3F2FD).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF6B9BF5).withOpacity(0.3)
                            : const Color(0xFF90CAF9).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // Nav items (always on top)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: topPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      categories.length,
                      (i) => SizedBox(
                        height: itemHeight,
                        child: _buildGlassNavItem(
                          categories[i],
                          icons[i],
                          labels[i],
                          isWide,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassNavItem(
    SettingsCategory category,
    IconData icon,
    String label,
    bool isWide,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedCategory == category;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(12),
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? colorScheme.accentBlue
                  : colorScheme.subtitleText,
            ),
            if (isWide) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.accentBlue
                        : colorScheme.primaryText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedContent() {
    switch (_selectedCategory) {
      case SettingsCategory.interface:
        return _buildInterfaceSettings();
      case SettingsCategory.feature:
        return _buildFeatureSettings();
      case SettingsCategory.model:
        return _buildModelSettings();
      case SettingsCategory.database:
        return _buildDatabaseSettings();
    }
  }

  Widget _buildInterfaceSettings() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey("interface"),
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle("介面外觀"),
        _buildSettingCard(
          child: Column(
            children: [
              _buildThemeOption(
                ThemeMode.system,
                Icons.brightness_auto_rounded,
              ),
              Divider(height: 1, indent: 56, color: colorScheme.borderColor),
              _buildThemeOption(ThemeMode.light, Icons.light_mode_rounded),
              Divider(height: 1, indent: 56, color: colorScheme.borderColor),
              _buildThemeOption(ThemeMode.dark, Icons.dark_mode_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureSettings() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey("feature"),
      padding: const EdgeInsets.all(24),
      children: [
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
    );
  }

  Widget _buildModelSettings() {
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
                  // Indicator
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
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeToggleItem(
                          label: "簡易模式",
                          isSelected: !_isAdvancedModelMode,
                          onTap: () async {
                            setState(() => _isAdvancedModelMode = false);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'is_advanced_model_mode',
                              false,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildModeToggleItem(
                          label: "進階模式",
                          isSelected: _isAdvancedModelMode,
                          onTap: () async {
                            setState(() => _isAdvancedModelMode = true);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('is_advanced_model_mode', true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        if (!_isAdvancedModelMode) ...[
          // Show tutorial at top if no LLM configs saved yet
          if (_aiConfigs.isEmpty) ...[
            _buildSectionTitle("新手教學"),
            _buildTutorialCard(),
            const SizedBox(height: 16),
          ],
          // === Simple Mode UI ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle("Google API 設定"),
              _buildSimpleConfigBadge(colorScheme),
            ],
          ),
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
                          'gemma-4-31b-it',
                          'other',
                        ].map((m) {
                          final isSelected = _selectedSimpleModel == m;
                          String label = m;
                          if (m == 'gemini-3.1-flash-lite-preview')
                            label = "Gemini 3.1 Flash-Lite";
                          if (m == 'gemini-flash-lite-latest') label = "Flash";
                          if (m == 'gemma-4-31b-it') label = "Gemma 4";
                          if (m == 'other') label = "其他";

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
                  if (_selectedSimpleModel == 'other') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _simpleModelIdController,
                      decoration: InputDecoration(
                        labelText: "自訂模型 ID",
                        hintText: "例如: gemini-1.5-pro",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Test Result Area
                  if (_simpleTestMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: (_isSimpleTestSuccess == true)
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_isSimpleTestSuccess == true)
                              ? Colors.green
                              : Colors.red,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            (_isSimpleTestSuccess == true)
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            color: (_isSimpleTestSuccess == true)
                                ? Colors.green
                                : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _simpleTestMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: (_isSimpleTestSuccess == true)
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Save & Test Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final key = _simpleApiKeyController.text.trim();
                            final modelId = _selectedSimpleModel == 'other'
                                ? _simpleModelIdController.text.trim()
                                : _selectedSimpleModel ?? '';
                            if (key.isEmpty) {
                              _showSnackBar("請先輸入 API Key", isError: true);
                              return;
                            }
                            if (modelId.isEmpty) {
                              _showSnackBar("請先選擇一個模型", isError: true);
                              return;
                            }
                            _syncSimpleConfigs();
                            setState(() {
                              if (_simpleConfigStatus ==
                                  _SimpleConfigStatus.disabled) {
                                _simpleConfigStatus =
                                    _SimpleConfigStatus.enabled;
                              } else {
                                _simpleConfigStatus =
                                    _SimpleConfigStatus.justUpdated;
                              }
                            });
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text("儲存設定"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.accentBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSimpleTesting
                              ? null
                              : _testSimpleConnection,
                          icon: _isSimpleTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
        ] else ...[
          // === Advanced Mode UI ===
          _buildSectionTitle("Embedding 數據向量化設定"),
          _buildEmbeddingConfigCard(),
          const SizedBox(height: 24),
          _buildSectionTitle("AI 模型清單"),
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
        ],
        const SizedBox(height: 32),
        // Show tutorial at bottom if configs exist (simple mode only)
        if (_isAdvancedModelMode == false && _aiConfigs.isNotEmpty) ...[
          _buildSectionTitle("新手教學"),
          _buildTutorialCard(),
        ],
      ],
    );
  }

  Widget _buildTutorialCard() {
    return _buildSettingCard(
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
            const Text("1. 前往 Google AI Studio 官方網站。"),
            const Text("2. 點擊「Get API key」並建立一個新的 Key。"),
            const Text("3. 在上面欄位輸入該 Key ，在選擇一個模型即可。"),
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

  Widget _buildSimpleConfigBadge(ColorScheme colorScheme) {
    String label;
    Color bgColor;
    Color textColor;

    switch (_simpleConfigStatus) {
      case _SimpleConfigStatus.disabled:
        label = "未啟用";
        bgColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
        break;
      case _SimpleConfigStatus.enabled:
        label = "啟用";
        bgColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green;
        break;
      case _SimpleConfigStatus.justUpdated:
        label = "更新成功";
        bgColor = colorScheme.accentBlue.withOpacity(0.15);
        textColor = colorScheme.accentBlue;
        break;
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
      if (mounted) {
        setState(() => _isEmbeddingTesting = false);
      }
    }
  }

  Widget _buildEmbeddingConfigCard() {
    if (!_isEmbeddingInitialized) return const SizedBox();
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
            // API Key
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
                  onPressed: () {
                    // Update and save
                  },
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
            // Model & Provider (Pre-filled, Locked)
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
                    onChanged: (val) {
                      if (_isEmbeddingEditing) {
                        // Split and update if needed, but easier to use a dialog for editing
                      }
                    },
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
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (_isEmbeddingTestSuccess == true)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isEmbeddingTestSuccess == true)
                        ? Colors.green
                        : Colors.red,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      (_isEmbeddingTestSuccess == true)
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: (_isEmbeddingTestSuccess == true)
                          ? Colors.green
                          : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _embeddingTestMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: (_isEmbeddingTestSuccess == true)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
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
    // Re-use _editAiConfig logic but tailored for embedding
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
                  _saveEmbeddingConfig();
                  _isEmbeddingEditing = false;
                });
                Navigator.pop(context);
              },
              child: const Text("確定"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseSettings() {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter databases by selected model
    final filteredDatabases = _availableDatabases.where((db) {
      if (_selectedEmbeddingModel == null) return true;
      return (db['embedding_model'] as String? ?? '') ==
          _selectedEmbeddingModel;
    }).toList();

    return ListView(
      key: const ValueKey("database"),
      padding: const EdgeInsets.all(16),
      children: [
        // === 課程資料庫區塊 ===
        Row(
          children: [
            Icon(Icons.library_books_rounded, color: colorScheme.accentBlue),
            const SizedBox(width: 8),
            Text(
              "課程資料庫",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "包含全校課程與教師資訊。選課指南的大多數功能與此資料庫相關。",
          style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle("目前狀態"),
        _buildSettingCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCoursesDbExists
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _isCoursesDbExists ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCoursesDbExists ? "已下載" : "尚未下載",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isCoursesDbExists
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (_isCoursesDbExists) ...[
                  const SizedBox(height: 8),
                  _buildDbInfoRow("學期", _courseDbSemester),
                  _buildDbInfoRow("更新時間", _courseDbTimestamp),
                  _buildDbInfoRow("課程數量", _courseDbCourseCount.toString()),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteCoursesDb(),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("刪除"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "課程資料庫將在登入後自動下載。若尚未下載，可點擊右側按鈕手動更新。",
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.subtitleText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isCoursesDownloading
                            ? null
                            : _downloadCoursesDb,
                        icon: _isCoursesDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(_isCoursesDownloading ? "下載中..." : "手動下載"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.accentBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 24),

        // === 評價資料庫區塊 ===
        Row(
          children: [
            Icon(Icons.forum_rounded, color: colorScheme.accentBlue),
            const SizedBox(width: 8),
            Text(
              "評價 (向量) 資料庫",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "提供過往學生的修課真實評價，依賴 Embedding 模型進行搜尋。下方所有設定皆與此資料庫相關。",
          style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
        ),
        const SizedBox(height: 16),

        _buildSectionTitle("目前狀態"),
        _buildSettingCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isDatabaseDbExists
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _isDatabaseDbExists ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isDatabaseDbExists ? "已下載" : "尚未下載",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDatabaseDbExists
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (_isDatabaseDbExists) ...[
                  const SizedBox(height: 8),
                  _buildDbInfoRow("Embedding 模型", _databaseDbEmbeddingModel),
                  _buildDbInfoRow("檔案名稱", _databaseDbFilename),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    "請從下方下載評價資料庫，AI 聊天功能需要此資料庫才能運作。",
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ],
                if (_isDatabaseDbExists)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteDatabaseDb(),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("刪除"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // === Auto Update ===
        _buildSectionTitle("自動更新"),
        _buildSettingCard(
          child: SwitchListTile.adaptive(
            title: Text(
              "評價資料庫",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            subtitle: Text(
              "啟動時自動檢查並下載最新版本",
              style: TextStyle(color: colorScheme.subtitleText),
            ),
            value: _isDatabaseDbAutoUpdate,
            onChanged: (val) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('database_db_auto_update', val);
              setState(() => _isDatabaseDbAutoUpdate = val);
            },
            activeColor: colorScheme.accentBlue,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("可下載的資料庫"),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: _fetchAvailableDatabases,
                icon: _isLoadingDatabases
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  _isLoadingDatabases ? "載入中..." : "重新整理",
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.accentBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text("""選擇 Embedding 模型後，將只顯示對應的資料庫版本。\n
可以隨機選取一種資料庫下載，若是出現問題可以換下載其他類型的。   
          """, style: TextStyle(fontSize: 12, color: colorScheme.subtitleText)),
        const SizedBox(height: 8),
        // Model selector
        if (_availableEmbeddingModels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableEmbeddingModels.map((model) {
                final isSelected = _selectedEmbeddingModel == model;
                return ChoiceChip(
                  label: Text(
                    model,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : colorScheme.primaryText,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedEmbeddingModel = model);
                      _saveSelectedEmbeddingModel(model);
                    }
                  },
                  selectedColor: colorScheme.accentBlue,
                  backgroundColor: colorScheme.isDark
                      ? Colors.white10
                      : Colors.grey[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                  elevation: isSelected ? 2 : 0,
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        if (_availableDatabases.isEmpty && !_isLoadingDatabases)
          _buildSettingCard(
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Text(
                  "點擊「重新整理」以查看可下載的資料庫",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ...filteredDatabases
            .take(_maxDisplayedDatabases)
            .map(
              (db) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAvailableDbCard(db, colorScheme),
              ),
            ),

        if (filteredDatabases.length > _maxDisplayedDatabases)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _maxDisplayedDatabases += 10;
                  });
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  "顯示更多 (還有 ${filteredDatabases.length - _maxDisplayedDatabases} 個)",
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.accentBlue,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDbInfoRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    String displayValue = value.isEmpty ? "—" : value;

    // Format semester if it's 4 digits (e.g., 1142 -> 114-2)
    if (label == "學期" && value.length == 4) {
      displayValue = "${value.substring(0, 3)}-${value.substring(3)}";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.subtitleText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(fontSize: 13, color: colorScheme.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDbCard(
    Map<String, dynamic> db,
    ColorScheme colorScheme,
  ) {
    final filename = db['db_filename'] as String? ?? '';
    final embeddingModel = db['embedding_model'] as String? ?? '';
    final lastUpdated = db['last_updated'] as String? ?? '';
    final isInstalled = filename == _databaseDbFilename;
    final isDownloading = filename == _downloadingFilename;

    return _buildSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          filename,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.primaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isInstalled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green, width: 0.5),
                          ),
                          child: const Text(
                            "已下載",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    embeddingModel,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                  if (lastUpdated.isNotEmpty)
                    Text(
                      lastUpdated,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.subtitleText.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (!isInstalled) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isDownloading ? null : () => _downloadDatabaseDb(db),
                icon: isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(isDownloading ? "下載中..." : "下載"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAvailableDatabases() async {
    setState(() => _isLoadingDatabases = true);
    try {
      final client = http.Client();
      try {
        final res = await client.get(
          Uri.parse(
            'https://edwinchu0711.github.io/CourseSelectionDateUpdate/database/version.json',
          ),
        );
        if (res.statusCode == 200) {
          final List<dynamic> list = jsonDecode(res.body);
          final databases = list.cast<Map<String, dynamic>>();

          // Extract unique embedding models
          final models = <String>{};
          for (final db in databases) {
            final model = db['embedding_model'] as String? ?? '';
            if (model.isNotEmpty) models.add(model);
          }

          // Sort databases by last_updated (newest first)
          databases.sort((a, b) {
            final dateA =
                a['last_updated'] as String? ??
                a['created_date'] as String? ??
                '';
            final dateB =
                b['last_updated'] as String? ??
                b['created_date'] as String? ??
                '';
            return dateB.compareTo(dateA);
          });

          if (mounted) {
            setState(() {
              _availableDatabases = databases;
              _availableEmbeddingModels = models.toList()..sort();
              // Default to selected model, or first available, or installed model
              if (_selectedEmbeddingModel == null ||
                  !_availableEmbeddingModels.contains(
                    _selectedEmbeddingModel,
                  )) {
                _selectedEmbeddingModel = _availableEmbeddingModels.isNotEmpty
                    ? _availableEmbeddingModels.first
                    : null;
              }
            });
          }
        } else {
          _showSnackBar("無法取得資料庫清單 (HTTP ${res.statusCode})", isError: true);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _showSnackBar("取得資料庫清單失敗: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingDatabases = false);
    }
  }

  Future<void> _downloadDatabaseDb(Map<String, dynamic> db) async {
    final filename = db['db_filename'] as String?;
    if (filename == null || filename.isEmpty) return;

    setState(() => _downloadingFilename = filename);
    try {
      await DatabaseEmbeddingService.instance.downloadDatabase(
        filename,
        embeddingModel: db['embedding_model'] as String?,
        chunkCount: db['chunk_count'] as int?,
        createdDate: db['created_date'] as String?,
      );
      if (mounted) {
        setState(() {
          _isDatabaseDbExists = true;
          _databaseDbFilename = filename;
          _databaseDbEmbeddingModel = db['embedding_model'] as String? ?? '';
          _databaseDbChunkCount = db['chunk_count'] as int? ?? 0;
          _databaseDbCreatedDate = db['created_date'] as String? ?? '';
        });
        _showSnackBar("資料庫下載完成");
      }
    } catch (e) {
      _showSnackBar("下載失敗: $e", isError: true);
    } finally {
      if (mounted) setState(() => _downloadingFilename = null);
    }
  }

  void _deleteCoursesDb() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除課程資料庫"),
        content: const Text(
          "確定要刪除 courses.db 嗎？刪除後 AI 聊天將無法使用課程搜尋功能，直到下次登入時自動重建。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalCourseService.instance.deleteCoursesDb();
              if (mounted) {
                setState(() {
                  _isCoursesDbExists = false;
                  _courseDbSemester = '';
                  _courseDbTimestamp = '';
                  _courseDbCourseCount = 0;
                });
                _showSnackBar("課程資料庫已刪除");
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除"),
          ),
        ],
      ),
    );
  }

  void _deleteDatabaseDb() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除評價資料庫"),
        content: const Text("確定要刪除 database.db 嗎？刪除後 AI 聊天功能將無法使用，直到重新下載。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseEmbeddingService.instance.deleteDatabase();
              if (mounted) {
                setState(() {
                  _isDatabaseDbExists = false;
                  _databaseDbFilename = '';
                  _databaseDbEmbeddingModel = '';
                  _databaseDbChunkCount = 0;
                  _databaseDbCreatedDate = '';
                });
                _showSnackBar("評價資料庫已刪除");
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除"),
          ),
        ],
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
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  config.type == 'google'
                      ? Icons.auto_awesome
                      : Icons.api_rounded,
                  color: Theme.of(context).colorScheme.accentBlue,
                ),
                title: Row(
                  children: [
                    Text(
                      config.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primaryText,
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.subtitleText,
                      ),
                    ),
                    Text(
                      "Key: ${_maskApiKey(config.apiKey)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.subtitleText.withOpacity(0.7),
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
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).colorScheme.borderColor,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _maskApiKey(String key) {
    if (key.length <= 8) return "********";
    return "${key.substring(0, 4)}...${key.substring(key.length - 4)}";
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
                _saveAiConfigs();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除"),
          ),
        ],
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
                    // 1. 類別
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
                            if (type == 'google') {
                              if (modelController.text.isEmpty) {
                                modelController.text =
                                    "gemini-flash-lite-latest";
                              }
                            } else {
                              if (urlController.text.isEmpty) {
                                urlController.text =
                                    "https://api.openai.com/v1/chat/completions";
                              }
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. 名稱
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

                    // 3. API KEY (重點放在這)
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

                    // 4. 模型名稱
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

                    // 5. Base URL
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
                              : "提供相容服務的完整 URL，如 https://api.groq.com/v1/chat/completions",
                          child: const Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 測試結果顯示區域
                    if (testResultMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: (isTestSuccess == true)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isTestSuccess == true)
                                ? Colors.green
                                : Colors.red,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              (isTestSuccess == true)
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: (isTestSuccess == true)
                                  ? Colors.green
                                  : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                testResultMessage!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: (isTestSuccess == true)
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 測試按鈕
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
                                    testResultMessage = "連線成功！AI 回應內容：\n$res";
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
                    _saveAiConfigs();
                  });
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
                "Google 的輕量旗艦，具備極佳的推理能力與超長上下文處理，特別適合處理複雜邏輯與大量文本摘要，使用額度高，有時會遇到API 流量限制的問題。",
              ),
              const SizedBox(height: 16),
              _buildModelDescItem(
                "Flash (Latest)",
                "目前穩定性最高且維護成本極簡的模型，不同期間會是不同的模型，因此使用額度不定。",
              ),
              const SizedBox(height: 16),
              _buildModelDescItem(
                "Gemma 4",
                "基於 Google 開源架構優化的模型，但也是這三種模型中推理能力最弱的，可以應付最基本的問答，回復速度最慢，但額度非常多。",
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
}
