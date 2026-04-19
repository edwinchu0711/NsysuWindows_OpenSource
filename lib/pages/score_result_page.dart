import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/historical_score_service.dart';
import '../theme/app_theme.dart';

class ScoreResultPage extends StatefulWidget {
  const ScoreResultPage({Key? key}) : super(key: key);

  @override
  State<ScoreResultPage> createState() => _ScoreResultPageState();
}

enum SummaryType { official, preview, calculated }

class _ScoreResultPageState extends State<ScoreResultPage> {
  String? _selectedYear;
  String? _selectedSem;
  bool _hasInitializedSelection = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: HistoricalScoreService.instance.isLoadingNotifier,
      builder: (context, isLoading, _) {
        return Scaffold(
          backgroundColor: colorScheme.pageBackground,
          appBar: null, // 移除 AppBar
          body: Column(
            children: [
              // 1. 自定義桌面標題列 (代替 AppBar)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 10,
                      right: 20,
                      top: 25,
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
                              onPressed: () => context.go('/home'),
                              tooltip: "返回主選單",
                            ),
                            Text(
                              "歷年成績查詢",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryText,
                              ),
                            ),
                          ],
                        ),
                        // 刷新按鈕
                        _buildRefreshButton(isLoading),
                      ],
                    ),
                  ),
                ),
              ),

              if (isLoading)
                ValueListenableBuilder<double>(
                  valueListenable:
                      HistoricalScoreService.instance.progressNotifier,
                  builder: (context, progress, _) => LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryCardBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.accentBlue,
                    ),
                    minHeight: 3,
                  ),
                ),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable:
                          HistoricalScoreService.instance.validYearsNotifier,
                      builder: (context, validYearsSet, child) {
                        if (validYearsSet.isEmpty) {
                          return Center(
                            child: isLoading
                                ? Text(
                                    "正在搜尋歷年成績...\n請稍候",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.subtitleText,
                                    ),
                                  )
                                : Text(
                                    "查無任何成績資料",
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.subtitleText,
                                    ),
                                  ),
                          );
                        }

                        List<String> sortedYears = validYearsSet.toList()
                          ..sort(
                            (a, b) => int.parse(b).compareTo(int.parse(a)),
                          );

                        if (_selectedYear == null ||
                            !validYearsSet.contains(_selectedYear)) {
                          _selectedYear = sortedYears.first;
                        }

                        List<String> availableSems =
                            HistoricalScoreService
                                .instance
                                .validSemestersNotifier
                                .value[_selectedYear] ??
                            [];
                        availableSems.sort();

                        if (_selectedSem == null ||
                            !availableSems.contains(_selectedSem)) {
                          _selectedSem = availableSems.last;
                        }

                        return Column(
                          children: [
                            // 2. 常駐說明盒 (最上方全寬)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: _buildPersistentInfoBox(),
                            ),

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 左側：選單與名次統計 (約 35%)
                                    SizedBox(
                                      width: 320,
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.only(
                                          bottom: 20,
                                        ),
                                        child: Column(
                                          children: [
                                            _buildDesktopSelectorArea(
                                              sortedYears,
                                              availableSems,
                                            ),
                                            const SizedBox(height: 16),
                                            _buildScoreSummaryPane(
                                              _selectedYear!,
                                              _selectedSem!,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 24),

                                    // 右側：課程成績 (Expanded)
                                    Expanded(
                                      child: _buildCourseListPane(
                                        _selectedYear!,
                                        _selectedSem!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ 新增：自定義刷新按鈕
  Widget _buildRefreshButton(bool isLoading) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isLoading
          ? null
          : () => HistoricalScoreService.instance.fetchAllData(),
      mouseCursor: isLoading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.borderColor),
        ),
        child: Row(
          children: [
            isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: colorScheme.accentBlue,
                  ),
            const SizedBox(width: 6),
            Text(
              isLoading ? "同步中" : "重新整理",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 修改：學期選擇器區域 (垂直排列適配左側欄)
  Widget _buildDesktopSelectorArea(
    List<String> sortedYears,
    List<String> availableSems,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: Theme.of(context).colorScheme.subtitleText,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "學期切換",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.subtitleText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown("選擇學年", sortedYears, _selectedYear!, (val) {
            setState(() {
              _selectedYear = val;
              _selectedSem = null;
            });
          }),
          const SizedBox(height: 12),
          _buildDropdown(
            "選擇學期",
            availableSems,
            _selectedSem!,
            (val) {
              setState(() => _selectedSem = val);
            },
            displayMap: {"1": "上學期", "2": "下學期", "3": "暑修"},
          ),
        ],
      ),
    );
  }

  // ✅ 新增：判定目前是否為預覽名次功能的自動關閉期間
  bool _isRankPreviewOffPeriod() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    // 期間 1: 3/20 ~ 6/5
    bool inPeriod1 =
        (month == 3 && day >= 20) ||
        (month > 3 && month < 6) ||
        (month == 6 && day <= 5);
    // 期間 2: 10/15 ~ 1/5 (跨年)
    bool inPeriod2 =
        (month == 10 && day >= 15) || (month > 10) || (month == 1 && day <= 5);

    return inPeriod1 || inPeriod2;
  }

  // ✅ 新增：常駐型預覽說明盒
  Widget _buildPersistentInfoBox() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        bool isPreviewEnabled =
            snapshot.data!.getBool('is_preview_rank_enabled') ?? false;
        bool isOffPeriod = _isRankPreviewOffPeriod();

        // 判定狀態類型
        bool isCurrentlyActive = isPreviewEnabled && !isOffPeriod;
        bool isEnabledButInactive = isPreviewEnabled && isOffPeriod;

        Color bgColor = isCurrentlyActive
            ? (Theme.of(context).colorScheme.isDark
                  ? Colors.blue[900]!.withOpacity(0.2)
                  : Colors.blue[50]!)
            : (isEnabledButInactive
                  ? (Theme.of(context).colorScheme.isDark
                        ? Colors.orange[900]!.withOpacity(0.2)
                        : Colors.orange[50]!)
                  : Theme.of(context).colorScheme.secondaryCardBackground);

        Color borderColor = isCurrentlyActive
            ? Theme.of(context).colorScheme.accentBlue.withOpacity(0.3)
            : (isEnabledButInactive
                  ? Colors.orange.withOpacity(0.5)
                  : Theme.of(context).colorScheme.borderColor);

        Color titleColor = isCurrentlyActive
            ? Theme.of(context).colorScheme.accentBlue
            : (isEnabledButInactive
                  ? Colors.orange[400]!
                  : Theme.of(context).colorScheme.primaryText);

        IconData icon = isCurrentlyActive
            ? Icons.info_rounded
            : (isEnabledButInactive
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline_rounded);

        Color iconColor = isCurrentlyActive
            ? Theme.of(context).colorScheme.accentBlue
            : (isEnabledButInactive
                  ? Colors.orange[400]!
                  : Theme.of(context).colorScheme.subtitleText);

        String statusTitle = "預覽名次：未開啟";
        if (isCurrentlyActive) statusTitle = "預覽名次：已開啟";
        if (isEnabledButInactive) statusTitle = "預覽名次：已開啟 (目前系統自動關閉中)";

        String description =
            "目前沒有開啟預覽名次，抓取速度快。若是要看預覽名次，請到設定頁面去開啟。\n※ 注意：3/20~6/5 和 10/15~1/5 期間此功能會強制關閉，為了節省時間。";
        if (isCurrentlyActive) {
          description =
              "現在有開啟預覽名次，每次抓取會比較久。若是已抓到要的資料，可以先去設定關閉以加快速度。\n※ 注意：1. 3/20~6/5 和 10/15~1/5 期間此功能會強制關閉。 2. 若寒暑假期間查無預覽資料，推測為系統更動，建議暫時關閉以維持效率。";
        } else if (isEnabledButInactive) {
          description =
              "您已開啟預覽名次功能，但目前正處於系統自動關閉期間 (3/20~6/5 或 10/15~1/5)，因此目前不會有預覽效果且不影響抓取速度。\n待限制期間過後，功能將自動恢復運作。";
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: titleColor.withOpacity(0.85),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ 新增：左側統計面版
  Widget _buildScoreSummaryPane(String year, String sem) {
    String key = "$year-$sem";
    final courses =
        HistoricalScoreService.instance.coursesNotifier.value[key] ?? [];
    var officialSummary =
        HistoricalScoreService.instance.summaryNotifier.value[key] ??
        ScoreSummary();
    var previewData =
        HistoricalScoreService.instance.previewRanksNotifier.value[key];

    if (courses.isEmpty) return const SizedBox.shrink();

    bool hasValidValue(String? value) =>
        value != null && value.isNotEmpty && value != "-";

    ScoreSummary finalSummary;
    SummaryType type;
    bool isOfficialValid = hasValidValue(officialSummary.average);

    if (isOfficialValid) {
      finalSummary = officialSummary;
      type = SummaryType.official;
      if (!hasValidValue(finalSummary.rank) &&
          previewData != null &&
          hasValidValue(previewData['rank'])) {
        finalSummary.rank = previewData['rank']!;
        finalSummary.classSize = previewData['classSize'] ?? "-";
      }
    } else {
      ScoreSummary calculated = _calculateSemesterSummary(courses);
      bool hasPreviewRank =
          previewData != null && hasValidValue(previewData['rank']);
      if (hasPreviewRank) {
        finalSummary = ScoreSummary(
          creditsTaken: calculated.creditsTaken,
          creditsEarned: calculated.creditsEarned,
          average: calculated.average,
          rank: previewData!['rank']!,
          classSize: previewData['classSize'] ?? "-",
        );
        type = SummaryType.preview;
      } else {
        finalSummary = calculated;
        type = SummaryType.calculated;
      }
    }

    return _buildSummaryCard(finalSummary, type);
  }

  // ✅ 改名與簡化：右側課程清單
  Widget _buildCourseListPane(String year, String sem) {
    String key = "$year-$sem";
    final courses =
        HistoricalScoreService.instance.coursesNotifier.value[key] ?? [];

    if (courses.isEmpty) {
      return Center(
        child: Text(
          "資料載入異常",
          style: TextStyle(color: Theme.of(context).colorScheme.subtitleText),
        ),
      );
    }

    return Column(
      children: [
        _buildTableHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 40),
            itemCount: courses.length,
            itemBuilder: (context, index) => _buildCourseCard(courses[index]),
          ),
        ),
      ],
    );
  }

  ScoreSummary _calculateSemesterSummary(List<CourseScore> courses) {
    double totalWeightedPoints = 0;
    double gpaCredits = 0;
    double creditsTaken = 0;
    double creditsEarned = 0;

    final Map<String, double> gradePoints = {
      "A+": 4.3,
      "A": 4.0,
      "A-": 3.7,
      "B+": 3.3,
      "B": 3.0,
      "B-": 2.7,
      "C+": 2.3,
      "C": 2.0,
      "C-": 1.7,
      "D": 1.0,
      "E": 0.0,
      "F": 0.0,
      "X": 0.0,
    };

    for (var course in courses) {
      double credit = double.tryParse(course.credits) ?? 0;
      String score = course.score.trim();

      if (score.contains("抵免")) continue;
      creditsTaken += credit;

      if (score != "E" && score != "F" && score != "X" && score != "") {
        creditsEarned += credit;
      }

      if (score != "(P)" && gradePoints.containsKey(score)) {
        gpaCredits += credit;
        totalWeightedPoints += (credit * gradePoints[score]!);
      }
    }

    double avg = gpaCredits > 0 ? (totalWeightedPoints / gpaCredits) : 0.0;

    return ScoreSummary(
      creditsTaken: creditsTaken.toInt().toString(),
      creditsEarned: creditsEarned.toInt().toString(),
      average: avg == 0.0 ? "0" : avg.toStringAsFixed(2),
      rank: "--",
      classSize: "--",
    );
  }

  @override
  void initState() {
    super.initState();
    _autoSelectSemester();
    HistoricalScoreService.instance.summaryNotifier.addListener(
      _autoSelectSemester,
    );
  }

  @override
  void dispose() {
    HistoricalScoreService.instance.summaryNotifier.removeListener(
      _autoSelectSemester,
    );
    super.dispose();
  }

  void _autoSelectSemester() {
    if (_hasInitializedSelection) return;

    final coursesMap = HistoricalScoreService.instance.coursesNotifier.value;
    final yearsSet = HistoricalScoreService.instance.validYearsNotifier.value;
    if (yearsSet.isEmpty || coursesMap.isEmpty) return;

    // 排序年份：114, 113, 112...
    List<String> years = yearsSet.toList()..sort((a, b) => b.compareTo(a));

    int currentMonth = DateTime.now().month;
    String targetSem = (currentMonth >= 5 && currentMonth <= 10) ? "2" : "1";

    // --- 策略 1：精準匹配 (找最新年份且符合月份的學期) ---
    // 假設現在 1 月，targetSem = "1"，我們會找 114-1，找不到就找 113-1
    for (var year in years) {
      String key = "$year-$targetSem";
      if (coursesMap.containsKey(key) && coursesMap[key]!.isNotEmpty) {
        setState(() {
          _selectedYear = year;
          _selectedSem = targetSem;
          _hasInitializedSelection = true;
        });
        print("DEBUG: 自動定位成功 -> $key");
        return;
      }
    }

    // --- 策略 2：退而求其次 (找最新有資料的學期，不論學期號) ---
    // 如果 1 月份卻還沒 114-1 的資料，就抓目前最新的一筆 (可能是 113-2)
    for (var year in years) {
      final sems =
          HistoricalScoreService.instance.validSemestersNotifier.value[year] ??
                []
            ..sort((a, b) => b.compareTo(a)); // 由大到小排序 (2 -> 1)

      for (var sem in sems) {
        String key = "$year-$sem";
        if (coursesMap[key]?.isNotEmpty ?? false) {
          setState(() {
            _selectedYear = year;
            _selectedSem = sem;
            _hasInitializedSelection = true;
          });
          print("DEBUG: 保底定位成功 -> $key");
          return;
        }
      }
    }
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              "學分",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.subtitleText,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "課程名稱 / 代碼",
              style: TextStyle(
                color: Theme.of(context).colorScheme.subtitleText,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            "成績",
            style: TextStyle(
              color: Theme.of(context).colorScheme.subtitleText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged, {
    Map<String, String>? displayMap,
  }) {
    return _GlassSingleSelectDropdown(
      label: label,
      items: items,
      value: value,
      onChanged: onChanged,
      displayMap: displayMap,
    );
  }

  Widget _buildCourseCard(CourseScore course) {
    final colorScheme = Theme.of(context).colorScheme;
    double scoreVal = double.tryParse(course.score) ?? 0;
    bool isPass = scoreVal >= 60;
    bool isNumber = RegExp(r'^\d+$').hasMatch(course.score);
    Color scoreColor;
    if (isNumber) {
      if (scoreVal >= 90) {
        scoreColor = colorScheme.isDark ? Colors.redAccent : Colors.red[700]!;
      } else if (isPass) {
        scoreColor = colorScheme.primaryText;
      } else {
        scoreColor = colorScheme.isDark
            ? Colors.redAccent[100]!
            : Colors.redAccent;
      }
    } else {
      scoreColor = colorScheme.isDark ? Colors.blueGrey[300]! : Colors.blueGrey;
    }

    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHovered
                    ? Colors.blue.withOpacity(0.6)
                    : colorScheme.borderColor,
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        spreadRadius: 0,
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ), // 縮減內部上下間距
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38, // 縮小圓圈
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.isDark
                          ? Colors.blue[900]!.withOpacity(0.3)
                          : Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        course.credits,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.accentBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          course.id,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.subtitleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    course.score,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ★★★ 修改：根據 Type 切換顏色與標題 ★★★
  Widget _buildSummaryCard(ScoreSummary summary, SummaryType type) {
    List<Color> bgColors;
    Color themeColor;
    String title;
    IconData icon;
    bool showRank = true;

    switch (type) {
      case SummaryType.official:
        bgColors = Theme.of(context).colorScheme.isDark
            ? [Colors.teal[900]!, Colors.teal[800]!]
            : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)];
        themeColor = Theme.of(context).colorScheme.isDark
            ? Colors.teal[200]!
            : Colors.teal[800]!;
        title = "學期統計";
        icon = Icons.analytics_outlined;
        break;
      case SummaryType.preview:
        bgColors = Theme.of(context).colorScheme.isDark
            ? [Colors.pink[900]!, Colors.pink[800]!]
            : [const Color(0xFFFFF1F1), const Color(0xFFFFE4E8)];
        themeColor = Theme.of(context).colorScheme.isDark
            ? Colors.pink[200]!
            : Colors.pink[800]!;
        title = "學期統計 (預覽)";
        icon = Icons.preview_rounded;
        break;
      case SummaryType.calculated:
        bgColors = Theme.of(context).colorScheme.isDark
            ? [Colors.green[900]!, Colors.green[800]!]
            : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)];
        themeColor = Theme.of(context).colorScheme.isDark
            ? Colors.green[200]!
            : Colors.green[800]!;
        title = "學期統計 (試算)";
        icon = Icons.calculate_outlined;
        showRank = false;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ), // 稍微縮減上下內距
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 使用 Row 並限制高度，解決 Icon 撐開空間的問題
          SizedBox(
            height: 28, // 固定標題列高度，讓視覺更緊湊
            child: Row(
              children: [
                Icon(icon, color: themeColor, size: 20), // 稍微縮小 Icon
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                if (type == SummaryType.preview) ...[
                  const Spacer(),
                  // 使用 GestureDetector 取代 IconButton 以節省空間
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text("預覽資料說明"),
                          content: const Text(
                            "此名次資料是從學校其他系統中抓取的資料，並非最終結果。\n\n"
                            "• 學分/平均：由程式依據下方課程成績自動試算。\n"
                            "• 名次與人數：抓取來源非學校成績查訊系統。\n\n"
                            "請注意：這不是教務處正式成績單，僅供參考，準確資料請以開學後學校正式公告為準。",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text("了解"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: themeColor.withOpacity(0.7),
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(
            color: themeColor.withOpacity(0.2),
            height: 12,
          ), // 縮小 Divider 的高度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem("修習學分", summary.creditsTaken, themeColor),
              _buildSummaryItem("實得學分", summary.creditsEarned, themeColor),
              _buildSummaryItem(
                "平均分數",
                summary.average,
                themeColor,
                isHighlight: true,
              ),
            ],
          ),

          if (showRank) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "本學期名次",
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        summary.rank,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.isDark
                              ? Colors.white
                              : themeColor,
                        ),
                      ),
                      Text(
                        " / ${summary.classSize}",
                        style: TextStyle(
                          color:
                              (Theme.of(context).colorScheme.isDark
                                      ? Colors.white
                                      : themeColor)
                                  .withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    Color color, {
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? (Theme.of(context).colorScheme.isDark
                      ? Colors.orangeAccent
                      : Colors.deepOrange)
                : color,
          ),
        ),
      ],
    );
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
  State<_GlassSingleSelectDropdown> createState() =>
      _GlassSingleSelectDropdownState();
}

class _GlassSingleSelectDropdownState
    extends State<_GlassSingleSelectDropdown> {
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
                    width: size.width,
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
                        ),
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
        children: [
          Text(
            widget.label,
            style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryCardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
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
  State<_HoverableSingleSelectOption> createState() =>
      _HoverableSingleSelectOptionState();
}

class _HoverableSingleSelectOptionState
    extends State<_HoverableSingleSelectOption> {
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
                : (_isHovering
                      ? cs.accentBlue.withValues(alpha: 0.08)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? cs.accentBlue.withValues(alpha: 0.4)
                  : (_isHovering
                        ? cs.accentBlue.withValues(alpha: 0.25)
                        : Colors.transparent),
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
                    color: isSelected || _isHovering
                        ? cs.primaryText
                        : cs.subtitleText,
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
