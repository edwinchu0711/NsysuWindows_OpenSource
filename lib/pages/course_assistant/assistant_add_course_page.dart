import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/course_query_service.dart'; // 請確認路徑是否正確
import '../../../services/course_evaluation_service.dart';
import 'package:http/http.dart' as http; // ✅ 新增這行：用來發送網路請求
import 'package:url_launcher/url_launcher.dart'; // ✅ 新增：用於開啟外部連結
import '../../../theme/app_theme.dart';

class AssistantAddCoursePage extends StatefulWidget {
  final VoidCallback? onCourseAdded; // 新增回呼，通知父層
  final VoidCallback? onClose; // 新增回呼，由父層決定關閉行為
  final bool isSubPane; // ★★★ 新增：是否以子區塊模式顯示 ★★★

  final List<dynamic>? initialCourses; // 既有課程 (來自父層)
  final List<dynamic>? initialEvents; // 既有行程 (來自父層)

  const AssistantAddCoursePage({
    Key? key,
    this.onCourseAdded,
    this.onClose,
    this.isSubPane = false,
    this.initialCourses,
    this.initialEvents,
  }) : super(key: key);

  @override
  State<AssistantAddCoursePage> createState() => _AssistantAddCoursePageState();
}

class _AssistantAddCoursePageState extends State<AssistantAddCoursePage> {
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  final Map<String, List<String>> _evaluationCache = {};
  // 已存在助手課表中的課程 ID 集合 (用來防呆顯示已加入)
  Set<String> _existingAssistantCourseIds = {};

  final TextEditingController _mergedQueryCtrl = TextEditingController();
  Set<String> _selectedGrades = {};
  Set<String> _selectedDays = {};
  Set<String> _selectedPeriods = {};
  String? _selectedClass;
  bool _filterConflict = false; // 是否過濾衝堂
  List<dynamic>? _localAddedCourses; // 新增：用於即時追蹤本地已加入課程，解決刷新延遲問題

  // 定義統一的選項，避免手機版與電腦版不一致
  static const Map<String, String> _gradeOptions = {
    "1": "一年級",
    "2": "二年級",
    "3": "三年級",
    "4": "四年級",
    "5": "五年級",
  };

  static const Map<String, String> _dayOptions = {
    "1": "週一",
    "2": "週二",
    "3": "週三",
    "4": "週四",
    "5": "週五",
    "6": "週六",
    "7": "週日",
  };

  static const Map<String, String> _periodOptions = {
    "A": "A (07:00)",
    "1": "1 (08:10)",
    "2": "2 (09:10)",
    "3": "3 (10:10)",
    "4": "4 (11:10)",
    "5": "5 (13:10)",
    "B": "B (12:10)",
    "6": "6 (14:10)",
    "7": "7 (15:10)",
    "8": "8 (16:10)",
    "9": "9 (17:10)",
    "C": "C (18:20)",
    "D": "D (19:15)",
    "E": "E (20:10)",
    "F": "F (21:05)",
  };

