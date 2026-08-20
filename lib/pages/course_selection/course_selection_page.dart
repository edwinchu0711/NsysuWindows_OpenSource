import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/course_selection_service.dart';
import 'course_status_tab.dart';
import 'course_query_tab.dart';
import '../../models/course_selection_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hover_icon_button.dart';

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

  /// 空白格篩選通知器，讓課表格子點擊可直接驅動右側查詢面板篩選
  final CourseSlotFilterNotifier _slotFilterNotifier = CourseSlotFilterNotifier();

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
    _slotFilterNotifier.dispose();
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
                                         slotFilterNotifier: _slotFilterNotifier,
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
              slotFilterNotifier: _slotFilterNotifier,
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
                                    return _buildSlotCell(
                                      dayKey: (dayIndex + 1).toString(),
                                      periodKey: period,
                                    );
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

                                    return _buildSlotCell(
                                      dayKey: (dayIndex + 1).toString(),
                                      periodKey: period,
                                      child: Container(
                                        height: cellHeight,
                                        padding: const EdgeInsets.all(1.0),
                                        child: _buildScheduleCell(c, titleFontSize, locationFontSize),
                                      ),
                                    );
                                  }

                                  return _buildSlotCell(
                                    dayKey: (dayIndex + 1).toString(),
                                    periodKey: period,
                                    child: Container(
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

  /// 為課表任一格（空堂或有課）包上一層可作為篩選配對的裝飾：
  /// 整格點擊即切換篩選、已選取時繪製邊框 + 勾選角標。
  /// [child] 為 null 代表空堂；非 null 則為有課格（本頁有課格沒有開詳情，整格同樣可點擊切換）。
  Widget _buildSlotCell({
    required String dayKey,
    required String periodKey,
    Widget? child,
  }) {
    // TableCell.intrinsicHeight：量測時貢獻本格自然高度（讓列高 = 最高那格，
    // 不會塌成 0、也不會裁切較高的多課格）；佈局時再被拉伸到整列高度，
    // 這樣已選取的邊框會涵蓋整個時段格，而不是只包到課程區塊的高度。
    // 注意：不能用 fill —— fill 格在 RenderTable 量測列高時會 break 不貢獻高度，
    // 若整列每格都是 fill（本頁時間欄也是 fill），rowHeight 會變 0、整列消失。
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      child: _SlotFilterableCell(
        dayKey: dayKey,
        periodKey: periodKey,
        notifier: _slotFilterNotifier,
        colorScheme: Theme.of(context).colorScheme,
        onToggle: () => _slotFilterNotifier.toggle(dayKey, periodKey),
        child: child,
      ),
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
      if (course.status.contains("退選") ||
          course.status.contains("未選上") ||
          course.status.contains("失敗")) {
        continue;
      }
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
                    HoverIconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "返回主選單",
                      color: colorScheme.primaryText,
                      iconSize: 18,
                      padding: 12,
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
    final colorScheme = Theme.of(context).colorScheme;
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
              const Text("本功能僅為提供選課之便利，請勿過度依賴。", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(
                    alpha: colorScheme.isDark ? 0.2 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "重要提醒：請務必先在「學校選課系統官網」完成「預選課程確認」，才可使用本程式進行選課操作。",
                        style: TextStyle(
                          color: colorScheme.isDark ? Colors.red[300] : Colors.red[800],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "⚠️ 注意事項：",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 4),
              const Text("1. 選完課後，請務必前往「學校官網」確認最終結果。"),
              const Text("2. 若本程式顯示結果與學校系統不一致，請以學校官方為準。"),
              const Text("3. 開發者不負擔因系統時間落差或操作導致之選課風險。"),
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

/// 課表格的「可篩選」裝飾 Widget（整格點擊切換版）。
///
/// 在任意課表格（空堂或有課）上疊加：
/// - 整格點擊即切換該 (星期, 節次) 配對為篩選條件。
/// - 已選取時：2px 外框 + 勾選角標，疊在彩色課格上也清楚可見。
/// - hover 時：淡色底（空堂）/ 細外框（有課）提示可點擊。
///
/// [child] 為 null 代表空堂；非 null 則為有課格內容（本頁有課格沒有開詳情需求，
/// 整格同樣可點擊切換篩選）。
class _SlotFilterableCell extends StatefulWidget {
  final String dayKey;
  final String periodKey;
  final CourseSlotFilterNotifier notifier;
  final ColorScheme colorScheme;
  final VoidCallback onToggle;
  final Widget? child;

  const _SlotFilterableCell({
    required this.dayKey,
    required this.periodKey,
    required this.notifier,
    required this.colorScheme,
    required this.onToggle,
    this.child,
    Key? key,
  }) : super(key: key);

  @override
  State<_SlotFilterableCell> createState() => _SlotFilterableCellState();
}

class _SlotFilterableCellState extends State<_SlotFilterableCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final accent = cs.accentBlue;
    final isEmpty = widget.child == null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: widget.notifier,
        builder: (context, _) {
          final selected =
              widget.notifier.isSelected(widget.dayKey, widget.periodKey);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: Stack(
              children: [
                // 非 positioned 子節點：決定 Stack 自然高度（供 Table 量測列高）。
                // 空堂用透明 SizedBox(70)（不強制寬度，寬度由 Positioned.fill 填滿）；
                // 有課格用課程區塊本身（真實高度）。
                isEmpty ? const SizedBox(height: 70) : widget.child!,
                // 空堂：整格底色（填滿整格，邊框涵蓋整個時段）。
                if (isEmpty)
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(
                                alpha: cs.isDark ? 0.18 : 0.10,
                              )
                            : _isHovered
                                ? accent.withValues(
                                    alpha: cs.isDark ? 0.08 : 0.05,
                                  )
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                // hover 提示外框（未選取時，涵蓋整格）
                if (_isHovered && !selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: accent.withValues(
                              alpha: cs.isDark ? 0.55 : 0.45,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                // 已選取：邊框 + 勾選角標（涵蓋整格，不攔截點擊）
                if (selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: cs.isDark ? 0.18 : 0.12,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: accent, width: 1.5),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 11,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
