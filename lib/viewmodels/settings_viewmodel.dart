import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_config_model.dart';
import '../services/ai/ai_client.dart';
import '../services/local_course_service.dart';
import '../services/database_embedding_service.dart';
import '../theme/theme_notifier.dart';
import '../utils/utils.dart';
import '../providers/app_providers.dart';

enum SimpleConfigStatus { disabled, enabled, justUpdated }

class SettingsState {
  static AiConfig defaultEmbeddingConfig() => AiConfig(
    id: 'embedding_default',
    name: 'Embedding 模型',
    type: 'google',
    model: 'gemini-embedding-2-preview',
    apiKey: '',
  );

  final bool isPreviewRankEnabled;
  final ThemeMode themeMode;
  final List<AiConfig> aiConfigs;
  final AiConfig embeddingConfig;
  final bool isEmbeddingInitialized;
  final bool isAdvancedModelMode;

  // Database state
  final bool isCoursesDbExists;
  final String courseDbSemester;
  final String courseDbTimestamp;
  final int courseDbCourseCount;
  final bool isDatabaseDbExists;
  final String databaseDbFilename;
  final String databaseDbEmbeddingModel;
  final int databaseDbChunkCount;
  final String databaseDbCreatedDate;
  final bool isDatabaseDbAutoUpdate;
  final List<Map<String, dynamic>> availableDatabases;
  final bool isLoadingDatabases;
  final String? downloadingFilename;
  final String? selectedEmbeddingModel;
  final List<String> availableEmbeddingModels;
  final bool isCoursesDownloading;
  final bool isEmbeddingTesting;

  // Simple config state
  final SimpleConfigStatus simpleConfigStatus;
  final bool isSimpleTesting;
  final String? simpleTestMessage;
  final bool? isSimpleTestSuccess;
  final String? selectedSimpleModel;
  final bool isEmbeddingTestSuccess;
  final String? embeddingTestMessage;

  SettingsState({
    this.isPreviewRankEnabled = false,
    this.themeMode = ThemeMode.system,
    this.aiConfigs = const [],
    AiConfig? embeddingConfig,
    this.isEmbeddingInitialized = false,
    this.isAdvancedModelMode = false,
    this.isCoursesDbExists = false,
    this.courseDbSemester = '',
    this.courseDbTimestamp = '',
    this.courseDbCourseCount = 0,
    this.isDatabaseDbExists = false,
    this.databaseDbFilename = '',
    this.databaseDbEmbeddingModel = '',
    this.databaseDbChunkCount = 0,
    this.databaseDbCreatedDate = '',
    this.isDatabaseDbAutoUpdate = true,
    this.availableDatabases = const [],
    this.isLoadingDatabases = false,
    this.downloadingFilename,
    this.selectedEmbeddingModel,
    this.availableEmbeddingModels = const [],
    this.isCoursesDownloading = false,
    this.isEmbeddingTesting = false,
    this.simpleConfigStatus = SimpleConfigStatus.disabled,
    this.isSimpleTesting = false,
    this.simpleTestMessage,
    this.isSimpleTestSuccess,
    this.selectedSimpleModel,
    this.isEmbeddingTestSuccess = false,
    this.embeddingTestMessage,
  }) : embeddingConfig = embeddingConfig ?? defaultEmbeddingConfig();

