import 'dart:convert';
import 'package:http/http.dart' as http;

class CourseJsonData {
  final String id;        // 科號 (T3)
  final String name;      // 課名 (crsname)
  final String teacher;   // 老師 (teacher)
  final String grade;     // 年級 (D2)
  final String className; // 班級 (CLASS_COD 對應文字)
  final String department;// 系所
  final List<String> classTime; // 時間 [Mon, Tue, ...]
  final String room;      // 教室
  final String credit;    // 學分
  final bool english;     // 英語授課
  final int restrict;     // 限收
  final int select;       // 已選 (本階段)
  final int selected;     // 已選 (總計)
  final int remaining;    // 餘額
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
      'tags': tags,
      'description': description,
    };
  }
}

class CourseQueryService {
  static final CourseQueryService instance = CourseQueryService._privateConstructor();
  CourseQueryService._privateConstructor();

  List<CourseJsonData> _cachedCourses = [];
  bool _isDataLoaded = false;
  String _currentSemester = "";

  String get currentSemester => _currentSemester;

  Future<List<CourseJsonData>> getCourses({bool forceRefresh = false}) async {
    if (_isDataLoaded && !forceRefresh && _cachedCourses.isNotEmpty) {
      return _cachedCourses;
    }

    final client = http.Client();
    try {
      final vRes = await client.get(Uri.parse("https://nsysu-opendev.github.io/NSYSUCourseAPI/version.json"));
      if (vRes.statusCode != 200) throw "Version API Error";
      final vJson = jsonDecode(vRes.body);
      final String latestSem = vJson['latest'];
      _currentSemester = latestSem;

      final tRes = await client.get(Uri.parse("https://nsysu-opendev.github.io/NSYSUCourseAPI/$latestSem/version.json"));
      if (tRes.statusCode != 200) throw "Time API Error";
      final tJson = jsonDecode(tRes.body);
      final String latestTime = tJson['latest'];

      final url = "https://nsysu-opendev.github.io/NSYSUCourseAPI/$latestSem/$latestTime/all.json";
      final allRes = await client.get(Uri.parse(url));
      if (allRes.statusCode != 200) throw "All JSON API Error";

      final List<dynamic> rawList = jsonDecode(utf8.decode(allRes.bodyBytes));
      _cachedCourses = rawList.map((e) => CourseJsonData.fromJson(e)).toList();
      _isDataLoaded = true;
      return _cachedCourses;
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  List<CourseJsonData> search({
    String? query,           // 合併搜尋 (課名, 老師, 系所, 學程)
    List<String>? grades,   // 年級 (複選)
    List<String>? days,     // 星期 (複選)
    List<String>? periods,  // 節次 (複選)
    String? classType,      // 班別
    bool filterConflict = false, // 是否過濾衝堂
    List<dynamic>? existingCourses, // 既有課程 (格式參考 Course 模型)
    List<dynamic>? existingEvents,  // 既有自訂行程 (格式參考 CustomEvent 模型)
  }) {
    if (_cachedCourses.isEmpty) return [];

    // 處理博雅關鍵字轉換
    String processedQuery = query?.trim() ?? "";
    if (processedQuery.isNotEmpty) {
      final Map<String, String> numMap = {
        '1': '一', '2': '二', '3': '三', '4': '四', '5': '五',
        '6': '六', '7': '七', '8': '八', '9': '九',
        '一': '一', '二': '二', '三': '三', '四': '四', '五': '五',
        '六': '六', '七': '七', '八': '八', '九': '九'
      };
      
      // 使用 Regex 尋找 "博雅" 或 "向度" + [1-9一-九]，中間可含空格
      final regex = RegExp(r'(博雅|向度)\s*([1-9一二三四五六七八九])');
      processedQuery = processedQuery.replaceAllMapped(regex, (match) {
        String num = match.group(2)!;
        // 轉為 "博雅 向度X" 兩個關鍵字，提高匹配靈活性
        return "博雅 向度${numMap[num] ?? num}";
      });
    }

    final Set<String> seenIds = {};
    final List<String> keywords = processedQuery.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

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

    return _cachedCourses.where((course) {
      // 1. 合併搜尋 (AND 邏輯)
      if (keywords.isNotEmpty) {
        for (var kw in keywords) {
          final kwUpper = kw.toUpperCase();
          bool match = course.name.toUpperCase().contains(kwUpper) ||
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
      if ((days != null && days.isNotEmpty) || (periods != null && periods.isNotEmpty)) {
        bool timeMatched = false;
        for (int i = 0; i < 7; i++) {
          String courseDayPeriods = course.classTime[i];
          if (courseDayPeriods.isEmpty) continue;

          bool dayOk = (days == null || days.isEmpty) || days.contains((i + 1).toString());
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
          // 逐一檢查節次 (中山節次為單一字元)
          final cleaned = courseDayPeriods.replaceAll(',', '').replaceAll(' ', '');
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
    }).take(200).toList();
  }
}