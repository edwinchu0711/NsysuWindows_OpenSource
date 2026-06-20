import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/course_selection_service.dart';
import 'course_status_tab.dart';
import 'course_query_tab.dart';
import '../../models/course_selection_models.dart';
import '../../theme/app_theme.dart';

class CourseSelectionPage extends StatefulWidget {
  final bool enableQuery;

  const CourseSelectionPage({Key? key, this.enableQuery = true})
    : super(key: key);

  @override
  State<CourseSelectionPage> createState() => _CourseSelectionPageState();
}

class _CourseSelectionPageState extends State<CourseSelectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String _message = "資料讀取中...";
  List<CourseSelectionData> _myCourses = [];
  bool _isSystemClosed = false;
  bool _isNeedConfirmation = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.enableQuery ? 2 : 1,
      vsync: this,
    );
    _loadMyCourses();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.enableQuery) {
        _showDisclaimerDialog();
      }
    });
  }

  Future<void> _loadMyCourses() async {
    setState(() {
      _isLoading = true;
      _message = "正在登入選課系統...";
      _isSystemClosed = false;
      _isNeedConfirmation = false;
    });

    try {
      final result = await CourseSelectionService.instance
          .fetchSelectionResult();
      final SelectionState state = result['state'];
      final List<CourseSelectionData> data = result['data'];

      if (state == SelectionState.closed) {
        setState(() {
          _isSystemClosed = true;
          _isLoading = false;
        });
      } else if (state == SelectionState.needConfirmation) {
        setState(() {
          _isNeedConfirmation = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _myCourses = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = "發生錯誤：$e";
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: null, // 移除佈局
      body: Column(
        children: [
          // 1. 自定義桌面標題列與導航
          _buildDesktopHeader(isDesktop),

          // 2. 主內容區域
          Expanded(
            child: _isNeedConfirmation
                ? _buildNeedConfirmationView()
                : (isDesktop && widget.enableQuery
                      ? _buildDesktopLayout()
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: widget.enableQuery
                                ? TabBarView(
                                    controller: _tabController,
                                     children: [
                                       _buildStatusTab(),
                                       CourseQueryTab(
                                         currentCourses: _myCourses,
                                         onRequestRefresh: _loadMyCourses,
                                         isLoading: _isLoading,
                                       ),
                                     ],
                                  )
                                : _buildStatusTab(),
                          ),
                        )),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedConfirmationView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 80,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 24),
            Text(
              "尚未完成預選課程確認",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "請利用學校官網完成預選課程的確認，再使用本程式進行選課。",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colorScheme.subtitleText),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse("https://selcrs.nsysu.edu.tw");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text("前往學校官網確認"),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadMyCourses, child: const Text("主動重新整理")),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左側：目前選課狀況 (28%)
        Expanded(
          flex: 28,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(right: BorderSide(color: colorScheme.borderColor)),
            ),
            child: _buildStatusTab(),
          ),
        ),
        // 中間：課表 (32%)
        Expanded(
          flex: 32,
          child: Container(
            color: Colors.transparent,
            child: _buildMiddleSchedulePane(),
          ),
        ),
        // 右側：課程查詢 / 加退選 (40%)
        Expanded(
          flex: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(left: BorderSide(color: colorScheme.borderColor)),
            ),
            child: CourseQueryTab(
              currentCourses: _myCourses,
              onRequestRefresh: _loadMyCourses,
              isLoading: _isLoading,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleSchedulePane() {
    final colorScheme = Theme.of(context).colorScheme;
    final scheduleMap = _parseCoursesToSchedule();
    List<int> visibleDays = [0, 1, 2, 3, 4];
    if (_hasCourseInDay(scheduleMap, 5)) visibleDays.add(5);
    if (_hasCourseInDay(scheduleMap, 6)) visibleDays.add(6);
    List<String> visiblePeriods = _calculateVisiblePeriods(scheduleMap);
    int maxDay = visibleDays.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(bottom: BorderSide(color: colorScheme.borderColor)),
          ),
          child: Text(
            "預覽課表",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.primaryText,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.5),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      double columnWidth = (width - 50) / maxDay;
                      double titleFontSize = (10.0 + (columnWidth - 60.0) * 0.1).clamp(8.0, 14.0);
                      double locationFontSize = (8.0 + (columnWidth - 60.0) * 0.08).clamp(7.0, 11.0);

                      return Table(
                        border: TableBorder(
                          horizontalInside: BorderSide(
                            color: colorScheme.borderColor,
                            width: 0.8,
                          ),
                          verticalInside: BorderSide(
                            color: colorScheme.borderColor,
                            width: 0.8,
                          ),
                        ),
                        columnWidths: const {0: FixedColumnWidth(50)},
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: colorScheme.timetableHeader,
                            ),
                            children: [
                              SizedBox(
                                height: 35,
                                child: Center(
                                  child: Text(
                                    "時段",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.subtitleText,
                                    ),
                                  ),
                                ),
                              ),
                              ...visibleDays.map(
                                (dayIndex) => Container(
                                  height: 35,
                                  alignment: Alignment.center,
                                  child: Text(
                                    ['一', '二', '三', '四', '五', '六', '日'][dayIndex],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: colorScheme.subtitleText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...visiblePeriods.map((period) {
                            String timeInfo = _timeMapping[period] ?? "";
                            return TableRow(
                              children: [
                                TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.fill,
                                  child: Container(
                                    color: colorScheme.timetableSlot,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          period,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: colorScheme.subtitleText,
                                          ),
                                        ),
                                        if (timeInfo.isNotEmpty)
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
                                ),
                                ...visibleDays.map((dayIndex) {
                                  final coursesInThisSlot =
                                      scheduleMap[dayIndex]?[period] ?? [];
                                  if (coursesInThisSlot.isEmpty) {
                                    return Container(height: 70);
                                  }

                                  if (coursesInThisSlot.length == 1) {
                                    final c = coursesInThisSlot.first;
                                    final displayName = keepUntilLastChinese(c.name);
                                    double cellHeight = 70.0;
                                    if (displayName.length > 20) {
                                      cellHeight += 30.0;
                                    } else if (displayName.length > 15) {
                                      cellHeight += 20.0;
                                    } else if (displayName.length > 10) {
                                      cellHeight += 10.0;
                                    }

                                    return Container(
                                      height: cellHeight,
                                      padding: const EdgeInsets.all(1.0),
                                      child: _buildScheduleCell(c, titleFontSize, locationFontSize),
                                    );
                                  }

                                  return Container(
                                    constraints: const BoxConstraints(minHeight: 70),
                                    padding: const EdgeInsets.all(1.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: coursesInThisSlot.map((c) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 2.0),
                                          child: _buildScheduleCell(c, titleFontSize, locationFontSize),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCell(
    CourseSelectionData course,
    double titleFontSize,
    double locationFontSize,
  ) {
    Color bgColor;
    if (course.status.contains("選上")) {
      bgColor = Colors.green[500]!;
    } else if (course.status.contains("退選") || course.status.contains("未選上")) {
      bgColor = Colors.grey[400]!;
    } else {
      bgColor = Colors.orange[400]!;
    }

    String room = _parseRoomName(course.timeRoom);
    final displayName = keepUntilLastChinese(course.name);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            displayName,
            style: TextStyle(
              fontSize: titleFontSize,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          if (room.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              room,
              style: TextStyle(
                fontSize: locationFontSize,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }

  String keepUntilLastChinese(String input) {
    final RegExp chineseRegex = RegExp(r'[\u4e00-\u9fa5]');
    final Iterable<Match> matches = chineseRegex.allMatches(input);
    if (matches.isEmpty) return input.split('\n')[0];
    int lastIndex = matches.last.end;
    String prefix = input.substring(0, lastIndex);

    // Count unmatched open parentheses in prefix
    int standardOpen = 0;
    int fullwidthOpen = 0;
    for (int i = 0; i < prefix.length; i++) {
      String char = prefix[i];
      if (char == '(') {
        standardOpen++;
      } else if (char == '（') {
        fullwidthOpen++;
      } else if (char == ')') {
        if (standardOpen > 0) standardOpen--;
      } else if (char == '）') {
        if (fullwidthOpen > 0) fullwidthOpen--;
      }
    }

    // Scan remaining string to find matching closing parentheses
    String suffix = "";
    for (int i = lastIndex; i < input.length; i++) {
      if (standardOpen == 0 && fullwidthOpen == 0) {
        break;
      }
      String char = input[i];
      suffix += char;
      if (char == ')') {
        if (standardOpen > 0) standardOpen--;
      } else if (char == '）') {
        if (fullwidthOpen > 0) fullwidthOpen--;
      }
    }

    return prefix + suffix;
  }

  // --- Helpers for middle pane ---
  final Map<String, String> _timeMapping = {
    'A': '07:00\n07:50',
    '1': '08:10\n09:00',
    '2': '09:10\n10:00',
    '3': '10:10\n11:00',
    '4': '11:10\n12:00',
    'B': '12:10\n13:00',
    '5': '13:10\n14:00',
    '6': '14:10\n15:00',
    '7': '15:10\n16:00',
    '8': '16:10\n17:00',
    '9': '17:10\n18:00',
    'C': '18:20\n19:10',
    'D': '19:15\n20:05',
    'E': '20:10\n21:00',
    'F': '21:05\n21:55',
  };

  Map<int, Map<String, List<CourseSelectionData>>> _parseCoursesToSchedule() {
    Map<int, Map<String, List<CourseSelectionData>>> map = {};
    for (var course in _myCourses) {
      if (course.status.contains("退選") || course.status.contains("未選上"))
        continue;
      if (course.timeRoom.isEmpty) continue;
      String rawTimeOnly = course.timeRoom.replaceAll(
        RegExp(r'[(\uff08].*?[)\uff09]'),
        '',
      );
      int? currentDay;
      final _weekDays = ['一', '二', '三', '四', '五', '六', '日'];
      final _allPeriods = [
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

      for (int i = 0; i < rawTimeOnly.length; i++) {
        String char = rawTimeOnly[i];
        int dayIndex = _weekDays.indexOf(char);
        if (dayIndex != -1) {
          currentDay = dayIndex;
          continue;
        }
        if (_allPeriods.contains(char)) {
          if (currentDay != null) {
            if (!map.containsKey(currentDay)) map[currentDay] = {};
            if (!map[currentDay]!.containsKey(char))
              map[currentDay]![char] = [];
            if (!map[currentDay]![char]!.contains(course))
              map[currentDay]![char]!.add(course);
          }
        }
      }
    }
    return map;
  }

  bool _hasCourseInDay(
    Map<int, Map<String, List<CourseSelectionData>>> map,
    int dayIndex,
  ) {
    return map.containsKey(dayIndex) && map[dayIndex]!.isNotEmpty;
  }

  List<String> _calculateVisiblePeriods(
    Map<int, Map<String, List<CourseSelectionData>>> map,
  ) {
    List<String> result = [];
    List<String> corePeriods = [
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
    ];

    bool hasA = false;
    for (var dayData in map.values) {
      if (dayData.containsKey('A') && dayData['A']!.isNotEmpty) hasA = true;
    }
    if (hasA) result.add('A');

    result.addAll(corePeriods);

    bool hasF = false, hasE = false, hasD = false;
    for (var dayData in map.values) {
      if (dayData.containsKey('F') && dayData['F']!.isNotEmpty) hasF = true;
      if (dayData.containsKey('E') && dayData['E']!.isNotEmpty) hasE = true;
      if (dayData.containsKey('D') && dayData['D']!.isNotEmpty) hasD = true;
    }
    if (hasF) {
      result.addAll(['D', 'E', 'F']);
    } else if (hasE) {
      result.addAll(['D', 'E']);
    } else if (hasD) {
      result.addAll(['D']);
    }
    return result;
  }

  String _parseRoomName(String timeRoom) {
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(timeRoom);
    return match?.group(1)?.trim() ?? "";
  }

  Widget _buildDesktopHeader(bool isDesktop) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 20,
              top: 10,
              bottom: 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "返回主選單",
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.enableQuery ? "選課系統" : "目前選課狀態",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                  ],
                ),
                // 已移除重新整理按鈕
              ],
            ),
          ),
          if (widget.enableQuery && !isDesktop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: colorScheme.accentBlue,
                  unselectedLabelColor: colorScheme.subtitleText,
                  indicatorColor: colorScheme.accentBlue,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: "目前選課情況"),
                    Tab(text: "課程查詢 / 加退選"),
                  ],
                ),
              ),
            ),
          Divider(height: 1, color: colorScheme.borderColor),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    return CourseStatusTab(
      isLoading: _isLoading,
      message: _message,
      isSystemClosed: _isSystemClosed,
      courses: _myCourses,
      onRefresh: _loadMyCourses,
    );
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          "選課免責聲明",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("本功能僅為提供選課之便利，請勿過度依賴。", style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              Text(
                "⚠️ 注意事項：",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              SizedBox(height: 4),
              Text("1. 選完課後，請務必前往「學校官網」確認最終結果。"),
              Text("2. 若本程式顯示結果與學校系統不一致，請以學校官方為準。"),
              Text("3. 開發者不負擔因系統時間落差或操作導致之選課風險。"),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("我了解並同意，我會去官網檢查"),
          ),
        ],
      ),
    );
  }
}