  SettingsState copyWith({
    bool? isPreviewRankEnabled,
    ThemeMode? themeMode,
    List<AiConfig>? aiConfigs,
    AiConfig? embeddingConfig,
    bool? isEmbeddingInitialized,
    bool? isAdvancedModelMode,
    bool? isCoursesDbExists,
    String? courseDbSemester,
    String? courseDbTimestamp,
    int? courseDbCourseCount,
    bool? isDatabaseDbExists,
    String? databaseDbFilename,
    String? databaseDbEmbeddingModel,
    int? databaseDbChunkCount,
    String? databaseDbCreatedDate,
    bool? isDatabaseDbAutoUpdate,
    List<Map<String, dynamic>>? availableDatabases,
    bool? isLoadingDatabases,
    String? downloadingFilename,
    String? selectedEmbeddingModel,
    List<String>? availableEmbeddingModels,
    bool? isCoursesDownloading,
    bool? isEmbeddingTesting,
    SimpleConfigStatus? simpleConfigStatus,
    bool? isSimpleTesting,
    String? simpleTestMessage,
    bool? isSimpleTestSuccess,
    String? selectedSimpleModel,
    bool? isEmbeddingTestSuccess,
    String? embeddingTestMessage,
  }) {
    return SettingsState(
      isPreviewRankEnabled: isPreviewRankEnabled ?? this.isPreviewRankEnabled,
      themeMode: themeMode ?? this.themeMode,
      aiConfigs: aiConfigs ?? this.aiConfigs,
      embeddingConfig: embeddingConfig ?? this.embeddingConfig,
      isEmbeddingInitialized: isEmbeddingInitialized ?? this.isEmbeddingInitialized,
      isAdvancedModelMode: isAdvancedModelMode ?? this.isAdvancedModelMode,
      isCoursesDbExists: isCoursesDbExists ?? this.isCoursesDbExists,
      courseDbSemester: courseDbSemester ?? this.courseDbSemester,
      courseDbTimestamp: courseDbTimestamp ?? this.courseDbTimestamp,
      courseDbCourseCount: courseDbCourseCount ?? this.courseDbCourseCount,
      isDatabaseDbExists: isDatabaseDbExists ?? this.isDatabaseDbExists,
      databaseDbFilename: databaseDbFilename ?? this.databaseDbFilename,
      databaseDbEmbeddingModel: databaseDbEmbeddingModel ?? this.databaseDbEmbeddingModel,
      databaseDbChunkCount: databaseDbChunkCount ?? this.databaseDbChunkCount,
      databaseDbCreatedDate: databaseDbCreatedDate ?? this.databaseDbCreatedDate,
      isDatabaseDbAutoUpdate: isDatabaseDbAutoUpdate ?? this.isDatabaseDbAutoUpdate,
      availableDatabases: availableDatabases ?? this.availableDatabases,
      isLoadingDatabases: isLoadingDatabases ?? this.isLoadingDatabases,
      downloadingFilename: downloadingFilename ?? this.downloadingFilename,
      selectedEmbeddingModel: selectedEmbeddingModel ?? this.selectedEmbeddingModel,
      availableEmbeddingModels: availableEmbeddingModels ?? this.availableEmbeddingModels,
      isCoursesDownloading: isCoursesDownloading ?? this.isCoursesDownloading,
      isEmbeddingTesting: isEmbeddingTesting ?? this.isEmbeddingTesting,
      simpleConfigStatus: simpleConfigStatus ?? this.simpleConfigStatus,
      isSimpleTesting: isSimpleTesting ?? this.isSimpleTesting,
      simpleTestMessage: simpleTestMessage ?? this.simpleTestMessage,
      isSimpleTestSuccess: isSimpleTestSuccess ?? this.isSimpleTestSuccess,
      selectedSimpleModel: selectedSimpleModel ?? this.selectedSimpleModel,
      isEmbeddingTestSuccess: isEmbeddingTestSuccess ?? this.isEmbeddingTestSuccess,
      embeddingTestMessage: embeddingTestMessage ?? this.embeddingTestMessage,
    );
  }
}

final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
  return SettingsViewModel(ref);
});

