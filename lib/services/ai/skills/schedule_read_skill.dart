import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'skill.dart';
import '../skill_context.dart';
import '../skill_result.dart';
// import '../intent_classifier.dart';
import '../../../../models/course_model.dart';
import '../../../../models/custom_event_model.dart';

class ScheduleReadSkill implements Skill {
  @override
  String get name => 'schedule_read';

  @override
  String get description => '讀取並分析使用者目前的個人課表安排（包含課程名稱、老師、學分數、時間地點）。';

  @override
  Map<String, dynamic> toToolJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {}
      }
    }
  };

  @override
  Future<SkillResult> execute(
    Map<String, dynamic> params,
    SkillContext ctx,
  ) async {
    await loadIntoContext(ctx);
    if (ctx.currentCourses.isEmpty) {
      return const SkillResult(contextInfo: '（目前課表為空）');
    }
    return SkillResult(contextInfo: '[目前課表]\n${ctx.scheduleStr}');
  }

  /// 將課表資料載入 SkillContext（供其他 Skill 複用）
  Future<void> loadIntoContext(SkillContext ctx) async {
    if (ctx.currentCourses.isNotEmpty) return; // 已載入則跳過
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('assistant_courses');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      ctx.currentCourses = decoded
          .map((v) => Course.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }

    final eventsStr = prefs.getString('custom_events');
    if (eventsStr != null && eventsStr.isNotEmpty) {
      final decodedEvents = jsonDecode(eventsStr) as List<dynamic>;
      ctx.currentEvents = decodedEvents
          .map((v) => CustomEvent.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }
  }

  /// 將課表儲存回 SharedPreferences（供其他 Skill 複用）
  static Future<void> saveFromContext(SkillContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'assistant_courses',
      jsonEncode(ctx.currentCourses.map((c) => c.toJson()).toList()),
    );
  }
}
