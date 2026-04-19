import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/course_model.dart';
import '../services/course_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class CourseSchedulePage extends StatefulWidget {
  const CourseSchedulePage({Key? key}) : super(key: key);

  @override
  State<CourseSchedulePage> createState() => _CourseSchedulePageState();
}

class _CourseSchedulePageState extends State<CourseSchedulePage> {
  // --- 資料狀態 ---
  Map<String, List<Course>> _allCourses = {}; // Key: "1131"
  List<String> _availableSemesters = [];
  String? _selectedSemester;
  bool _isLoading = false;

  // ✅ 新增：右側面板選中的課程
  Course? _selectedCourseForDetail;

  final List<String> _periods = [
    'A',
    '1',
    '2',
    '3',
    '4',
    'B',
    '5',
    '6',
    '7',
    '8',
    '9',
    'C',
    'D',
    'E',
    'F',
  ];
  final List<String> _fullWeekDays = ['一', '二', '三', '四', '五', '六', '日'];

  final Map<String, String> _timeMapping = {
    'A': '07:00-07:50',
    '1': '08:10-09:00',
    '2': '09:10-10:00',
    '3': '10:10-11:00',
    '4': '11:10-12:00',
    'B': '12:10-13:00',
    '5': '13:10-14:00',
    '6': '14:10-15:00',
    '7': '15:10-16:00',
    '8': '16:10-17:00',
    '9': '17:10-18:00',
    'C': '18:20-19:10',
    'D': '19:15-20:05',
    'E': '20:10-21:00',
    'F': '21:05-21:55',
  };

