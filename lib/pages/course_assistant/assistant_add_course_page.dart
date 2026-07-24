import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/course_query_service.dart';
import '../../../services/course_evaluation_service.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import 'widgets/glass_multi_select_dropdown.dart';
import 'widgets/course_search_result_card.dart';
import 'course_assistant_page.dart';

class AssistantAddCoursePage extends StatefulWidget {
  final VoidCallback? onCourseAdded; // 新增回呼，通知父層
  final VoidCallback? onClose; // 新增回呼，由父層決定關閉行為
  final bool isSubPane; // ★★★ 新增：是否以子區塊模式顯示 ★★★

  final List<dynamic>? initialCourses; // 既有課程 (來自父層)
  final List<dynamic>? initialEvents; // 既有行程 (來自父層)
  final CourseSlotFilterNotifier? slotFilterNotifier; // 槽位篩選器

  const AssistantAddCoursePage({
    super.key,
    this.onCourseAdded,
    this.onClose,
    this.isSubPane = false,
    this.initialCourses,
    this.initialEvents,
    this.slotFilterNotifier,
  });

  @override
  State<AssistantAddCoursePage> createState() => _AssistantAddCoursePageState();
}

class _AssistantAddCoursePageState extends State<AssistantAddCoursePage> {
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  final Map<String, Future<List<String>>> _evaluationFutureCache = {};

  // 已存在助手課表中的課程 ID 集合 (用來防呆顯示已加入)
  Set<String> _existingAssistantCourseIds = {};

  final TextEditingController _mergedQueryCtrl = TextEditingController();
  Set<String> _selectedGrades = {};
  Set<String> _selectedDays = {};
  Set<String> _selectedPeriods = {};
  /// 來自課表格子點擊的 (day-period) 配對篩選，與下拉的星期/節次互相獨立。
  Set<String> _selectedSlots = {};
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

  Timer? _debounce;

  void _onSlotFilterChanged() {
    final notifier = widget.slotFilterNotifier;
    if (notifier == null) return;
    setState(() {
      // 格子點擊以配對為單位，獨立於下拉的星期/節次篩選，不混入 _selectedDays/_selectedPeriods
      _selectedSlots = Set.from(notifier.slots);
    });
    _performSearch();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Use initialCourses passed from parent if available
    if (widget.initialCourses != null && widget.initialCourses!.isNotEmpty) {
      _existingAssistantCourseIds = widget.initialCourses!
          .map((c) => c['code'].toString())
          .toSet();
    }
    _mergedQueryCtrl.addListener(_onSearchChanged);
    widget.slotFilterNotifier?.addListener(_onSlotFilterChanged);
    if (widget.slotFilterNotifier != null) {
      _selectedSlots = Set.from(widget.slotFilterNotifier!.slots);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingAssistantCourses();
      if (_selectedSlots.isNotEmpty ||
          _selectedDays.isNotEmpty ||
          _selectedPeriods.isNotEmpty) {
        _performSearch();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AssistantAddCoursePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCourses != oldWidget.initialCourses) {
      _loadExistingAssistantCourses();
    }
    if (widget.slotFilterNotifier != oldWidget.slotFilterNotifier) {
      oldWidget.slotFilterNotifier?.removeListener(_onSlotFilterChanged);
      widget.slotFilterNotifier?.addListener(_onSlotFilterChanged);
      if (widget.slotFilterNotifier != null) {
        setState(() {
          _selectedSlots = Set.from(widget.slotFilterNotifier!.slots);
        });
        _performSearch();
      }
    }
  }

  @override
  void dispose() {
    widget.slotFilterNotifier?.removeListener(_onSlotFilterChanged);
    _mergedQueryCtrl.removeListener(_onSearchChanged);
    _debounce?.cancel();
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
      debugPrint("讀取既有助手課表失敗: $e");
    }
  }

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

      // 將時間字串精準拆分 (支援 "234" 或 "2,3,4" 等格式)
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
        'required': courseData.compulsory ? "必修" : "選修",
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

      // 呼叫回呼，讓旁邊的課表自動更新
      widget.onCourseAdded?.call();

      // 如果開啟了過濾衝堂，加入課程後自動重新搜尋以隱藏新衝突課程
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
      semDisplay = "$syear-$sem";
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
    final colorScheme = Theme.of(context).colorScheme;

    if (_isQueryLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              "搜尋中 (可能需要下載課程資料)...",
              style: TextStyle(color: colorScheme.subtitleText),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          widget.isSubPane ? "輸入關鍵字或選擇條件後，點擊搜尋按鈕" : "點擊上方按鈕搜尋想加入的課程",
          style: TextStyle(color: colorScheme.subtitleText),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text("找不到符合條件的課程"));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final course = _searchResults[index];
              bool isAdded = _existingAssistantCourseIds.contains(course.id);

