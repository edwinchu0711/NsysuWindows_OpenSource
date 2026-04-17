import 'package:isar/isar.dart';

part 'course_isar_model.g.dart';

@collection
class CourseIsar {
  Id id = Isar.autoIncrement;

  @Index()
  String courseId = ""; // 科號 (T3)

  @Index()
  String name = ""; // 課名

  @Index()
  String teacher = ""; // 老師

  String grade = ""; // 年級
  String className = ""; // 班級

  @Index()
  String department = ""; // 系所

  List<String> classTime = []; // 長度 7, 對應 Mon-Sun

  String room = ""; // 教室
  String credit = ""; // 學分
  bool english = false; // 英語授課
  int restrict = 0; // 限收
  int select = 0; // 已選 (本階段)
  int selected = 0; // 已選 (總計)
  int remaining = 0; // 餘額
  int multipleCompulsory = 0; // 0=必修, 1=選修
  List<String> tags = []; // 標籤/學程
  String description = ""; // 備註
  String semester = ""; // 歸屬學期
}