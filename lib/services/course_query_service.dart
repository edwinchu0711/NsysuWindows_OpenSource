import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../utils/utils.dart';
import '../models/course_isar_model.dart';
import 'local_course_service.dart';

class CourseJsonData {
  final String id; // 科號 (T3)
  final String name; // 課名 (crsname)
  final String teacher; // 老師 (teacher)
  final String grade; // 年級 (D2)
  final String className; // 班級 (CLASS_COD 對應文字)
  final String department; // 系所
  final List<String> classTime; // 時間 [Mon, Tue, ...]
  final String room; // 教室
  final String credit; // 學分
  final bool english; // 英語授課
  final int restrict; // 限收
  final int select; // 已選 (本階段)
  final int selected; // 已選 (總計)
  final int remaining; // 餘額
  final int multipleCompulsory; // 0=必修, 1=選修
  final List<String> tags; // 標籤/學程
  final String description; // 備註

  CourseJsonData({
    required this.id,
    required this.name,
    required this.teacher,
    required this.grade,
    required this.className,
    required this.department,
    required this.classTime,
    required this.room,
    required this.credit,
    required this.english,
    required this.restrict,
    required this.select,
    required this.selected,
    required this.remaining,
    required this.multipleCompulsory,
    required this.tags,
    required this.description,
  });

  factory CourseJsonData.fromJson(Map<String, dynamic> json) {
    return CourseJsonData(
      id: json['id'] ?? "",
      name: json['name'] ?? "",
      teacher: json['teacher'] ?? "",
      grade: json['grade'] ?? "",
      className: json['class'] ?? "",
      department: json['department'] ?? "",
      classTime: List<String>.from(json['classTime'] ?? []),
      room: json['room'] ?? "",
      credit: json['credit'] ?? "",
      english: json['english'] ?? false,
      restrict: json['restrict'] ?? 0,
      select: json['select'] ?? 0,
      selected: json['selected'] ?? 0,
      remaining: json['remaining'] ?? 0,
      multipleCompulsory: json['multiple_compulsory'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      description: json['description'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'grade': grade,
      'class': className,
      'department': department,
      'classTime': classTime,
      'room': room,
      'credit': credit,
      'english': english,
      'restrict': restrict,
      'select': select,
      'selected': selected,
      'remaining': remaining,
      'multiple_compulsory': multipleCompulsory,
      'tags': tags,
      'description': description,
    };
  }
}

class CourseQueryService {
  static final CourseQueryService instance =
      CourseQueryService._privateConstructor();
  CourseQueryService._privateConstructor();

  Isar? _isar;
  List<CourseJsonData> _cachedCourses = [];
  bool _isDataLoaded = false;
  String _currentSemester = "";
  bool _isUpdating = false;

  String get currentSemester => _currentSemester;
  List<CourseJsonData> get cachedCourses => List.unmodifiable(_cachedCourses);

  /// 初始化：開啟 Isar、載入本地資料
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [CourseIsarSchema],
      directory: dir.path,
    );
    await _loadFromIsar();
  }

  /// 從 Isar 載入本地課程到記憶體
  Future<void> _loadFromIsar() async {
    if (_isar == null) return;
    final courses = await _isar!.courseIsars.where().findAll();
    _cachedCourses = courses.map(_isarToCourseJsonData).toList();
    if (_cachedCourses.isNotEmpty) {
      _isDataLoaded = true;
      final prefs = await SharedPreferences.getInstance();
      _currentSemester = prefs.getString('course_local_semester') ?? "";
    }
  }