              return CourseSearchResultCard(
                course: course,
                isAdded: isAdded,
                onAddPressed: () => _addCourseToAssistant(course),
                getCourseEvaluation: _getCourseEvaluation,
                launchEvaluationSearch: _launchEvaluationSearch,
              );
            },
          ),
        ),
      ],
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
                                  _performSearch();
                                },
                                activeThumbColor: Theme.of(
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
                                _performSearch();
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
                                _performSearch();
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
                                _performSearch();
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
                                _performSearch();
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
        slots: _selectedSlots.toList(),
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                "合併關鍵字搜尋 (名稱、教師、系所、學程、必修/選修)",
                _mergedQueryCtrl,
                hint: "可用空白區隔多個關鍵字，如：資工 必修 物件",
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
                    activeThumbColor: Theme.of(context).colorScheme.accentBlue,
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
                onChanged: (newSet) {
                  setState(() => _selectedGrades = newSet);
                  _performSearch();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildMultiSelectDropdown(
                label: "星期",
                values: _selectedDays,
                options: _dayOptions,
                onChanged: (newSet) {
                  setState(() => _selectedDays = newSet);
                  _performSearch();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildMultiSelectDropdown(
                label: "節次",
                values: _selectedPeriods,
                options: _periodOptions,
                onChanged: (newSet) {
                  setState(() => _selectedPeriods = newSet);
                  _performSearch();
                },
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
        // 顯示目前從課表點選的時段配對篩選（與下拉的星期/節次獨立）。
        if (_selectedSlots.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 14,
                  color: cs.accentBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  "已點選時段：",
                  style: TextStyle(fontSize: 12, color: cs.subtitleText),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _selectedSlots.map(_slotDescription).join("、"),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => widget.slotFilterNotifier?.clear(),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: cs.subtitleText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 把 "day-period" 配對（例如 "4-2"）轉成可讀文字，例如 "週四第2節"。
  String _slotDescription(String slot) {
    final dash = slot.indexOf('-');
    if (dash <= 0 || dash == slot.length - 1) return slot;
    final dayKey = slot.substring(0, dash);
    final periodKey = slot.substring(dash + 1);
    final dayLabel = _dayOptions[dayKey] ?? dayKey;
    return "$dayLabel第$periodKey節";
  }

  void _clearSearchFields() {
    _mergedQueryCtrl.clear();
    setState(() {
      _selectedGrades = {};
      _selectedClass = null;
      _selectedDays = {};
      _selectedPeriods = {};
      _selectedSlots = {};
    });
    // 同步清掉課表格子的配對選取狀態
    widget.slotFilterNotifier?.clear();
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
          initialValue: value,
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
    return GlassMultiSelectDropdown(
      label: label,
      values: values,
      options: options,
      onChanged: onChanged,
    );
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
              ).colorScheme.subtitleText.withValues(alpha: 0.5),
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

  Future<List<String>> _getCourseEvaluation(String courseId) {
    if (_evaluationFutureCache.containsKey(courseId)) {
      return _evaluationFutureCache[courseId]!;
    }
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return Future.value(["無法取得學期資訊"]);
    final syear = semStr.substring(0, 3);
    final sem = semStr.substring(3, 4);

    final future = CourseEvaluationService.instance.fetchEvaluation(
      year: syear,
      semester: sem,
      courseId: courseId,
    );
    _evaluationFutureCache[courseId] = future;
    return future;
  }

  bool _compareCourseNames(String dbName, String jsonName) {
    String clean(String name) {
      String cleaned = name
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'（[^）]*）'), '');
      return cleaned.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    }

    return clean(dbName) == clean(jsonName);
  }

  bool _compareTeacherNames(String dbTeacher, String jsonProfessor) {
    if (dbTeacher.isEmpty || jsonProfessor.isEmpty) return false;
    final t = dbTeacher.replaceAll(RegExp(r'\s+'), '');
    final p = jsonProfessor.replaceAll(RegExp(r'\s+'), '');

    if (t.length < 2 || p.length < 2) {
      return t.contains(p) || p.contains(t);
    }

    for (int i = 0; i <= t.length - 2; i++) {
      final sub = t.substring(i, i + 2);
      if (p.contains(sub)) {
        return true;
      }
    }
    return false;
  }

  void _launchEvaluationSearch(String keyword) async {
    if (keyword.isEmpty) return;
    final cleanKeyword = keyword
        .replaceAll(RegExp(r'\s*[\(（].*?[\)）]\s*$'), '')
        .trim();
    final query = '中山大學 $cleanKeyword 評價';
    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
