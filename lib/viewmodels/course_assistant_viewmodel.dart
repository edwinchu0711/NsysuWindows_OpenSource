import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_model.dart';
import '../models/custom_event_model.dart';
import '../models/ai_config_model.dart';
import '../services/ai/ai_service.dart';

class CourseAssistantState {
  final List<Course> assistantCourses;
  final List<CustomEvent> customEvents;
  final bool isLoading;
  final AssistantAction currentAction;
  final Course? selectedCourseForDetail;
  final CustomEvent? selectedEventForDetail;
  final AiService? aiService;
  final List<AiConfig> aiConfigs;
  final String? selectedAiConfigId;
  final bool hasEmbeddingApiKey;

  const CourseAssistantState({
    this.assistantCourses = const [],
    this.customEvents = const [],
    this.isLoading = false,
    this.currentAction = AssistantAction.addCourse,
    this.selectedCourseForDetail,
    this.selectedEventForDetail,
    this.aiService,
    this.aiConfigs = const [],
    this.selectedAiConfigId,
    this.hasEmbeddingApiKey = false,
  });

  CourseAssistantState copyWith({
    List<Course>? assistantCourses,
    List<CustomEvent>? customEvents,
    bool? isLoading,
    AssistantAction? currentAction,
    Course? selectedCourseForDetail,
    CustomEvent? selectedEventForDetail,
    AiService? aiService,
    List<AiConfig>? aiConfigs,
    String? selectedAiConfigId,
    bool? hasEmbeddingApiKey,
  }) {
    return CourseAssistantState(
      assistantCourses: assistantCourses ?? this.assistantCourses,
      customEvents: customEvents ?? this.customEvents,
      isLoading: isLoading ?? this.isLoading,
      currentAction: currentAction ?? this.currentAction,
      selectedCourseForDetail:
          selectedCourseForDetail ?? this.selectedCourseForDetail,
      selectedEventForDetail:
          selectedEventForDetail ?? this.selectedEventForDetail,
      aiService: aiService ?? this.aiService,
      aiConfigs: aiConfigs ?? this.aiConfigs,
      selectedAiConfigId: selectedAiConfigId ?? this.selectedAiConfigId,
      hasEmbeddingApiKey: hasEmbeddingApiKey ?? this.hasEmbeddingApiKey,
    );
  }

  String getTotalCredits() {
    double total = 0.0;
    for (var c in assistantCourses) {
      double? cred = double.tryParse(c.credits);
      if (cred != null) total += cred;
    }
    return total.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
}

enum AssistantAction { none, addCourse, addEvent, import, export, aiAssistant }

final courseAssistantViewModelProvider =
    StateNotifierProvider<CourseAssistantViewModel, CourseAssistantState>((ref) {
  return CourseAssistantViewModel();
});

class CourseAssistantViewModel extends StateNotifier<CourseAssistantState> {
  CourseAssistantViewModel() : super(const CourseAssistantState());

  Future<void> loadAllData() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load courses
      String? courseJson = prefs.getString('assistant_courses');
      List<Course> courses = [];
      if (courseJson != null && courseJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(courseJson);
        courses = decoded
            .map((v) => Course.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      }

      // Load custom events
      String? eventJson = prefs.getString('custom_events');
      List<CustomEvent> events = [];
      if (eventJson != null && eventJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(eventJson);
        events = decoded
            .map((v) => CustomEvent.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      }

      // Load AI configs
      final configJson = prefs.getString('ai_configs') ?? '[]';
      List<AiConfig> aiConfigs = AiConfig.decode(configJson);
      String? selectedAiConfigId = prefs.getString('selected_ai_config_id');

      // Check embedding API key
      bool hasEmbeddingApiKey = false;
      final embeddingJson = prefs.getString('embedding_config');
      if (embeddingJson != null && embeddingJson.isNotEmpty) {
        try {
          final embeddingConfig = AiConfig.fromJson(jsonDecode(embeddingJson));
          hasEmbeddingApiKey = embeddingConfig.apiKey.isNotEmpty;
        } catch (_) {
          hasEmbeddingApiKey = false;
        }
      } else {
        hasEmbeddingApiKey =
            aiConfigs.isNotEmpty && aiConfigs.first.apiKey.isNotEmpty;
      }

      // Create AI service if configs exist
      AiService? aiService;
      if (aiConfigs.isNotEmpty) {
        AiConfig? target;
        if (selectedAiConfigId != null) {
          target = aiConfigs.firstWhere(
            (c) => c.id == selectedAiConfigId,
            orElse: () => aiConfigs.first,
          );
        } else {
          target = aiConfigs.first;
        }

        if (state.aiService != null &&
            state.aiService!.config.id == target.id) {
          aiService = state.aiService;
        } else {
          final oldHistory = state.aiService?.history ?? [];
          aiService = AiService(config: target);
          aiService.history.addAll(oldHistory);
        }
      }

      state = state.copyWith(
        assistantCourses: courses,
        customEvents: events,
        aiConfigs: aiConfigs,
        selectedAiConfigId: selectedAiConfigId,
        hasEmbeddingApiKey: hasEmbeddingApiKey,
        aiService: aiService,
        isLoading: false,
      );
    } catch (e) {
      print("讀取資料失敗: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> removeCourse(Course course) async {
    final updatedCourses = state.assistantCourses
        .where((c) => c.code != course.code)
        .toList();
    Course? updatedDetail =
        state.selectedCourseForDetail?.code == course.code
            ? null
            : state.selectedCourseForDetail;

    state = state.copyWith(
      assistantCourses: updatedCourses,
      selectedCourseForDetail: updatedDetail,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'assistant_courses',
      jsonEncode(updatedCourses.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> removeCustomEvent(String eventId) async {
    final updatedEvents = state.customEvents
        .where((e) => e.id != eventId)
        .toList();
    CustomEvent? updatedDetail = state.selectedEventForDetail?.id == eventId
        ? null
        : state.selectedEventForDetail;

    state = state.copyWith(
      customEvents: updatedEvents,
      selectedEventForDetail: updatedDetail,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_events',
      jsonEncode(updatedEvents.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('assistant_courses');
    await prefs.remove('custom_events');
    await loadAllData();
  }

  void setCurrentAction(AssistantAction action) {
    state = state.copyWith(currentAction: action);
  }

  void selectCourseForDetail(Course? course) {
    state = state.copyWith(selectedCourseForDetail: course);
  }

  void selectEventForDetail(CustomEvent? event) {
    state = state.copyWith(selectedEventForDetail: event);
  }

  Future<void> onAiConfigChanged(AiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_ai_config_id', config.id);

    final oldHistory = state.aiService?.history ?? [];
    final newService = AiService(config: config);
    newService.history.addAll(oldHistory);

    state = state.copyWith(
      selectedAiConfigId: config.id,
      aiService: newService,
    );
  }
}