  /// 背景檢查遠端版本是否有更新（public，由 SSO 登入後觸發）
  Future<void> checkForUpdate() async {
    if (_isUpdating) return;
    _isUpdating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final localSem = prefs.getString('course_local_semester') ?? "";
      final localTs = prefs.getString('course_local_timestamp') ?? "";

      final client = http.Client();
      try {
        // 取得最新學期
        final vRes = await client.get(
          Uri.parse(
            "https://nsysu-opendev.github.io/NSYSUCourseAPI/version.json",
          ),
        );
        if (vRes.statusCode != 200) return;
        final vJson = jsonDecode(vRes.body);
        final String latestSem = vJson['latest'];

        // 取得最新時間戳
        final tRes = await client.get(
          Uri.parse(
            "https://nsysu-opendev.github.io/NSYSUCourseAPI/$latestSem/version.json",
          ),
        );
        if (tRes.statusCode != 200) return;
        final tJson = jsonDecode(tRes.body);
        final String latestTime = tJson['latest'];

        // 比對本地版本
        if (latestSem != localSem || latestTime != localTs || !_isDataLoaded) {
          print("🔄 CourseQueryService: 偵測到遠端版本更新 ($localSem/$localTs → $latestSem/$latestTime)");
          await _downloadAndUpdate(latestSem, latestTime);
        } else {
          print("✅ CourseQueryService: 本地資料已是最新 ($latestSem/$latestTime)");
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print("⚠️ CourseQueryService: 背景更新檢查失敗: $e（使用本地資料）");
    } finally {
      _isUpdating = false;
    }
  }

  /// 下載 JSON 並寫入 Isar
  Future<void> _downloadAndUpdate(String semester, String timestamp) async {
    final client = http.Client();
    try {
      final url =
          "https://nsysu-opendev.github.io/NSYSUCourseAPI/$semester/$timestamp/all.json";
      final allRes = await client.get(Uri.parse(url));
      if (allRes.statusCode != 200) throw "All JSON API Error: ${allRes.statusCode}";

      final List<dynamic> rawList = jsonDecode(utf8.decode(allRes.bodyBytes));

      // 轉換為 Isar 物件
      final courseIsarList =
          rawList.map((e) => _jsonToIsar(e, semester)).toList();

      // 寫入 Isar
      if (_isar != null) {
        await _isar!.writeTxn(() async {
          await _isar!.courseIsars.clear();
          await _isar!.courseIsars.putAll(courseIsarList);
        });
      }

      // 同時建立 courses.db (SQLite)
      await _buildCoursesDb(rawList, semester);

      // 更新版本記錄
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('course_local_semester', semester);
      await prefs.setString('course_local_timestamp', timestamp);
      await prefs.setInt('course_db_course_count', rawList.length);

      // 重新載入到記憶體
      await _loadFromIsar();
      _currentSemester = semester;

      print("🚀 CourseQueryService: 課程資料更新完成 (${_cachedCourses.length} 筆, $semester/$timestamp)");
    } catch (e) {
      print("❌ CourseQueryService: 下載更新失敗: $e");
      rethrow;
    } finally {
      client.close();
    }
  }

  /// 從下載的 JSON 建立 courses.db (SQLite)
  Future<void> _buildCoursesDb(List<dynamic> rawList, String semester) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await Utils.getAppDbDirectory();
    final path = join(dbPath, "courses.db");

    // Delete existing DB first
    final existingFile = File(path);
    if (await existingFile.exists()) {
      await existingFile.delete();
    }

    final db = await openDatabase(path);

    try {
      // Create tables with the same schema as the Python script
      await db.execute('''
        CREATE TABLE IF NOT EXISTS courses (
          id TEXT PRIMARY KEY,
          url TEXT,
          change TEXT,
          change_description TEXT,
          multiple_compulsory INTEGER NOT NULL DEFAULT 0,
          department TEXT,
          grade TEXT,
          class_name TEXT,
          name_zh_en TEXT,
          credit REAL,
          year_semester TEXT,
          compulsory INTEGER NOT NULL DEFAULT 0,
          restrict_count INTEGER,
          select_count INTEGER,
          selected_count INTEGER,
          remaining_count INTEGER,
          teacher TEXT,
          room TEXT,
          description TEXT,
          english INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS course_times (
          course_id TEXT NOT NULL,
          weekday INTEGER NOT NULL,
          periods TEXT,
          PRIMARY KEY (course_id, weekday),
          FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS course_tags (
          course_id TEXT NOT NULL,
          tag TEXT NOT NULL,
          PRIMARY KEY (course_id, tag),
          FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_courses_teacher ON courses(teacher)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_course_tags_tag ON course_tags(tag)');

      // Batch insert using transaction
      await db.transaction((txn) async {
        for (var c in rawList) {
          // Insert course row
          await txn.execute(
            '''INSERT OR REPLACE INTO courses (
              id, url, change, change_description, multiple_compulsory,
              department, grade, class_name, name_zh_en, credit, year_semester,
              compulsory, restrict_count, select_count, selected_count, remaining_count,
              teacher, room, description, english
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              c['id']?.toString() ?? '',
              c['url']?.toString() ?? '',
              c['change']?.toString() ?? '',
              c['changeDescription']?.toString() ?? c['change_description']?.toString() ?? '',
              c['multiple_compulsory'] != null ? (c['multiple_compulsory'] is bool ? (c['multiple_compulsory'] ? 1 : 0) : (c['multiple_compulsory'] as int)) : 0,
              c['department']?.toString() ?? '',
              c['grade']?.toString() ?? '',
              c['class']?.toString() ?? c['class_name']?.toString() ?? '',
              c['name']?.toString() ?? c['name_zh_en']?.toString() ?? '',
              _toFloat(c['credit']),
              semester,
              c['compulsory'] != null ? (c['compulsory'] is bool ? (c['compulsory'] ? 1 : 0) : (c['compulsory'] as int)) : 0,
              _toInt(c['restrict']),
              _toInt(c['select']),
              _toInt(c['selected']),
              _toInt(c['remaining']),
              c['teacher']?.toString() ?? '',
              c['room']?.toString() ?? '',
              c['description']?.toString() ?? '',
              c['english'] != null ? (c['english'] is bool ? (c['english'] ? 1 : 0) : (c['english'] as int)) : 0,
            ],
          );

          // Insert course_times
          final classTime = c['classTime'];
          if (classTime is List) {
            // Delete old times for this course (safety)
            await txn.delete('course_times', where: 'course_id = ?', whereArgs: [c['id']]);

            for (int weekday = 0; weekday < classTime.length && weekday < 7; weekday++) {
              final periods = classTime[weekday]?.toString() ?? '';
              if (periods.isNotEmpty) {
                await txn.execute(
                  'INSERT OR REPLACE INTO course_times (course_id, weekday, periods) VALUES (?, ?, ?)',
                  [c['id']?.toString() ?? '', weekday, periods],
                );
              }
            }
          }

          // Insert course_tags
          final tags = c['tags'];
          if (tags is List) {
            await txn.delete('course_tags', where: 'course_id = ?', whereArgs: [c['id']]);
            for (var tag in tags) {
              if (tag != null) {
                await txn.execute(
                  'INSERT OR IGNORE INTO course_tags (course_id, tag) VALUES (?, ?)',
                  [c['id']?.toString() ?? '', tag.toString()],
                );
              }
            }
          }
        }
      });

      await db.close();

      // Re-initialize LocalCourseService to use the new DB
      LocalCourseService.instance.reset();
      await LocalCourseService.instance.init();

      print("✅ CourseQueryService: courses.db 建立完成 (${rawList.length} 筆課程)");
    } catch (e) {
      print("❌ CourseQueryService: courses.db 建立失敗: $e");
      try { await db.close(); } catch (_) {}
      rethrow;
    }
  }

  /// Helper: convert value to int safely
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? int.tryParse(double.tryParse(s)?.toStringAsFixed(0) ?? '');
  }

  /// Helper: convert value to double safely
  double? _toFloat(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  /// 取得課程資料（對外 API 不變）
  Future<List<CourseJsonData>> getCourses({bool forceRefresh = false}) async {
    if (_isDataLoaded && !forceRefresh && _cachedCourses.isNotEmpty) {
      return _cachedCourses;
    }

    // 如果本地沒資料，同步下載
    final client = http.Client();
    try {
      final vRes = await client.get(
        Uri.parse(
          "https://nsysu-opendev.github.io/NSYSUCourseAPI/version.json",
        ),
      );
      if (vRes.statusCode != 200) throw "Version API Error";
      final vJson = jsonDecode(vRes.body);
      final String latestSem = vJson['latest'];
      _currentSemester = latestSem;

      final tRes = await client.get(
        Uri.parse(
          "https://nsysu-opendev.github.io/NSYSUCourseAPI/$latestSem/version.json",
        ),
      );
      if (tRes.statusCode != 200) throw "Time API Error";
      final tJson = jsonDecode(tRes.body);
      final String latestTime = tJson['latest'];

      await _downloadAndUpdate(latestSem, latestTime);
      return _cachedCourses;
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  List<CourseJsonData> search({
    String? query,
    List<String>? grades,
    List<String>? days,
    List<String>? periods,
    String? classType,
    bool filterConflict = false,
    List<dynamic>? existingCourses,
    List<dynamic>? existingEvents,
  }) {
    if (_cachedCourses.isEmpty) return [];

    // 處理博雅關鍵字轉換
    String processedQuery = query?.trim() ?? "";
    if (processedQuery.isNotEmpty) {
      final Map<String, String> numMap = {
        '1': '一',
        '2': '二',
        '3': '三',
        '4': '四',
        '5': '五',
        '6': '六',
        '7': '七',
        '8': '八',
        '9': '九',
        '一': '一',
        '二': '二',
        '三': '三',
        '四': '四',
        '五': '五',
        '六': '六',
        '七': '七',
        '八': '八',
        '九': '九',
      };

      final regex = RegExp(r'(博雅|向度)\s*([1-9一二三四五六七八九])');
      processedQuery = processedQuery.replaceAllMapped(regex, (match) {
        String num = match.group(2)!;
        return "博雅 向度${numMap[num] ?? num}";
      });
    }

    final Set<String> seenIds = {};
    final List<String> keywords = processedQuery
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    // 預先建立衝突檢查用的 Set (Day-Period)
    final Set<String> occupiedSlots = {};
    if (filterConflict) {
      if (existingCourses != null) {
        for (var c in existingCourses) {
          final pTimes = c['parsedTimes'] as List?;
          if (pTimes != null) {
            for (var t in pTimes) {
              occupiedSlots.add("${t['day']}-${t['period']}");
            }
          }
        }
      }
      if (existingEvents != null) {
        for (var e in existingEvents) {
          final day = e['day'];
          final ps = e['periods'] as List?;
          if (day != null && ps != null) {
            for (var p in ps) {
              occupiedSlots.add("$day-$p");
            }
          }
        }
      }
    }

    return _cachedCourses
        .where((course) {
          // 1. 合併搜尋 (AND 邏輯)
          if (keywords.isNotEmpty) {
            for (var kw in keywords) {
              final kwUpper = kw.toUpperCase();
              bool match =
                  course.name.toUpperCase().contains(kwUpper) ||
                  course.teacher.toUpperCase().contains(kwUpper) ||
                  course.department.toUpperCase().contains(kwUpper) ||
                  course.id.toUpperCase().contains(kwUpper) ||
                  course.tags.any((t) => t.toUpperCase().contains(kwUpper));
              if (!match) return false;
            }
          }

          // 2. 年級 (複選 OR)
          if (grades != null && grades.isNotEmpty) {
            if (!grades.contains(course.grade)) return false;
          }

          // 3. 班別
          if (classType != null && classType.isNotEmpty) {
            if (course.className != classType) return false;
          }

          // 4. 星期與節次 (複選 OR)
          if ((days != null && days.isNotEmpty) ||
              (periods != null && periods.isNotEmpty)) {
            bool timeMatched = false;
            for (int i = 0; i < 7; i++) {
              String courseDayPeriods = course.classTime[i];
              if (courseDayPeriods.isEmpty) continue;

              bool dayOk =
                  (days == null || days.isEmpty) ||
                  days.contains((i + 1).toString());
              if (!dayOk) continue;

              if (periods == null || periods.isEmpty) {
                timeMatched = true;
                break;
              } else {
                for (var p in periods) {
                  if (courseDayPeriods.contains(p)) {
                    timeMatched = true;
                    break;
                  }
                }
                if (timeMatched) break;
              }
            }
            if (!timeMatched) return false;
          }

          // 5. 衝堂檢查 (若開啟)
          if (filterConflict && occupiedSlots.isNotEmpty) {
            for (int i = 0; i < 7; i++) {
              String courseDayPeriods = course.classTime[i];
              if (courseDayPeriods.isEmpty) continue;

              final String day = (i + 1).toString();
              final cleaned = courseDayPeriods
                  .replaceAll(',', '')
                  .replaceAll(' ', '');
              for (int j = 0; j < cleaned.length; j++) {
                if (occupiedSlots.contains("$day-${cleaned[j]}")) {
                  return false; // 衝堂
                }
              }
            }
          }

          if (seenIds.contains(course.id)) return false;
          seenIds.add(course.id);

          return true;
        })
        .take(200)
        .toList();
  }

  // ─── Isar ↔ CourseJsonData 轉換 ───

  CourseJsonData _isarToCourseJsonData(CourseIsar isar) {
    return CourseJsonData(
      id: isar.courseId,
      name: isar.name,
      teacher: isar.teacher,
      grade: isar.grade,
      className: isar.className,
      department: isar.department,
      classTime: List<String>.from(isar.classTime),
      room: isar.room,
      credit: isar.credit,
      english: isar.english,
      restrict: isar.restrict,
      select: isar.select,
      selected: isar.selected,
      remaining: isar.remaining,
      multipleCompulsory: isar.multipleCompulsory,
      tags: List<String>.from(isar.tags),
      description: isar.description,
    );
  }

  CourseIsar _jsonToIsar(Map<String, dynamic> json, String semester) {
    final isar = CourseIsar();
    isar.courseId = json['id'] ?? "";
    isar.name = json['name'] ?? "";
    isar.teacher = json['teacher'] ?? "";
    isar.grade = json['grade'] ?? "";
    isar.className = json['class'] ?? "";
    isar.department = json['department'] ?? "";
    isar.classTime = List<String>.from(json['classTime'] ?? []);
    isar.room = json['room'] ?? "";
    isar.credit = json['credit'] ?? "";
    isar.english = json['english'] ?? false;
    isar.restrict = json['restrict'] ?? 0;
    isar.select = json['select'] ?? 0;
    isar.selected = json['selected'] ?? 0;
    isar.remaining = json['remaining'] ?? 0;
    isar.multipleCompulsory = json['multiple_compulsory'] ?? 0;
    isar.tags = List<String>.from(json['tags'] ?? []);
    isar.description = json['description'] ?? "";
    isar.semester = semester;
    return isar;
  }
}