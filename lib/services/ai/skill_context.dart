import '../../../models/course_model.dart';
import '../../../models/custom_event_model.dart';

/// 在所有 Skill 之間共享的可變狀態容器
class SkillContext {
  List<Course> currentCourses;
  List<CustomEvent> currentEvents;
  final Function(String)? onStatusUpdate;

  SkillContext({
    List<Course>? currentCourses,
    List<CustomEvent>? currentEvents,
    this.onStatusUpdate,
  }) : currentCourses = currentCourses ?? [],
       currentEvents = currentEvents ?? [];

  String get scheduleStr {
    final sb = StringBuffer();
    if (currentCourses.isNotEmpty) {
      sb.writeln("[正規課程]");
      for (var c in currentCourses) {
        final deptStr = c.department.isNotEmpty ? ' [${c.department}]' : '';
        sb.writeln("- ${c.name}(${c.professor})$deptStr [${c.timeString}] @${c.location}");
      }
    }
    if (currentEvents.isNotEmpty) {
      sb.writeln("\n[自定義行程]");
      for (var e in currentEvents) {
        final days = ["一", "二", "三", "四", "五", "六", "日"];
        final dayStr = (e.day >= 1 && e.day <= 7) ? "週${days[e.day - 1]}" : "";
        sb.writeln("- ${e.title} [$dayStr ${e.periods.join(', ')}] @${e.location}");
      }
    }
    return sb.toString().trim();
  }
}