class SettingsViewModel extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsViewModel(this._ref) : super(SettingsState());

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final embeddingConfig = _loadEmbeddingConfig(prefs);
    final aiConfigs = _loadAiConfigs(prefs);
    final isAdvancedModelMode = prefs.getBool('is_advanced_model_mode') ?? false;
    final isPreviewRankEnabled = prefs.getBool('is_preview_rank_enabled') ?? false;
    final themeMode = ThemeNotifier.instance.value;

    // Sync simple mode from AI configs
    String? selectedSimpleModel;
    String simpleApiKey = '';
    String simpleModelId = '';
    SimpleConfigStatus simpleConfigStatus = SimpleConfigStatus.disabled;

    if (aiConfigs.isNotEmpty) {
      final firstGoogle = aiConfigs.firstWhere(
        (c) => c.type == 'google',
        orElse: () => AiConfig(id: '', name: '', type: '', model: '', apiKey: ''),
      );
      if (firstGoogle.id.isNotEmpty) {
        simpleApiKey = firstGoogle.apiKey;
        if (['gemini-3.1-flash-lite-preview', 'gemini-flash-lite-latest', 'gemma-4-31b-it']
            .contains(firstGoogle.model)) {
          selectedSimpleModel = firstGoogle.model;
        } else {
          selectedSimpleModel = 'other';
          simpleModelId = firstGoogle.model;
        }
      }
    }
    if (simpleApiKey.isEmpty && simpleModelId.isEmpty) {
      if (embeddingConfig.apiKey.isNotEmpty) {
        simpleApiKey = embeddingConfig.apiKey;
      }
      selectedSimpleModel = null;
    }

    final primaryGoogle = aiConfigs.where((c) => c.id == 'primary_google').firstOrNull;
    if (primaryGoogle != null && primaryGoogle.apiKey.isNotEmpty) {
      simpleConfigStatus = SimpleConfigStatus.enabled;
    }

    // Load database metadata
    final dbState = await _loadDatabaseState(prefs);

    state = state.copyWith(
      isPreviewRankEnabled: isPreviewRankEnabled,
      themeMode: themeMode,
      aiConfigs: aiConfigs,
      embeddingConfig: embeddingConfig,
      isEmbeddingInitialized: true,
      isAdvancedModelMode: isAdvancedModelMode,
      selectedSimpleModel: selectedSimpleModel,
      simpleConfigStatus: simpleConfigStatus,
      isCoursesDbExists: dbState.isCoursesDbExists,
      courseDbSemester: dbState.courseDbSemester,
      courseDbTimestamp: dbState.courseDbTimestamp,
      courseDbCourseCount: dbState.courseDbCourseCount,
      isDatabaseDbExists: dbState.isDatabaseDbExists,
      databaseDbFilename: dbState.databaseDbFilename,
      databaseDbEmbeddingModel: dbState.databaseDbEmbeddingModel,
      databaseDbChunkCount: dbState.databaseDbChunkCount,
      databaseDbCreatedDate: dbState.databaseDbCreatedDate,
      isDatabaseDbAutoUpdate: dbState.isDatabaseDbAutoUpdate,
      selectedEmbeddingModel: dbState.selectedEmbeddingModel,
    );
  }

  AiConfig _loadEmbeddingConfig(SharedPreferences prefs) {
    final embeddingJson = prefs.getString('embedding_config');
    if (embeddingJson != null) {
      return AiConfig.fromJson(jsonDecode(embeddingJson));
    }
    return SettingsState.defaultEmbeddingConfig();
  }

  List<AiConfig> _loadAiConfigs(SharedPreferences prefs) {
    final configJson = prefs.getString('ai_configs') ?? '[]';
    return AiConfig.decode(configJson);
  }

  Future<({bool isCoursesDbExists, String courseDbSemester, String courseDbTimestamp, int courseDbCourseCount, bool isDatabaseDbExists, String databaseDbFilename, String databaseDbEmbeddingModel, int databaseDbChunkCount, String databaseDbCreatedDate, bool isDatabaseDbAutoUpdate, String? selectedEmbeddingModel})> _loadDatabaseState(SharedPreferences prefs) async {
    String courseDbSem = prefs.getString('course_local_semester') ?? '';
    String courseDbTs = prefs.getString('course_local_timestamp') ?? '';
    int courseDbCount = prefs.getInt('course_db_course_count') ?? 0;
    String dbFilename = prefs.getString('database_db_filename') ?? '';
    String dbEmbedModel = prefs.getString('database_db_embedding_model') ?? '';
    int dbChunkCount = prefs.getInt('database_db_chunk_count') ?? 0;
    String dbCreatedDate = prefs.getString('database_db_created_date') ?? '';
    bool dbAutoUpdate = prefs.getBool('database_db_auto_update') ?? true;
    String? selectedModel = prefs.getString('selected_embedding_model');

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

    return (
      isCoursesDbExists: coursesDbExists,
      courseDbSemester: courseDbSem,
      courseDbTimestamp: courseDbTs,
      courseDbCourseCount: realCourseCount,
      isDatabaseDbExists: databaseDbExists,
      databaseDbFilename: dbFilename,
      databaseDbEmbeddingModel: dbEmbedModel,
      databaseDbChunkCount: dbChunkCount,
      databaseDbCreatedDate: dbCreatedDate,
      isDatabaseDbAutoUpdate: dbAutoUpdate,
      selectedEmbeddingModel: selectedModel ?? (dbEmbedModel.isNotEmpty ? dbEmbedModel : null),
    );
  }

  Future<void> togglePreviewRank(bool value) async {
    state = state.copyWith(isPreviewRankEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_preview_rank_enabled', value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ThemeNotifier.instance.setThemeMode(mode);
  }

  Future<void> downloadCoursesDb() async {
    state = state.copyWith(isCoursesDownloading: true);
    try {
      await _ref.read(courseQueryServiceProvider).getCourses(forceRefresh: true);
      await loadSettings();
    } catch (e) {
      rethrow;
    } finally {
      state = state.copyWith(isCoursesDownloading: false);
    }
  }

  Future<void> testSimpleConnection(String apiKey, String modelId) async {
    if (apiKey.isEmpty) {
      state = state.copyWith(
        simpleTestMessage: "請先輸入 API KEY",
        isSimpleTestSuccess: false,
      );
      return;
    }

    state = state.copyWith(
      isSimpleTesting: true,
      simpleTestMessage: "正在連線測試中...",
      isSimpleTestSuccess: null,
    );

    final testConfig = AiConfig(
      id: "simple_test",
      name: "Simple Test",
      type: 'google',
      model: modelId,
      apiKey: apiKey,
    );

    final client = AiClient(config: testConfig);
    try {
      final res = await client.generateContent(
        [],
        "你好，請簡短回傳「連線成功」四個字。",
        temperature: 0.1,
        maxOutputTokens: 50,
      );
      state = state.copyWith(
        simpleTestMessage: "連線成功！AI 回應內容：\n$res",
        isSimpleTestSuccess: true,
        isSimpleTesting: false,
      );
    } catch (e) {
      state = state.copyWith(
        simpleTestMessage: "連線失敗：$e",
        isSimpleTestSuccess: false,
        isSimpleTesting: false,
      );
    }
  }

  void syncSimpleConfigs(String apiKey, String modelId, String modelDisplayName) {
    if (apiKey.isEmpty && modelId.isEmpty) return;

    final newEmbeddingConfig = AiConfig(
      id: state.embeddingConfig.id,
      name: state.embeddingConfig.name,
      type: 'google',
      model: state.embeddingConfig.model,
      apiKey: apiKey,
    );

    final newConfig = AiConfig(
      id: 'primary_google',
      name: modelDisplayName,
      type: 'google',
      model: modelId,
      apiKey: apiKey,
    );

    List<AiConfig> updatedConfigs = List.from(state.aiConfigs);
    int idx = updatedConfigs.indexWhere((c) => c.id == 'primary_google');
    if (idx != -1) {
      updatedConfigs[idx] = newConfig;
    } else {
      updatedConfigs.insert(0, newConfig);
    }

    state = state.copyWith(
      embeddingConfig: newEmbeddingConfig,
      aiConfigs: updatedConfigs,
    );

    _saveEmbeddingConfig();
    _saveAiConfigs();
  }

  Future<void> _saveAiConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_configs', AiConfig.encode(state.aiConfigs));
  }

  Future<void> _saveEmbeddingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'embedding_config',
      jsonEncode(state.embeddingConfig.toJson()),
    );
  }

  Future<void> saveSelectedEmbeddingModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_embedding_model', model);
  }

  void updateSimpleConfigStatus(SimpleConfigStatus status) {
    state = state.copyWith(simpleConfigStatus: status);
  }

  void updateSelectedSimpleModel(String? model) {
    state = state.copyWith(selectedSimpleModel: model);
  }

  void updateSimpleTestResult({String? message, bool? success}) {
    state = state.copyWith(
      simpleTestMessage: message,
      isSimpleTestSuccess: success,
    );
  }
}