  final Map<String, List<String>> _timeRangeMap = {
    'A': ['07:00', '07:50'],
    '1': ['08:10', '09:00'],
    '2': ['09:10', '10:00'],
    '3': ['10:10', '11:00'],
    '4': ['11:10', '12:00'],
    'B': ['12:10', '13:00'],
    '5': ['13:10', '14:00'],
    '6': ['14:10', '15:00'],
    '7': ['15:10', '16:00'],
    '8': ['16:10', '17:00'],
    '9': ['17:10', '18:00'],
    'C': ['18:20', '19:10'],
    'D': ['19:15', '20:05'],
    'E': ['20:10', '21:00'],
    'F': ['21:05', '21:55'],
  };

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    setState(() => _isLoading = true);
    try {
      String? jsonStr = await StorageService.instance.read(
        CourseService.CACHE_KEY,
      );
      if (jsonStr != null && jsonStr.isNotEmpty) {
        Map<String, dynamic> decoded = jsonDecode(jsonStr);
        Map<String, List<Course>> loadedData = {};
        decoded.forEach((key, value) {
          if (value is List) {
            loadedData[key] = value.map((v) => _courseFromJson(v)).toList();
          }
        });
        if (mounted) {
          setState(() {
            _allCourses = loadedData;
            _availableSemesters = _allCourses.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            if (_availableSemesters.isNotEmpty) {
              _selectedSemester = _availableSemesters.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("❌ 課表展示頁：載入失敗 $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Course _courseFromJson(Map<String, dynamic> json) {
    var times =
        (json['parsedTimes'] as List?)
            ?.map((t) => CourseTime(t['day'], t['period']))
            .toList() ??
        [];
    return Course(
      name: json['name'] ?? "",
      code: json['code'] ?? "",
      professor: json['professor'] ?? "",
      location: json['location'] ?? "",
      timeString: json['timeString'] ?? "",
      credits: json['credits'] ?? "",
      required: json['required'] ?? "",
      detailUrl: json['detailUrl'] ?? "",
      parsedTimes: times,
    );
  }

  // ✅ 新增：計算當前學期總學分
  double _calculateTotalCredits() {
    if (_selectedSemester == null ||
        !_allCourses.containsKey(_selectedSemester))
      return 0;
    double total = 0;
    for (var c in _allCourses[_selectedSemester!]!) {
      total += double.tryParse(c.credits) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. 自定義桌面標題列 (Header)
                _buildDesktopHeader(),

                // 2. 分割佈局內容區 (50%:50%)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: _allCourses.isEmpty
                          ? _buildEmptyState()
                          : Row(
                              children: [
                                // 左側：課表展示 (50%)
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.cardBackground,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                      ),
                                      border: Border.all(
                                        color: colorScheme.borderColor,
                                      ),
                                    ),
                                    child: ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(
                                        context,
                                      ).copyWith(scrollbars: false),
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: _buildTimeTable(
                                          _allCourses[_selectedSemester!] ?? [],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // 垂直分界線
                                Container(width: 1, color: Colors.grey[200]),
                                // 右側：詳情面板 (50%)
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.secondaryCardBackground,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: _buildDetailPane(),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildDesktopHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 10,
            right: 20,
            top: 25,
            bottom: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "歷年課表查詢",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 學期切換 Dropdown
                  if (_availableSemesters.isNotEmpty)
                    _GlassSingleSelectDropdown(
                      label: "", // 標題內嵌在按鈕內
                      items: _availableSemesters,
                      value: _selectedSemester!,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSemester = val;
                            _selectedCourseForDetail = null;
                          });
                        }
                      },
                      displayMap: Map.fromEntries(
                        _availableSemesters.map((sem) {
                          String label =
                              "${sem.substring(0, sem.length - 1)} 學年 " +
                              (sem.endsWith("1")
                                  ? "上學期"
                                  : sem.endsWith("2")
                                  ? "下學期"
                                  : "暑修");
                          return MapEntry(sem, label);
                        }),
                      ),
                    ),
                ],
              ),
              // 功能按鈕組
              Row(
                children: [
                  _buildExportButton(),
                  const SizedBox(width: 8),
                  _buildRefreshButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _isLoading ? null : _refreshFromNetwork,
      mouseCursor: _isLoading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.borderColor),
        ),
        child: Row(
          children: [
            _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: colorScheme.accentBlue,
                  ),
            const SizedBox(width: 8),
            Text(
              _isLoading ? "同步中" : "重新整理",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 新增：一鍵匯出代碼按鈕
  Widget _buildExportButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _exportCurrentSemesterAsCode(),
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.accentBlue.withOpacity(0.1), // 使用主題色系
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.accentBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.code_rounded, size: 18, color: colorScheme.accentBlue),
            const SizedBox(width: 8),
            Text(
              "匯出代碼",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportCurrentSemesterAsCode() {
    if (_selectedSemester == null) return;

    final courses = _allCourses[_selectedSemester!] ?? [];
    if (courses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("目前學期沒有課程資料可匯出")));
      return;
    }

    // 格式: const exportClass = [{"id":"GEAE2347","name":"名稱","value":0,"isSel":"+"}];
    List<Map<String, dynamic>> exportData = courses
        .map((c) => {"id": c.code, "name": c.name, "value": 0, "isSel": "+"})
        .toList();

    String codeString = "const exportClass = ${jsonEncode(exportData)};";

    Clipboard.setData(ClipboardData(text: codeString));

    String semesterLabel =
        "${_selectedSemester!.substring(0, 3)} 學年 " +
        (_selectedSemester!.endsWith("1")
            ? "上學期"
            : _selectedSemester!.endsWith("2")
            ? "下學期"
            : "暑修");

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("已複製 $semesterLabel 共 ${courses.length} 門課程代碼"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.accentBlue,
        // 加入這行，例如設定為 1 秒或 500 毫秒
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ✅ 新增：右側詳情面板 (Detail Pane)
  Widget _buildDetailPane() {
    final colorScheme = Theme.of(context).colorScheme;
    double totalCredits = _calculateTotalCredits();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 總學分統計卡片 (Sea Blue)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan[700]!, Colors.blue[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "本學期選課統計",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      "總修習學分",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      totalCredits.toString().replaceAll(".0", ""),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "學分",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            "課程詳情",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primaryText,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _selectedCourseForDetail == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "請點擊左側課表\n查看詳細資訊",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailInfoCard(_selectedCourseForDetail!),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailInfoCard(Course course) {
    final colorScheme = Theme.of(context).colorScheme;
    // ✅ 新增：計算時數 (節次數)
    int courseHours = course.parsedTimes.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colorScheme.accentBlue,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.tag_rounded, "課程代碼", course.code),
          _buildInfoRow(Icons.person_rounded, "授課教授", course.professor),
          _buildInfoRow(
            Icons.place_rounded,
            "教室地點",
            _extractLocation(course.location),
          ),
          _buildInfoRow(
            Icons.school_rounded,
            "修別學分",
            "${course.credits} 學分 ($courseHours 小時)",
          ),
          _buildInfoRow(
            Icons.access_time_filled_rounded,
            "上課時間",
            _formatCourseTimeWithRange(course),
          ),
          const Divider(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                // ✅ 修正：動態解析學分與學年生成正確連結
                String syear = _selectedSemester?.substring(0, 3) ?? "";
                String sem = _selectedSemester?.substring(3, 4) ?? "";
                final url = Uri.parse(
                  'https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=${course.code}',
                );
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.description_rounded, size: 18),
              label: const Text(
                "查看課程大綱",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.accentBlue.withOpacity(0.1),
                foregroundColor: colorScheme.accentBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.subtitleText),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: colorScheme.subtitleText, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTable(List<Course> courses) {
    final colorScheme = Theme.of(context).colorScheme;
    int maxDay = 5;
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        if (t.day == 6 && maxDay < 6) maxDay = 6;
        if (t.day == 7) maxDay = 7;
      }
    }
    List<String> visibleWeekDays = _fullWeekDays.sublist(0, maxDay);
    bool hasPeriodA = false;
    int maxPeriodIndex = _periods.indexOf('7');
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        if (t.period == 'A') hasPeriodA = true;
        int currentIndex = _periods.indexOf(t.period);
        if (currentIndex > maxPeriodIndex) maxPeriodIndex = currentIndex;
      }
    }
    int displayEndIndex = maxPeriodIndex;
    if (displayEndIndex < _periods.length - 1) displayEndIndex += 1;
    int startIndex = hasPeriodA ? 0 : _periods.indexOf('1');
    List<String> visiblePeriods = _periods.sublist(
      startIndex,
      displayEndIndex + 1,
    );

    Map<String, Course> courseMap = {};
    for (var c in courses) {
      for (var t in c.parsedTimes) {
        courseMap["${t.day}-${t.period}"] = c;
      }
    }

    return Table(
      border: TableBorder.all(
        color: colorScheme.borderColor,
        width: 1,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {0: FixedColumnWidth(60)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: colorScheme.secondaryCardBackground),
          children: [
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  "時段",
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.subtitleText,
                  ),
                ),
              ),
            ),
            ...visibleWeekDays.map(
              (d) => Container(
                height: 40,
                alignment: Alignment.center,
                child: Text(
                  d,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.primaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
        ...visiblePeriods.map((period) {
          String timeInfo = (_timeMapping[period] ?? "").replaceAll("-", "\n");
          return TableRow(
            children: [
              Container(
                height: 80,
                color: colorScheme.secondaryCardBackground,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      period,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.accentBlue,
                      ),
                    ),
                    Text(
                      timeInfo,
                      style: TextStyle(
                        fontSize: 9,
                        color: colorScheme.subtitleText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              ...List.generate(maxDay, (dayIndex) {
                int currentDay = dayIndex + 1;
                var cellCourse = courseMap["$currentDay-$period"];

                // 檢查是否選取
                bool isSelected =
                    _selectedCourseForDetail?.code == cellCourse?.code &&
                    cellCourse != null;

                return Container(
                  height: 85, // 稍微增加高度
                  padding: const EdgeInsets.all(2),
                  child: cellCourse == null
                      ? const SizedBox()
                      : Material(
                          color: _getCourseColor(
                            cellCourse.name,
                          ).withOpacity(isSelected ? 1.0 : 0.8),
                          borderRadius: BorderRadius.circular(8),
                          elevation: isSelected ? 4 : 0,
                          child: InkWell(
                            onTap: () => setState(
                              () => _selectedCourseForDetail = cellCourse,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    keepUntilLastChinese(cellCourse.name),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                    maxLines: 3,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _extractLocation(cellCourse.location),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                );
              }),
            ],
          );
        }).toList(),
      ],
    );
  }

  Future<void> _refreshFromNetwork() async {
    setState(() => _isLoading = true);
    try {
      await CourseService.instance.refreshAndCache();
      final updatedData = CourseService.instance.allCoursesNotifier.value;
      if (mounted) {
        setState(() {
          _allCourses = updatedData;
          _availableSemesters = updatedData.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          if (_availableSemesters.isNotEmpty) {
            _selectedSemester = _availableSemesters.first;
          }
          _selectedCourseForDetail = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("課表已同步至最新")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("更新失敗: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text(
            "尚未取得課表資料",
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text("請點擊重新整理或回首頁自動同步", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String keepUntilLastChinese(String input) {
    if (input.isEmpty) return "";
    final RegExp chineseRegex = RegExp(r'[\u4e00-\u9fa5]');
    final Iterable<Match> matches = chineseRegex.allMatches(input);
    if (matches.isEmpty) return input;
    
    int lastIndex = matches.last.end;
    
    // 包含最後一個中文字後面的括號、全半形標點、或是括號內的內容
    final RegExp suffixRegex = RegExp(r'^[\s\(\)（）\[\]【】]+');
    final match = suffixRegex.firstMatch(input.substring(lastIndex));
    if (match != null) {
      lastIndex += match.end;
    }
    
    return input.substring(0, lastIndex).trim();
  }

  String _extractLocation(String raw) {
    final regex = RegExp(r'[\(（](.*?)[\)）]');
    final match = regex.firstMatch(raw);
    return match?.group(1) ?? raw;
  }

  String _formatCourseTimeWithRange(Course c) {
    if (c.parsedTimes.isEmpty) return "無時間資料";
    Map<int, List<String>> dayGroups = {};
    for (var t in c.parsedTimes) {
      if (!dayGroups.containsKey(t.day)) dayGroups[t.day] = [];
      dayGroups[t.day]!.add(t.period);
    }
    List<String> results = [];
    List<int> sortedDays = dayGroups.keys.toList()..sort();
    for (var d in sortedDays) {
      List<String> periods = dayGroups[d]!;
      periods.sort(
        (a, b) => _periods.indexOf(a).compareTo(_periods.indexOf(b)),
      );
      String dayName = "週${_fullWeekDays[d - 1]}";
      String periodStr = periods.join(",");
      String? startT = _timeRangeMap[periods.first]?[0];
      String? endT = _timeRangeMap[periods.last]?[1];
      results.add("$dayName $periodStr ($startT-$endT)");
    }
    return results.join("\n");
  }

  Color _getCourseColor(String name, {String? id}) {
    final colors = [
      0xFF1976D2, // Blue 700
      0xFFEF6C00, // Orange 800
      0xFF8E24AA, // Purple 600
      0xFF00796B, // Teal 700
      0xFFD81B60, // Pink 600
      0xFF3949AB, // Indigo 600
      0xFFF4511E, // Deep Orange 600
      0xFF0097A7, // Cyan 700
      0xFFE53935, // Red 600
      0xFF5E35B1, // Deep Purple 600
      0xFF388E3C, // Green 700
    ];
    final String key = id != null ? name + id : name;
    final int hash = key.hashCode.abs();
    return Color(colors[hash % colors.length]);
  }
}

class _GlassSingleSelectDropdown extends StatefulWidget {
  final String label;
  final List<String> items;
  final String value;
  final Function(String?) onChanged;
  final Map<String, String>? displayMap;

  const _GlassSingleSelectDropdown({
    Key? key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.displayMap,
  }) : super(key: key);

  @override
  State<_GlassSingleSelectDropdown> createState() => _GlassSingleSelectDropdownState();
}

class _GlassSingleSelectDropdownState extends State<_GlassSingleSelectDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isOpen = true);
    }
  }

  void _closeDropdown() {
    // 解決 Windows 平台在移除 Overlay 時可能發生的焦點/鍵盤狀態斷言錯誤
    FocusManager.instance.primaryFocus?.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final colorScheme = Theme.of(context).colorScheme;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: 0.95 + 0.05 * val,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: val.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: size.width < 220 ? 220 : size.width,
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: colorScheme.headerBackground,
                      borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.borderColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.items.map((item) {
                          final isSelected = item == widget.value;
                          final label = widget.displayMap != null
                              ? (widget.displayMap![item] ?? item)
                              : item;
                          return _HoverableSingleSelectOption(
                            label: label,
                            isSelected: isSelected,
                            colorScheme: colorScheme,
                            onTap: () {
                              widget.onChanged(item);
                              _closeDropdown();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = widget.displayMap != null
        ? (widget.displayMap![widget.value] ?? widget.value)
        : widget.value;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.label,
                style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
              ),
            ),
          InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.secondaryCardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.borderColor,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.accentBlue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableSingleSelectOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _HoverableSingleSelectOption({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  }) : super(key: key);

  @override
  State<_HoverableSingleSelectOption> createState() => _HoverableSingleSelectOptionState();
}

class _HoverableSingleSelectOptionState extends State<_HoverableSingleSelectOption> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.accentBlue.withValues(alpha: 0.15)
                : (_isHovering ? cs.accentBlue.withValues(alpha: 0.08) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cs.accentBlue.withValues(alpha: 0.4) : (_isHovering ? cs.accentBlue.withValues(alpha: 0.25) : Colors.transparent),
            ),
            boxShadow: _isHovering && !isSelected
                ? [
                    BoxShadow(
                      color: cs.accentBlue.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected || _isHovering ? cs.primaryText : cs.subtitleText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 18, color: cs.accentBlue),
            ],
          ),
        ),
      ),
    );
  }
}