  @override
  void initState() {
    super.initState();
    // Use initialCourses passed from parent if available
    if (widget.initialCourses != null && widget.initialCourses!.isNotEmpty) {
      _existingAssistantCourseIds = widget.initialCourses!
          .map((c) => c['code'].toString())
          .toSet();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingAssistantCourses().then((_) => _performSearch());
    });
  }

  @override
  void didUpdateWidget(covariant AssistantAddCoursePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCourses != oldWidget.initialCourses) {
      _loadExistingAssistantCourses();
    }
  }

  @override
  void dispose() {
    _mergedQueryCtrl.dispose();
    super.dispose();
  }

  // 讀取已經加到助手的課程，用來在畫面上顯示 "已加入"
  Future<void> _loadExistingAssistantCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('assistant_courses');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _existingAssistantCourseIds = decoded
              .map((v) => v['code'].toString())
              .toSet();
        });
      }
    } catch (e) {
      print("讀取既有助手課表失敗: $e");
    }
  }

  // 將 CourseJsonData 轉換為 Course 模型並存入快取
  // 將 CourseJsonData 轉換為 Course 模型並存入快取
  Future<void> _addCourseToAssistant(CourseJsonData courseData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> currentList = [];
      String? jsonStr = prefs.getString('assistant_courses');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        currentList = jsonDecode(jsonStr);
      }

      if (currentList.any((c) => c['code'] == courseData.id)) {
        return;
      }

      // ✅ 修改這裡：將時間字串精準拆分 (支援 "234" 或 "2,3,4" 等格式)
      List<Map<String, dynamic>> parsedTimes = [];
      for (int i = 0; i < courseData.classTime.length; i++) {
        String dayPeriods = courseData.classTime[i];
        if (dayPeriods.isNotEmpty) {
          // 去除逗號與空白，確保剩下純節次字元 (例如 "2, 3, 4" 或 "234" 都變成 "234")
          String cleaned = dayPeriods.replaceAll(',', '').replaceAll(' ', '');

          // 逐字元拆開 (中山的節次皆為單一字元: 1~9, A~F)
          for (int j = 0; j < cleaned.length; j++) {
            parsedTimes.add({'day': i + 1, 'period': cleaned[j]});
          }
        }
      }

      // 建立存檔用 Map
      Map<String, dynamic> newCourse = {
        'name': courseData.name.split('\n')[0],
        'code': courseData.id,
        'professor': courseData.teacher,
        'location': courseData.room,
        'timeString': "",
        'credits': courseData.credit,
        'required': "",
        'detailUrl': "",
        'parsedTimes': parsedTimes,
        'english': courseData.english,
        'restrict': courseData.restrict,
        'select': courseData.select,
        'selected': courseData.selected,
        'remaining': courseData.remaining,
        'tags': courseData.tags,
        'department': courseData.department,
        'description': courseData.description,
      };

      currentList.add(newCourse);
      await prefs.setString('assistant_courses', jsonEncode(currentList));

      setState(() {
        _existingAssistantCourseIds.add(courseData.id);
        _localAddedCourses = currentList; // 更新本地緩存資料，讓下次搜尋即時生效
      });

      // ★★★ 新增：呼叫回呼，讓旁邊的課表自動更新 ★★★
      widget.onCourseAdded?.call();

      // ★★★ 新增：如果開啟了過濾衝堂，加入課程後自動重新搜尋以隱藏新衝突課程 ★★★
      if (_filterConflict) {
        _performSearch();
      }
    } catch (e) {
      // 靜默處理
    }
  }

  @override
  Widget build(BuildContext context) {
    final semStr = CourseQueryService.instance.currentSemester;
    String semDisplay = "";
    if (semStr.length == 4) {
      final syear = semStr.substring(0, 3); // 前三碼 (114)
      final sem = semStr.substring(3, 4); // 最後一碼 (2)
      semDisplay = "$syear-${sem}";
    }
    final content = Column(
      children: [
        if (!widget.isSubPane)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.cardBackground,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton.icon(
                onPressed: _showSearchSheet,
                icon: const Icon(Icons.search),
                label: const Text("開啟搜尋面板"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryCardBackground,
                  foregroundColor: Theme.of(context).colorScheme.accentBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          )
        else
          // 桌面版內嵌搜尋表單
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.cardBackground,
            child: _buildDesktopSearchForm(),
          ),
        const Divider(height: 1),
        Expanded(child: _buildSearchResults()),
      ],
    );

    if (widget.isSubPane) {
      return Container(
        color: Theme.of(context).colorScheme.pageBackground,
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$semDisplay 新增課程"),
        backgroundColor: Theme.of(context).colorScheme.headerBackground,
        foregroundColor: Theme.of(context).colorScheme.primaryText,
        elevation: 0.5,
        // ★★★ 新增：如果由分割畫面呼叫，顯示關閉按鈕 ★★★
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              )
            : null,
      ),
      body: content,
    );
  }

  Widget _buildSearchResults() {
    if (_isQueryLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              "搜尋中 (可能需要下載課程資料)...",
              style: TextStyle(
                color: Theme.of(context).colorScheme.subtitleText,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          "點擊上方按鈕搜尋想加入的課程",
          style: TextStyle(color: Theme.of(context).colorScheme.subtitleText),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text("找不到符合條件的課程"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final course = _searchResults[index];
        bool isAdded = _existingAssistantCourseIds.contains(course.id);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.borderColor,
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: Theme.of(context).colorScheme,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Row(
                children: [
                  Expanded(child: _HoverableCourseName(course: course)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 減少間距
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildMiniInfoChip(Icons.person_outline, course.teacher),
                      _buildMiniInfoChip(
                        Icons.grade_outlined,
                        "${course.credit} 學分",
                      ),
                      _buildMiniInfoChip(
                        Icons.class_outlined,
                        "${course.grade}年${course.className}",
                      ),
                      _buildMiniInfoChip(
                        Icons.category_outlined,
                        course.department,
                      ),
                      _buildMiniInfoChip(
                        Icons.access_time,
                        _formatClassTime(course.classTime),
                      ),
                      if (course.english)
                        _buildMiniInfoChip(Icons.language, "英語授課"),
                    ],
                  ),
                ],
              ),
              trailing: isAdded
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.isDark
                          ? Colors.greenAccent[400]
                          : Colors.green[600],
                      size: 32,
                    )
                  : MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton(
                        onPressed: () => _addCourseToAssistant(course),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.isDark
                              ? Colors.green[800]
                              : Colors.green[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 32),
                        ),
                        child: const Text("加入排課"),
                      ),
                    ),
              children: [
                const Divider(height: 1, thickness: 1),
                Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondaryCardBackground.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "評分方式",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.subtitleText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 使用 FutureBuilder 動態載入
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FutureBuilder<List<String>>(
                          future: _getCourseEvaluation(course.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError ||
                                !snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return Text(
                                "尚無詳細評分資料",
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.subtitleText,
                                  fontSize: 13,
                                ),
                              );
                            }
                            // 渲染抓取到的評分清單
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: snapshot.data!
                                  .map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.accentBlue,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              e,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primaryText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 12),

                      // 課程狀態與標籤
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "課程資訊",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.subtitleText,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow("名額", "${course.restrict}"),
                                _buildInfoRow(
                                  "餘額",
                                  "${course.remaining}",
                                  valueColor: course.remaining > 0
                                      ? (Theme.of(context).colorScheme.isDark
                                            ? Colors.green[200]
                                            : Colors.green[700])
                                      : Colors.redAccent,
                                ),
                                _buildInfoRow(
                                  "選上機率",
                                  _calculateProbability(course),
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "對應學程",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.subtitleText,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (course.tags.isEmpty)
                                  Text(
                                    "無相關學程",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.subtitleText,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: course.tags
                                        .map(
                                          (t) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondaryCardBackground,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.borderColor,
                                              ),
                                            ),
                                            child: Text(
                                              t,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.accentBlue,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (course.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "備註",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.subtitleText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            course.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primaryText,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "外部連結與評價",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.subtitleText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildActionButton(
                            icon: Icons.person_search,
                            label: "教授評價",
                            color: Colors.orangeAccent,
                            onTap: () =>
                                _launchEvaluationSearch(course.teacher),
                          ),
                          _buildActionButton(
                            icon: Icons.forum_outlined,
                            label: "課程評價",
                            color: Colors.purpleAccent,
                            onTap: () => _launchEvaluationSearch(
                              course.name.split('\n')[0],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // 使用 StatefulBuilder 確保在 BottomSheet 內部調用 setState 時，畫面會即時更新
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "課程查詢條件",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              "關鍵字搜尋 (課名、教師、系所、學程)",
                              _mergedQueryCtrl,
                              hint: "可用空白區隔多個關鍵字，如：資工 周",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              const Text(
                                "過濾衝堂",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Switch(
                                value: _filterConflict,
                                onChanged: (v) {
                                  // 同步更新父層與 Sheet 內部狀態
                                  setState(() => _filterConflict = v);
                                  setSheetState(() {});
                                },
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.accentBlue,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMultiSelectDropdown(
                              label: "年級 (D2)",
                              values: _selectedGrades,
                              options: _gradeOptions,
                              onChanged: (newSet) {
                                setState(() => _selectedGrades = newSet);
                                setSheetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: "班級 (CLASS)",
                              value: _selectedClass,
                              items: const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text("全部"),
                                ),
                                DropdownMenuItem(
                                  value: "0",
                                  child: Text("不分班"),
                                ),
                                DropdownMenuItem(value: "1", child: Text("甲班")),
                                DropdownMenuItem(value: "2", child: Text("乙班")),
                                DropdownMenuItem(
                                  value: "5",
                                  child: Text("全英班"),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedClass = v);
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "上課時間",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.subtitleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMultiSelectDropdown(
                              label: "星期",
                              values: _selectedDays,
                              options: _dayOptions,
                              onChanged: (newSet) {
                                setState(() => _selectedDays = newSet);
                                setSheetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMultiSelectDropdown(
                              label: "節次",
                              values: _selectedPeriods,
                              options: _periodOptions,
                              onChanged: (newSet) {
                                setState(() => _selectedPeriods = newSet);
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _performSearch();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.accentBlue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              "開始查詢",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: _clearSearchFields,
                          child: const Text(
                            "重設條件",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ✅ 核心變更：加入了 await CourseQueryService.instance.getCourses()
  Future<void> _performSearch() async {
    setState(() {
      _isQueryLoading = true;
      _hasSearched = true;
    });

    try {
      // 1. 確保資料已經透過 API 下載完畢 (初次點擊時會下載 all.json，之後就有 cache)
      await CourseQueryService.instance.getCourses();

      // 2. 處理班級下拉選單對應的中文字 (因為 API JSON 的 class 欄位是中文字)
      String? classText;
      if (_selectedClass == "0") classText = "不分班";
      if (_selectedClass == "1") classText = "甲班";
      if (_selectedClass == "2") classText = "乙班";
      if (_selectedClass == "5") classText = "全英班";

      // 3. 呼叫 Search 邏輯
      final results = CourseQueryService.instance.search(
        query: _mergedQueryCtrl.text.trim(),
        grades: _selectedGrades.toList(),
        classType: classText,
        days: _selectedDays.toList(),
        periods: _selectedPeriods.toList(),
        filterConflict: _filterConflict,
        existingCourses: _localAddedCourses ?? widget.initialCourses,
        existingEvents: widget.initialEvents,
      );

      setState(() {
        _searchResults = results;
        _isQueryLoading = false;
      });
    } catch (e) {
      setState(() => _isQueryLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("搜尋失敗或資料載入錯誤: $e")));
      }
    }
  }

  Widget _buildDesktopSearchForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                "合併關鍵字搜尋 (名稱、教師、系所、學程)",
                _mergedQueryCtrl,
                hint: "可用空白區隔多個關鍵字，如：資工 物件",
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "過濾衝堂",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                SizedBox(
                  height: 32,
                  child: Switch(
                    value: _filterConflict,
                    activeColor: Theme.of(context).colorScheme.accentBlue,
                    onChanged: (v) {
                      setState(() => _filterConflict = v);
                      _performSearch();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildMultiSelectDropdown(
                label: "年級",
                values: _selectedGrades,
                options: _gradeOptions,
                onChanged: (newSet) => setState(() => _selectedGrades = newSet),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildMultiSelectDropdown(
                label: "星期",
                values: _selectedDays,
                options: _dayOptions,
                onChanged: (newSet) => setState(() => _selectedDays = newSet),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildMultiSelectDropdown(
                label: "節次",
                values: _selectedPeriods,
                options: _periodOptions,
                onChanged: (newSet) =>
                    setState(() => _selectedPeriods = newSet),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.only(top: 15),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton(
                    onPressed: _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 38),
                    ),
                    child: const Icon(Icons.search, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _clearSearchFields() {
    _mergedQueryCtrl.clear();
    setState(() {
      _selectedGrades = {};
      _selectedClass = null;
      _selectedDays = {};
      _selectedPeriods = {};
    });
    Navigator.pop(context);
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        const SizedBox(height: 2),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.borderColor,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.secondaryCardBackground,
            isDense: true,
          ),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectDropdown({
    required String label,
    required Set<String> values,
    required Map<String, String> options,
    required Function(Set<String>) onChanged,
  }) {
    return _GlassMultiSelectDropdown(
      label: label,
      values: values,
      options: options,
      onChanged: onChanged,
    );
  }

  // ✅ 新增：輔助元件顯示詳細資訊列
  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.subtitleText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Theme.of(context).colorScheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateProbability(CourseJsonData course) {
    if (course.remaining <= 0) return "0% (已滿)";
    double prob = course.remaining / course.select;
    if (course.select <= 0 || prob > 1) return "100%"; // 無人選
    return "${(prob * 100).toStringAsFixed(1)}%";
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.subtitleText.withOpacity(0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.borderColor,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.secondaryCardBackground,
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  // ✅ 核心方法：抓取評分方式
  Future<List<String>> _getCourseEvaluation(String courseId) async {
    if (_evaluationCache.containsKey(courseId)) {
      return _evaluationCache[courseId]!;
    }
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return ["無法取得學期資訊"];
    final syear = semStr.substring(0, 3);
    final sem = semStr.substring(3, 4);

    final evals = await CourseEvaluationService.instance.fetchEvaluation(
      year: syear,
      semester: sem,
      courseId: courseId,
    );
    _evaluationCache[courseId] = evals;
    return evals;
  }

  String _formatClassTime(List<String> times) {
    if (times.length < 7) return times.join(', ');
    final dayNames = ["一", "二", "三", "四", "五", "六", "日"];
    List<String> formattedParts = [];
    for (int i = 0; i < 7; i++) {
      String p = times[i].trim();
      if (p.isNotEmpty) {
        // 如果節數包含多位，如 456 -> 4,5,6
        String periods = p.split('').join(',');
        formattedParts.add("${dayNames[i]}$periods");
      }
    }
    return formattedParts.isEmpty ? "未排課" : formattedParts.join(' ');
  }

  void _launchEvaluationSearch(String keyword) async {
    if (keyword.isEmpty) return;
    final query = '中山大學 "$keyword" 評價';
    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Theme.of(context).colorScheme.subtitleText,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ 新增：支援 Hover 效果與點擊開網址的課程名稱組件
class _HoverableCourseName extends StatefulWidget {
  final CourseJsonData course;
  const _HoverableCourseName({Key? key, required this.course})
    : super(key: key);

  @override
  State<_HoverableCourseName> createState() => _HoverableCourseNameState();
}

class _HoverableCourseNameState extends State<_HoverableCourseName> {
  bool _isHovering = false;

  Future<void> _launchCourseOutline() async {
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return;

    final syear = semStr.substring(0, 3);
    final sem = semStr.substring(3, 4);
    final courseId = widget.course.id;
    final url = Uri.parse(
      'https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: _launchCourseOutline,
            child: Text(
              widget.course.name.split('\n')[0],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _isHovering
                    ? Theme.of(context).colorScheme.accentBlue
                    : Theme.of(context).colorScheme.primaryText,
                decoration: _isHovering
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassMultiSelectDropdown extends StatefulWidget {
  final String label;
  final Set<String> values;
  final Map<String, String> options;
  final Function(Set<String>) onChanged;

  const _GlassMultiSelectDropdown({
    Key? key,
    required this.label,
    required this.values,
    required this.options,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_GlassMultiSelectDropdown> createState() =>
      _GlassMultiSelectDropdownState();
}

class _GlassMultiSelectDropdownState extends State<_GlassMultiSelectDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late Set<String> _tempSet;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown(true);
    } else {
      _tempSet = Set.from(widget.values);
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isOpen = true);
    }
  }

  void _closeDropdown([bool save = false]) {
    if (save) {
      widget.onChanged(Set.from(_tempSet));
    }
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
                onTap: () => _closeDropdown(true),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(
                  builder: (context, setInnerState) {
                    return TweenAnimationBuilder<double>(
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
                        width: size.width < 180 ? 180 : size.width,
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: colorScheme.headerBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.borderColor.withValues(
                              alpha: 0.5,
                            ),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: widget.options.entries.map((e) {
                                    final isSelected = _tempSet.contains(e.key);
                                    return _HoverableMultiSelectOption(
                                      label: e.value,
                                      isSelected: isSelected,
                                      colorScheme: colorScheme,
                                      onTap: () {
                                        setInnerState(() {
                                          if (isSelected) {
                                            _tempSet.remove(e.key);
                                          } else {
                                            _tempSet.add(e.key);
                                          }
                                          // Save immediately upon ticking for real-time feel
                                          widget.onChanged(Set.from(_tempSet));
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.values.isEmpty
                          ? "全部"
                          : widget.values
                                .map((e) {
                                  final label = widget.options[e] ?? e;
                                  // 如果標籤包含括號時間，在欄位顯示時僅保留前半部 (例如 "A (07:00)" -> "A")
                                  return label.contains(' (')
                                      ? label.split(' (')[0]
                                      : label;
                                })
                                .join(', '),
                      style: TextStyle(
                        fontSize: 13,
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
                    size: 18,
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

class _HoverableMultiSelectOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _HoverableMultiSelectOption({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  }) : super(key: key);

  @override
  State<_HoverableMultiSelectOption> createState() =>
      _HoverableMultiSelectOptionState();
}

class _HoverableMultiSelectOptionState
    extends State<_HoverableMultiSelectOption> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.accentBlue.withValues(alpha: 0.1)
                : (_isHovering
                      ? cs.accentBlue.withValues(alpha: 0.05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? cs.accentBlue.withValues(alpha: 0.3)
                  : (_isHovering
                        ? cs.accentBlue.withValues(alpha: 0.2)
                        : Colors.transparent),
            ),
            boxShadow: _isHovering && !isSelected
                ? [
                    BoxShadow(
                      color: cs.accentBlue.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: isSelected
                    ? cs.accentBlue
                    : (_isHovering
                          ? cs.accentBlue.withValues(alpha: 0.6)
                          : cs.subtitleText),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected || _isHovering
                        ? cs.primaryText
                        : cs.subtitleText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
