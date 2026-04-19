/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../utils/utils.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_theme.dart';
import '../models/ai_config_model.dart';
import '../services/local_course_service.dart';
import '../services/database_embedding_service.dart';
import 'settings/interface_settings_section.dart';
import 'settings/feature_settings_section.dart';
import 'settings/model_settings_section.dart';
import 'settings/database_settings_section.dart';

enum SettingsCategory { interface, feature, model, database }

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
  bool _isDatabaseDbAutoUpdate = true;
  List<Map<String, dynamic>> _availableDatabases = [];
  bool _isLoadingDatabases = false;
  String? _downloadingFilename;
  String? _selectedEmbeddingModel;
  List<String> _availableEmbeddingModels = [];
  bool _isAdvancedModelMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchAvailableDatabases();
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
    });

    // Load database metadata
    final prefs2 = await SharedPreferences.getInstance();
    String courseDbSem = prefs2.getString('course_local_semester') ?? '';
    String courseDbTs = prefs2.getString('course_local_timestamp') ?? '';
    int courseDbCount = prefs2.getInt('course_db_course_count') ?? 0;
    String dbFilename = prefs2.getString('database_db_filename') ?? '';
    String dbEmbedModel = prefs2.getString('database_db_embedding_model') ?? '';
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
        _isDatabaseDbAutoUpdate = dbAutoUpdate;
        _isCoursesDbExists = coursesDbExists;
        _isDatabaseDbExists = databaseDbExists;
        _selectedEmbeddingModel =
            selectedModel ?? (dbEmbedModel.isNotEmpty ? dbEmbedModel : null);
      });
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
          final models = <String>{};
          for (final db in databases) {
            final model = db['embedding_model'] as String? ?? '';
            if (model.isNotEmpty) models.add(model);
          }
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
        }
      } finally {
        client.close();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingDatabases = false);
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await ThemeNotifier.instance.setThemeMode(mode);
  }

  Future<void> _togglePreviewRank(bool value) async {
    setState(() => _isPreviewRankEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_preview_rank_enabled', value);
    if (value) _showSnackBar("已開啟預覽名次功能，下次查詢成績時生效");
  }

  Future<void> _setAdvancedModelMode(bool value) async {
    setState(() => _isAdvancedModelMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_advanced_model_mode', value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 900;

    // Compute simple config status for ModelSettingsSection
    SimpleConfigStatus simpleConfigStatus = SimpleConfigStatus.disabled;
    final primaryGoogle = _aiConfigs
        .where((c) => c.id == 'primary_google')
        .firstOrNull;
    if (primaryGoogle != null && primaryGoogle.apiKey.isNotEmpty) {
      simpleConfigStatus = SimpleConfigStatus.enabled;
    }

    // Compute selectedSimpleModel
    String? selectedSimpleModel;
    if (_aiConfigs.isNotEmpty) {
      final firstGoogle = _aiConfigs.firstWhere(
        (c) => c.type == 'google',
        orElse: () =>
            AiConfig(id: '', name: '', type: '', model: '', apiKey: ''),
      );
      if (firstGoogle.id.isNotEmpty) {
        if ([
          'gemini-3.1-flash-lite-preview',
          'gemini-flash-lite-latest',
          'gemma-4-31b-it',
        ].contains(firstGoogle.model)) {
          selectedSimpleModel = firstGoogle.model;
        } else {
          selectedSimpleModel = 'other';
        }
      }
    }

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
                      _buildLiquidGlassSidebar(isWide),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildSelectedContent(
                            simpleConfigStatus,
                            selectedSimpleModel,
                          ),
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

  Widget _buildSelectedContent(
    SimpleConfigStatus simpleConfigStatus,
    String? selectedSimpleModel,
  ) {
    switch (_selectedCategory) {
      case SettingsCategory.interface:
        return InterfaceSettingsSection(
          themeMode: _themeMode,
          onThemeChanged: _setThemeMode,
        );
      case SettingsCategory.feature:
        return FeatureSettingsSection(
          isPreviewRankEnabled: _isPreviewRankEnabled,
          onPreviewRankChanged: _togglePreviewRank,
        );
      case SettingsCategory.model:
        return ModelSettingsSection(
          isAdvancedModelMode: _isAdvancedModelMode,
          aiConfigs: _aiConfigs,
          embeddingConfig: _embeddingConfig,
          isEmbeddingInitialized: _isEmbeddingInitialized,
          isEmbeddingEditing: _isEmbeddingEditing,
          selectedSimpleModel: selectedSimpleModel,
          simpleConfigStatus: simpleConfigStatus,
          onAdvancedModeChanged: _setAdvancedModelMode,
          onReload: _loadSettings,
        );
      case SettingsCategory.database:
        return DatabaseSettingsSection(
          isCoursesDbExists: _isCoursesDbExists,
          courseDbSemester: _courseDbSemester,
          courseDbTimestamp: _courseDbTimestamp,
          courseDbCourseCount: _courseDbCourseCount,
          isDatabaseDbExists: _isDatabaseDbExists,
          databaseDbFilename: _databaseDbFilename,
          databaseDbEmbeddingModel: _databaseDbEmbeddingModel,
          isDatabaseDbAutoUpdate: _isDatabaseDbAutoUpdate,
          selectedEmbeddingModel: _selectedEmbeddingModel,
          availableEmbeddingModels: _availableEmbeddingModels,
          availableDatabases: _availableDatabases,
          isLoadingDatabases: _isLoadingDatabases,
          downloadingFilename: _downloadingFilename,
          onReload: _loadSettings,
        );
    }
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
            onPressed: () => context.go('/home'),
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
}
