import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/score_item.dart';
import '../services/course_evaluation_service.dart';
import '../services/historical_score_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_dropdown.dart';
import 'score_tracking_detail.dart';
import 'score_tracking_migration_dialog.dart';

class ScoreTrackingPage extends StatefulWidget {
  const ScoreTrackingPage({Key? key}) : super(key: key);

  @override
  State<ScoreTrackingPage> createState() => _ScoreTrackingPageState();
}

class _ScoreTrackingPageState extends State<ScoreTrackingPage> {
  String? _selectedYear;
  String? _selectedSem;
  bool _hasInitializedSelection = false;

  // 課程配分資料快取：key = courseId
  final Map<String, CourseScoreData> _courseDataCache = {};

  // 選擇狀態
  String? _selectedCourseId;

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

    List<String> years = yearsSet.toList()..sort((a, b) => b.compareTo(a));

    for (var year in years) {
      final sems =
          HistoricalScoreService.instance.validSemestersNotifier.value[year] ??
                []
            ..sort((a, b) => b.compareTo(a));
      for (var sem in sems) {
        String key = "$year-$sem";
        if (coursesMap[key]?.isNotEmpty ?? false) {
          if (mounted) {
            setState(() {
              _selectedYear = year;
              _selectedSem = sem;
              _hasInitializedSelection = true;
            });
          }
          return;
        }
      }
    }
  }

  /// 載入課程配分資料（從本地儲存或網路）
  Future<CourseScoreData?> _loadCourseData(
    String courseId,
    String courseName,
  ) async {
    if (_courseDataCache.containsKey(courseId)) {
      return _courseDataCache[courseId];
    }

    final prefs = await SharedPreferences.getInstance();
    final key =
        'score_tracking_scores_${_selectedYear}_${_selectedSem}_$courseId';
    final jsonStr = prefs.getString(key);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final data = CourseScoreData.fromJson(json.decode(jsonStr));
        _courseDataCache[courseId] = data;
        return data;
      } catch (e) {
        print("載入課程配分資料失敗: $e");
      }
    }

    // 首次載入，嘗試從網路抓取
    if (_selectedYear != null && _selectedSem != null) {
      final evals = await CourseEvaluationService.instance.fetchEvaluation(
        year: _selectedYear!,
        semester: _selectedSem!,
        courseId: courseId,
      );

      List<ScoreItem> items = [];
      if (evals.isNotEmpty &&
          evals.first != "載入失敗" &&
          evals.first != "查無資料" &&
          evals.first != "尚無評分方式資料") {
        for (var evalStr in evals) {
          final match = RegExp(
            r'^(\d+)\.\s*(.+?)\s*：\s*(\d+(?:\.\d+)?)\s*%$',
          ).firstMatch(evalStr);
          if (match != null) {
            items.add(
              ScoreItem.fromRawData(
                match.group(2)!.trim(),
                double.tryParse(match.group(3)!) ?? 0.0,
              ),
            );
          }
        }
      }

      final data = CourseScoreData(
        courseId: courseId,
        courseName: courseName,
        items: items,
      );
      _courseDataCache[courseId] = data;
      await _saveCourseData(courseId, data);
      return data;
    }

    return null;
  }

  /// 儲存課程配分資料
  Future<void> _saveCourseData(String courseId, CourseScoreData data) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'score_tracking_scores_${_selectedYear}_${_selectedSem}_$courseId';
    data.lastUpdated = DateTime.now();
    await prefs.setString(key, json.encode(data.toJson()));
  }

  /// 清除當前學期所有分數追蹤資料
  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("重置分數追蹤"),
        content: Text("確定要清除 $_selectedYear 學年第 $_selectedSem 學期的所有分數追蹤資料嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "確定清除",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs.getKeys().where((k) {
      return k.startsWith(
        'score_tracking_scores_${_selectedYear}_${_selectedSem}_',
      );
    }).toList();

    for (var key in keysToRemove) {
      await prefs.remove(key);
    }

    _courseDataCache.clear();
    _selectedCourseId = null;

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("已清除當前學期分數追蹤資料")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: HistoricalScoreService.instance.isLoadingNotifier,
      builder: (context, isLoading, _) {
        return Scaffold(
          backgroundColor: colorScheme.pageBackground,
          body: Column(
            children: [
              // 自定義標題列
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
                              "分數試算",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primaryText,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedYear != null && _selectedSem != null)
                          TextButton.icon(
                            onPressed: _resetAllData,
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text("重置"),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.subtitleText,
                            ),
                          ),
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
                    backgroundColor: colorScheme.secondaryCardBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.accentBlue,
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
                                      color: colorScheme.subtitleText,
                                    ),
                                  )
                                : Text(
                                    "查無任何成績資料",
                                    style: TextStyle(
                                      color: colorScheme.subtitleText,
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
                            // 頂部學期選擇器
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: _buildSemesterSelector(
                                sortedYears,
                                availableSems,
                              ),
                            ),

                            // 常駐說明盒
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              child: _buildInfoBox(),
                            ),

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 600) {
                                      // 寬螢幕：左右分列
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(
                                                    color:
                                                        colorScheme.borderColor,
                                                  ),
                                                ),
                                              ),
                                              child: _buildCourseListPane(),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: _buildCourseDetailPane(),
                                          ),
                                        ],
                                      );
                                    } else {
                                      // 窄螢幕：如果未選擇課程，顯示列表；否則顯示詳細內容（帶返回按鈕）
                                      if (_selectedCourseId == null) {
                                        return _buildCourseListPane();
                                      } else {
                                        return Column(
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedCourseId = null;
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.arrow_back,
                                                ),
                                                label: const Text("返回課程列表"),
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildCourseDetailPane(),
                                            ),
                                          ],
                                        );
                                      }
                                    }
                                  },
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

  Widget _buildSemesterSelector(
    List<String> sortedYears,
    List<String> availableSems,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, color: colorScheme.subtitleText, size: 18),
          const SizedBox(width: 8),
          Text(
            "學期切換",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.subtitleText,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdown("選擇學年", sortedYears, _selectedYear!, (val) {
              setState(() {
                _selectedYear = val;
                _selectedSem = null;
                _selectedCourseId = null;
                _courseDataCache.clear();
              });
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDropdown(
              "選擇學期",
              availableSems,
              _selectedSem!,
              (val) {
                setState(() {
                  _selectedSem = val;
                  _selectedCourseId = null;
                  _courseDataCache.clear();
                });
              },
              displayMap: {"1": "上學期", "2": "下學期", "3": "暑修"},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.isDark
            ? Colors.blue[900]!.withValues(alpha: 0.2)
            : Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, color: colorScheme.accentBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "輸入各項成績以預估學期總分",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.accentBlue,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "資料僅儲存於本機。配分方式可手動編輯，也可從選課系統抓取作為參考。",
                  style: TextStyle(
                    color: colorScheme.accentBlue.withValues(alpha: 0.85),
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
  }

  Widget _buildCourseListPane() {
    String key = "${_selectedYear!}-${_selectedSem!}";
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

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: courses.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.borderColor.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) => _buildCourseItem(courses[index]),
    );
  }

  Widget _buildCourseItem(CourseScore course) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedCourseId == course.id;

    return InkWell(
      onTap: () => _selectCourse(course),
      child: Container(
        color: isSelected
            ? colorScheme.accentBlue.withValues(alpha: 0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.isDark
                    ? Colors.blue[900]!.withValues(alpha: 0.3)
                    : Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  course.credits,
                  style: TextStyle(
                    color: colorScheme.accentBlue,
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
                      color: colorScheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    course.id,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.subtitleText,
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
                color: _getScoreColor(course.score),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isSelected
                  ? colorScheme.accentBlue
                  : colorScheme.subtitleText,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCourse(CourseScore course) async {
    if (_selectedCourseId == course.id) {
      return;
    }

    if (!_courseDataCache.containsKey(course.id)) {
      await _loadCourseData(course.id, course.name);
    }

    if (mounted) {
      setState(() {
        _selectedCourseId = course.id;
      });
    }
  }

  Color _getScoreColor(String score) {
    final colorScheme = Theme.of(context).colorScheme;
    double? scoreVal = double.tryParse(score);
    if (scoreVal == null) return colorScheme.subtitleText;
    if (scoreVal >= 90)
      return colorScheme.isDark ? Colors.redAccent : Colors.red[700]!;
    if (scoreVal >= 60) return colorScheme.primaryText;
    return colorScheme.isDark ? Colors.redAccent[100]! : Colors.redAccent;
  }

  Widget _buildCourseDetailPane() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_selectedCourseId == null) {
      return Center(
        child: Text(
          "請選擇左側課程以查看或編輯配分",
          style: TextStyle(color: colorScheme.subtitleText),
        ),
      );
    }

    final courseData = _courseDataCache[_selectedCourseId!];
    if (courseData == null) {
      return const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (courseData.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("尚無評分方式資料", style: TextStyle(color: colorScheme.subtitleText)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  courseData.items = [
                    ScoreItem.fromRawData('出席', 0),
                    ScoreItem.fromRawData('小考', 0),
                    ScoreItem.fromRawData('期中考', 0),
                    ScoreItem.fromRawData('期末考', 0),
                    ScoreItem.fromRawData('期中報告', 0),
                    ScoreItem.fromRawData('期末報告', 0),
                  ];
                  courseData.isCustomized = true;
                });
                _saveCourseData(_selectedCourseId!, courseData);
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text("手動建立配分"),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: ScoreTrackingDetail(
        courseData: courseData,
        onSave: () => _saveCourseData(_selectedCourseId!, courseData),
        onRefresh: () => _refreshEvaluation(_selectedCourseId!, courseData),
      ),
    );
  }

  Future<void> _refreshEvaluation(
    String courseId,
    CourseScoreData courseData,
  ) async {
    if (courseData.isCustomized) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("重新抓取配分"),
          content: const Text("重新抓取將覆蓋您手動編輯的配分，是否繼續？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("繼續"),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // 儲存舊配分（深複製）
    final oldItems = courseData.items
        .map(
          (item) => ScoreItem(
            id: item.id,
            name: item.name,
            weight: item.weight,
            score: item.score,
            children: item.children
                .map(
                  (c) => ScoreItem(
                    id: c.id,
                    name: c.name,
                    weight: c.weight,
                    score: c.score,
                  ),
                )
                .toList(),
            isExpanded: item.isExpanded,
          ),
        )
        .toList();

    final evals = await CourseEvaluationService.instance.fetchEvaluation(
      year: _selectedYear!,
      semester: _selectedSem!,
      courseId: courseId,
    );

    // 解析新配分
    List<ScoreItem> newItems = [];
    if (evals.isNotEmpty &&
        evals.first != "載入失敗" &&
        evals.first != "查無資料" &&
        evals.first != "尚無評分方式資料") {
      for (var evalStr in evals) {
        final match = RegExp(
          r'^(\d+)\.\s*(.+?)\s*：\s*(\d+(?:\.\d+)?)\s*%$',
        ).firstMatch(evalStr);
        if (match != null) {
          newItems.add(
            ScoreItem.fromRawData(
              match.group(2)!.trim(),
              double.tryParse(match.group(3)!) ?? 0.0,
            ),
          );
        }
      }
    }

    // 比對新舊配分是否需要遷移
    bool needsMigration = _checkNeedsMigration(oldItems, newItems);

    if (needsMigration && oldItems.isNotEmpty) {
      // 顯示遷移助手
      final result = await showScoreMigrationDialog(
        context: context,
        oldItems: oldItems,
        newItems: newItems,
        courseName: courseData.courseName,
      );

      if (result == null) {
        // 使用者取消，保留舊配分
        return;
      }

      // 應用遷移結果
      if (!mounted) return;
      setState(() {
        courseData.items = newItems;
        for (var mapping in result) {
          final newItemId = mapping['newItemId'] as String?;
          final score = mapping['score'] as double?;
          if (newItemId != null && score != null) {
            final newItem = courseData.items.firstWhere(
              (item) => item.id == newItemId,
              orElse: () => courseData.items.first,
            );
            newItem.score = score;
          }
        }
        courseData.isCustomized = false;
        courseData.lastUpdated = DateTime.now();
      });
    } else {
      // 不需要遷移，直接替換
      if (!mounted) return;
      setState(() {
        courseData.items = newItems;
        courseData.isCustomized = false;
        courseData.lastUpdated = DateTime.now();
      });
    }

    await _saveCourseData(courseId, courseData);
  }

  /// 檢查是否需要遷移（新舊配分有差異）
  bool _checkNeedsMigration(
    List<ScoreItem> oldItems,
    List<ScoreItem> newItems,
  ) {
    // 如果舊項目為空，不需要遷移
    if (oldItems.isEmpty) return false;

    // 如果新項目為空，不需要遷移（可能是抓取失敗）
    if (newItems.isEmpty) return false;

    // 檢查項目數量是否不同
    if (oldItems.length != newItems.length) return true;

    // 檢查項目名稱或權重是否不同
    for (int i = 0; i < oldItems.length; i++) {
      final oldItem = oldItems[i];
      // 嘗試找到名稱相同的新項目
      final matchingNew = newItems
          .where((n) => n.name == oldItem.name)
          .toList();
      if (matchingNew.isEmpty) return true;
      if ((matchingNew.first.weight - oldItem.weight).abs() > 0.01) return true;
    }

    // 檢查新項目中是否有舊配分沒有的項目
    for (var newItem in newItems) {
      final matchingOld = oldItems
          .where((o) => o.name == newItem.name)
          .toList();
      if (matchingOld.isEmpty) return true;
    }

    return false;
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged, {
    Map<String, String>? displayMap,
  }) {
    return GlassSingleSelectDropdown(
      label: label,
      items: items,
      value: value,
      onChanged: onChanged,
      displayMap: displayMap,
    );
  }
}
