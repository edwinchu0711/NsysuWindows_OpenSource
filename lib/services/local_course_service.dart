import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';
import 'course_query_service.dart';

class LocalCourseService {
  static final LocalCourseService instance = LocalCourseService._privateConstructor();
  LocalCourseService._privateConstructor();

  Database? _db;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await Utils.getAppDbDirectory();
    final path = join(dbPath, "courses.db");

    final file = File(path);
    if (!await file.exists()) {
      // DB doesn't exist yet — not initialized, but don't crash
      _initialized = false;
      return;
    }

    _db = await openDatabase(path);
    _initialized = true;
  }

  /// Get the actual course count from the database
  Future<int> getCourseCount() async {
    if (!_initialized) await init();
    if (!_initialized || _db == null) return 0;
    try {
      final result = await _db!.rawQuery('SELECT COUNT(*) as cnt FROM courses');
      if (result.isNotEmpty) {
        return (result.first['cnt'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Reset state so the service can be re-initialized after DB rebuild
  void reset() {
    _db?.close();
    _db = null;
    _initialized = false;
  }

  /// Delete the courses.db file and reset state
  Future<void> deleteCoursesDb() async {
    _db?.close();
    _db = null;
    _initialized = false;

    final dbPath = await Utils.getAppDbDirectory();
    final path = join(dbPath, "courses.db");
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('course_db_course_count');
  }

  /// Removes parentheses (both full-width and half-width) and English suffix from course names.
  /// Also strips "服務學習：" / "服務學習:" prefix so that review names like
  /// "圖書館志工" can match formal course names like "服務學習：圖書館志工".
  /// name_zh_en format: "微積分\nCalculus" → strip to "微積分"
  String stripBrackets(String s) {
    var withoutEnglish = s.split('\n').first;
    // Strip "服務學習：" / "服務學習:" prefix (full-width and half-width colon)
    withoutEnglish = withoutEnglish.replaceAll(RegExp(r'服務學習[：:]\s*'), '');
    return withoutEnglish.replaceAll(RegExp(r'（.*?）|\(.*?\)', unicode: true), '').trim();
  }

  /// Check if teacher names match broadly (rule-based fast path)
  /// Returns: true = definitely match, false = definitely not match, null = uncertain (need LLM)
  bool? _isTeacherMatchBasic(String t1, String t2) {
    if (t1.isEmpty || t2.isEmpty) return false;
    if (t1 == t2) return true;

    // Compare first characters (typically surname in Chinese names)
    if (t1[0] != t2[0]) return false;

    if (t1.contains('教授') || t2.contains('教授')) return true;
    if (t1.length >= 2 && t2.length >= 2 && t1.substring(0, 2) == t2.substring(0, 2)) return true;
    if (t1.length == 3 && t2.length == 3) {
      int matchCount = 0;
      for (int i=0; i<3; i++) {
        if (t1[i] == t2[i]) matchCount++;
      }
      if (matchCount >= 2) return true;
    }
    // Same surname but can't determine by rules — let LLM decide
    return null;
  }

  /// Combined teacher matching: rule-based check with surname fallback for uncertain cases
  /// (LLM matching removed — surname fallback is sufficient and avoids extra API calls)
  Future<bool> isTeacherMatch(String t1, String t2) async {
    final basicResult = _isTeacherMatchBasic(t1, t2);
    if (basicResult != null) return basicResult;
    // Uncertain — fall back to same-surname match
    return t1.isNotEmpty && t2.isNotEmpty && t1[0] == t2[0];
  }

  /// Convert a DB cursor row to `CourseJsonData` efficiently
  Future<CourseJsonData> _rowToCourseJsonData(Map<String, dynamic> row) async {
    final courseId = row['id'];

    // query times (weekday is 0-indexed: 0=Mon, 6=Sun)
    final timesQuery = await _db!.query('course_times', where: 'course_id = ?', whereArgs: [courseId]);
    List<String> classTime = List.filled(7, "");
    for (var t in timesQuery) {
      int weekday = t['weekday'] as int;
      if (weekday >= 0 && weekday <= 6) {
        classTime[weekday] = t['periods']?.toString() ?? "";
      }
    }

    // query tags
    final tagsQuery = await _db!.query('course_tags', where: 'course_id = ?', whereArgs: [courseId]);
    List<String> tags = tagsQuery.map((e) => e['tag'].toString()).toList();

    return CourseJsonData(
      id: row['id']?.toString() ?? "",
      name: row['name_zh_en']?.toString() ?? "",
      teacher: row['teacher']?.toString() ?? "",
      grade: row['grade']?.toString() ?? "",
      className: row['class_name']?.toString() ?? "",
      department: row['department']?.toString() ?? "",
      classTime: classTime,
      room: row['room']?.toString() ?? "",
      credit: row['credit']?.toString() ?? "0",
      english: (row['english'] as int?) == 1,
      restrict: row['restrict_count'] as int? ?? 0,
      select: row['select_count'] as int? ?? 0,
      selected: row['selected_count'] as int? ?? 0,
      remaining: row['remaining_count'] as int? ?? 0,
      multipleCompulsory: row['multiple_compulsory'] as int? ?? 0,
      tags: tags,
      description: row['description']?.toString() ?? "",
    );
  }

  /// Finds matching courses to recommendation logic. Strips brackets to check.
  /// Uses LLM for uncertain professor name matches.
  Future<List<CourseJsonData>> findMatchingCourses(String courseName, String professor) async {
    if (!_initialized) await init();
    if (!_initialized) return [];

    final strippedTarget = stripBrackets(courseName);

    // Filter by name containing the stripped term
    final professorPrefix = professor.isNotEmpty ? '%${professor[0]}%' : '%';
    final rows = await _db!.query('courses', where: 'name_zh_en LIKE ? OR teacher LIKE ?', whereArgs: ['%$strippedTarget%', professorPrefix]);

    List<CourseJsonData> matched = [];
    for (var r in rows) {
      final dbName = r['name_zh_en']?.toString() ?? "";
      final dbTeacher = r['teacher']?.toString() ?? "";

      final dbNameStripped = stripBrackets(dbName);
      if (dbNameStripped.contains(strippedTarget) || strippedTarget.contains(dbNameStripped)) {
        // Use async teacher matching with LLM fallback
        final isMatch = await isTeacherMatch(professor, dbTeacher);
        if (isMatch) {
          matched.add(await _rowToCourseJsonData(r));
        }
      }
    }

    return matched;
  }

  /// Custom filtering corresponding to CourseFilterSkill
  Future<List<CourseJsonData>> searchCourses({
    String? keyword,
    List<String>? days,
    List<String>? periods,
    String? department,
    String? grade,
    int? compulsory, // 0=必修, 1=選修, null=不篩選
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return [];

    String query = '''
      SELECT DISTINCT c.* FROM courses c
      LEFT JOIN course_times ct ON c.id = ct.course_id
      LEFT JOIN course_tags cg ON c.id = cg.course_id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (keyword != null && keyword.isNotEmpty) {
      query += ' AND (c.name_zh_en LIKE ? OR c.teacher LIKE ? OR c.department LIKE ? OR cg.tag LIKE ?)';
      final k = '%$keyword%';
      args.addAll([k, k, k, k]);
    }

    if (department != null && department.isNotEmpty) {
      query += ' AND (c.department LIKE ? OR cg.tag LIKE ?)';
      args.add('%$department%');
      args.add('%$department%');
    }

    if (grade != null && grade.isNotEmpty) {
      query += ' AND c.grade = ?';
      args.add(grade);
    }

    if (compulsory != null) {
      query += ' AND c.multiple_compulsory = ?';
      args.add(compulsory);
    }

    if (days != null && days.isNotEmpty) {
      final dayPlaceholders = List.filled(days.length, '?').join(',');
      query += ' AND ct.weekday IN ($dayPlaceholders)';
      // DB uses 0-indexed weekday (0=Mon, 6=Sun), input is 1-indexed (1=Mon, 7=Sun)
      args.addAll(days.map((e) => (int.tryParse(e) ?? 1) - 1));
    }

    if (periods != null && periods.isNotEmpty) {
      List<String> periodConditions = [];
      for (var p in periods) {
        periodConditions.add('ct.periods LIKE ?');
        args.add('%$p%');
      }
      query += ' AND (' + periodConditions.join(' OR ') + ')';
    }

    final rows = await _db!.rawQuery(query, args);
    List<CourseJsonData> result = [];
    for (var r in rows) {
      result.add(await _rowToCourseJsonData(r));
    }

    return result;
  }
}
