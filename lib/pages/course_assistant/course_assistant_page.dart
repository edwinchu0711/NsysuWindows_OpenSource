import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_model.dart';
import '../../models/custom_event_model.dart';
import 'assistant_import_page.dart';
import 'assistant_add_course_page.dart';
import 'assistant_export_page.dart';
import 'widgets/assistant_left_pane.dart';
import 'widgets/assistant_add_event_pane.dart';
import 'widgets/assistant_ai_pane.dart';
import '../../services/ai/ai_service.dart';
import '../../models/ai_config_model.dart';
import '../../theme/app_theme.dart';

enum AssistantAction { none, addCourse, addEvent, import, export, aiAssistant }

class CourseAssistantPage extends StatefulWidget {
  const CourseAssistantPage({Key? key}) : super(key: key);

  @override
  State<CourseAssistantPage> createState() => _CourseAssistantPageState();
}

class _CourseAssistantPageState extends State<CourseAssistantPage>
    with SingleTickerProviderStateMixin {
  List<Course> _assistantCourses = [];
  List<CustomEvent> _customEvents = []; // ✅ 新增：存放自訂行程的列表
  bool _isLoading = false;
  AssistantAction _currentAction =
      AssistantAction.addCourse; // ★★★ 預設改為加課模式 ★★★

  // ✅ 新增：用於左側顯示詳細資訊的狀態
  Course? _selectedCourseForDetail;
  CustomEvent? _selectedEventForDetail;

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

  AiService? _aiService;
  List<AiConfig> _aiConfigs = [];
  String? _selectedAiConfigId;
  bool _hasEmbeddingApiKey = false;

  late final AnimationController _navAnimController;
  late final Animation<double> _navCurve;
  int _prevActionIndex = 0;
  final Set<AssistantAction> _builtActions = {AssistantAction.addCourse};

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _navCurve = CurvedAnimation(
      parent: _navAnimController,
      curve: Curves.easeInOutCubic,
    );
    _navAnimController.value = 1.0; // start at initial position
    // Defer heavy data loading until after the first frame to avoid jank during page transition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAllData(silent: true);
    });
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    _aiService?.clearHistory();
    super.dispose();
  }

  void _onAiConfigChanged(AiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_ai_config_id', config.id);
    setState(() {
      _selectedAiConfigId = config.id;

      if (_aiService != null) {
        final oldHistory = _aiService!.history;
        _aiService = AiService(config: config);
        _aiService!.history.addAll(oldHistory);
      } else {
        _aiService = AiService(config: config);
      }
    });
  }

  // ✅ 統一載入課程與自訂行程
  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // 讀取課程
      String? courseJson = prefs.getString('assistant_courses');
      if (courseJson != null && courseJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(courseJson);
        _assistantCourses = decoded
            .map((v) => Course.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      } else {
        _assistantCourses = [];
      }

      // 讀取自訂行程
      String? eventJson = prefs.getString('custom_events');
      if (eventJson != null && eventJson.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(eventJson);
        _customEvents = decoded
            .map((v) => CustomEvent.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      } else {
        _customEvents = [];
      }

      // 讀取 AI 設定
      final configJson = prefs.getString('ai_configs') ?? '[]';
      _aiConfigs = AiConfig.decode(configJson);
      _selectedAiConfigId = prefs.getString('selected_ai_config_id');

      // 檢查 Embedding API Key 是否已設定
      final embeddingJson = prefs.getString('embedding_config');
      if (embeddingJson != null && embeddingJson.isNotEmpty) {
        try {
          final embeddingConfig = AiConfig.fromJson(jsonDecode(embeddingJson));
          _hasEmbeddingApiKey = embeddingConfig.apiKey.isNotEmpty;
        } catch (_) {
          _hasEmbeddingApiKey = false;
        }
      } else {
        // 若無獨立 embedding 設定，嘗試使用主 AI 設定的 API Key
        _hasEmbeddingApiKey = _aiConfigs.isNotEmpty && _aiConfigs.first.apiKey.isNotEmpty;
      }

      if (_aiConfigs.isNotEmpty) {
        AiConfig? target;
        if (_selectedAiConfigId != null) {
          target = _aiConfigs.firstWhere(
            (c) => c.id == _selectedAiConfigId,
            orElse: () => _aiConfigs.first,
          );
        } else {
          target = _aiConfigs.first;
        }

        if (_aiService == null || _aiService!.config.id != target.id) {
          if (_aiService != null) {
            final oldHistory = _aiService!.history;
            _aiService = AiService(config: target);
            _aiService!.history.addAll(oldHistory);
          } else {
            _aiService = AiService(config: target);
          }
        }

        _selectedAiConfigId = target.id;
      }
    } catch (e) {
      print("讀取資料失敗: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeCourseFromAssistant(Course course) async {
    setState(() {
      _assistantCourses = _assistantCourses.where((c) => c.code != course.code).toList();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'assistant_courses',
      jsonEncode(_assistantCourses.map((c) => c.toJson()).toList()),
    );
    if (_selectedCourseForDetail?.code == course.code) {
      setState(() => _selectedCourseForDetail = null);
    }
  }

  // ✅ 新增：移除自訂行程
  Future<void> _removeCustomEvent(String eventId) async {
    setState(() {
      _customEvents = _customEvents.where((e) => e.id != eventId).toList();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_events',
      jsonEncode(_customEvents.map((e) => e.toJson()).toList()),
    );
    if (_selectedEventForDetail?.id == eventId) {
      setState(() => _selectedEventForDetail = null);
    }
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('assistant_courses');
    await prefs.remove('custom_events');
    _loadAllData();
  }

  String _getTotalCredits() {
    double total = 0.0;
    for (var c in _assistantCourses) {
      double? cred = double.tryParse(c.credits);
      if (cred != null) total += cred;
    }
    return total.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("確認清除"),
        content: const Text("確定要清空選課助手裡的所有課程與自訂行程嗎？(不影響正式課表)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("確定清除"),
          ),
        ],
      ),
    );
  }

  void _showManageCoursesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "管理已加入課程與行程",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: (_assistantCourses.isEmpty && _customEvents.isEmpty)
                        ? const Center(
                            child: Text(
                              "目前沒有任何模擬課程或行程",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView(
                            children: [
                              if (_assistantCourses.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    "正規課程",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ..._assistantCourses
                                    .map(
                                      (c) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          c.name.split('\n')[0],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "${c.code} · ${c.professor}\n${_formatCourseTimeWithRange(c).replaceAll('\n', ' ')}",
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            await _removeCourseFromAssistant(c);
                                            setModalState(() {});
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ],
                              if (_customEvents.isNotEmpty) ...[
                                const Divider(),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    "其他行程",
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ..._customEvents
                                    .map(
                                      (e) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          e.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "星期${_fullWeekDays[e.day - 1]} (${e.periods.join(', ')}節)\n${e.details}",
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            await _removeCustomEvent(e.id);
                                            setModalState(() {});
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isWideScreen = MediaQuery.of(context).size.width >= 1000;

    Widget timetableContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isWideScreen)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 16,
                      ),
                      color: colorScheme.secondaryCardBackground,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: colorScheme.accentBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    " ${_assistantCourses.length} 門課程 / ${_getTotalCredits()} 學分",
                                    style: TextStyle(
                                      color: colorScheme.primaryText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showManageCoursesSheet,
                            icon: const Icon(Icons.list_alt, size: 18),
                            label: const Text("管理清單"),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildTimeTable(),
                ],
              ),
            ),
          );

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: colorScheme.pageBackground,
        appBar: null,
        body: Column(
          children: [
            _buildDesktopHeader(),
            Expanded(
              child: Row(
                children: [
                  // 左側：管理清單 / 詳細資訊 (Flex 2)
                  Expanded(
                    flex: 200,
                    child: AssistantLeftPane(
                      assistantCourses: _assistantCourses,
                      customEvents: _customEvents,
                      fullWeekDays: _fullWeekDays,
                      totalCredits: _getTotalCredits(),
                      onRemoveCourse: _removeCourseFromAssistant,
                      onRemoveEvent: _removeCustomEvent,
                      onClearAll: _showClearConfirmDialog,
                      onFormatTime: (Course c) =>
                          _formatCourseTimeWithRange(c).replaceAll('\n', ' '),
                      selectedCourse: _selectedCourseForDetail,
                      selectedEvent: _selectedEventForDetail,
                      onClearSelection: () => setState(() {
                        _selectedCourseForDetail = null;
                        _selectedEventForDetail = null;
                      }),
                    ),
                  ),
                  // 分隔線：左 ↔ 中
                  Container(width: 1, color: colorScheme.borderColor),
                  // 中間：課表主體 (Flex 3.5)
                  Expanded(
                    flex: 350,
                    child: Container(
                      alignment: Alignment.topCenter,
                      child: timetableContent,
                    ),
                  ),
                  // 分隔線：中 ↔ 右
                  Container(width: 1, color: colorScheme.borderColor),
                  // 右側：動作操作區 + 頂部導覽 (Flex 4.5)
                  Expanded(
                    flex: 450,
                    child: Column(
                      children: [
                        // 頂部導覽 - Liquid Glass
                        _buildLiquidGlassNav(),
                        // 操作內容區
                        Expanded(child: _buildRightPaneContent()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: null,
      body: Column(
        children: [
          _buildDesktopHeader(),
          Expanded(child: timetableContent),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 20, top: 10, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => context.go('/home'),
                tooltip: "返回主選單",
              ),
              const SizedBox(width: 4),
              Text(
                "選課助手",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primaryText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: "功能說明",
                onPressed: _showInfoDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _navActions = [
    (AssistantAction.addCourse, Icons.add_box_rounded, "加選課程"),
    (AssistantAction.addEvent, Icons.event_note_rounded, "其他行程"),
    (AssistantAction.import, Icons.download_rounded, "匯入課表"),
    (AssistantAction.export, Icons.upload_rounded, "匯出選課"),
    (AssistantAction.aiAssistant, Icons.smart_toy_rounded, "AI 助手"),
  ];

  Widget _buildLiquidGlassNav() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final itemWidth = totalWidth / _navActions.length;

          return Stack(
            children: [
              // Outer ellipse container (background layer)
              Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.03),
                          ]
                        : [
                            Colors.white.withOpacity(0.85),
                            Colors.white.withOpacity(0.6),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.white.withOpacity(0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.8),
                      blurRadius: 0,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Row(
                      children: _navActions.map((item) {
                        final (action, icon, label) = item;
                        final isSelected = _currentAction == action;
                        return _buildGlassNavItem(action, icon, label, isSelected);
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // Animated inner ellipse (sliding indicator B) — behind icons
              AnimatedBuilder(
                animation: _navAnimController,
                builder: (context, _) {
                  final tween = Tween<double>(
                    begin: _prevActionIndex * itemWidth + 4,
                    end: _currentActionIndex * itemWidth + 4,
                  );
                  final left = tween.evaluate(_navCurve);
                  return Positioned(
                    left: left,
                    top: 4,
                    child: IgnorePointer(
                      child: Container(
                        width: itemWidth - 8,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : const Color(0xFFE3F2FD).withOpacity(0.7),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF90CAF9).withOpacity(0.5),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : const Color(0xFF90CAF9).withOpacity(0.15),
                              blurRadius: 8,
                              spreadRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Icon row (top layer — always visible)
              Positioned.fill(
                child: Row(
                  children: _navActions.map((item) {
                    final (action, icon, label) = item;
                    final isSelected = _currentAction == action;
                    return _buildGlassNavItem(action, icon, label, isSelected);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassNavItem(AssistantAction action, IconData icon, String label, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(
            icon,
            size: 20,
            color: isSelected ? colorScheme.accentBlue : colorScheme.iconColor,
          ),
          onPressed: () {
            if (_currentAction != action) {
              setState(() {
                _prevActionIndex = _currentActionIndex;
                _currentAction = action;
              });
              _navAnimController.forward(from: 0);
            }
          },
          mouseCursor: SystemMouseCursors.click,
          splashRadius: 18,
        ),
      ),
    );
  }

  int get _currentActionIndex {
    switch (_currentAction) {
      case AssistantAction.addCourse: return 0;
      case AssistantAction.addEvent: return 1;
      case AssistantAction.import: return 2;
      case AssistantAction.export: return 3;
      case AssistantAction.aiAssistant: return 4;
      case AssistantAction.none: return 0;
    }
  }

  Widget _buildRightPaneContent() {
    _builtActions.add(_currentAction);
    return IndexedStack(
      index: _currentActionIndex,
      children: [
        _buildIfVisited(AssistantAction.addCourse, AssistantAddCoursePage(
          key: const ValueKey('add_course_pane'),
          isSubPane: true,
          onCourseAdded: _loadAllData,
          initialCourses: _assistantCourses.map((c) => c.toJson()).toList(),
          initialEvents: _customEvents.map((e) => e.toJson()).toList(),
        )),
        _buildIfVisited(AssistantAction.addEvent, AssistantAddEventPane(
          key: const ValueKey('add_event_pane'),
          periods: _periods,
          fullWeekDays: _fullWeekDays,
          onSave: (title, loc, details, day, periods) async {
            if (title.trim().isEmpty || periods.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("請填寫標題並至少選擇一節課")));
              return;
            }
            final newEvent = CustomEvent(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title.trim(),
              location: loc.trim(),
              details: details.trim(),
              day: day,
              periods: periods
                ..sort(
                  (a, b) => _periods.indexOf(a).compareTo(_periods.indexOf(b)),
                ),
            );
            _customEvents.add(newEvent);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'custom_events',
              jsonEncode(_customEvents.map((e) => e.toJson()).toList()),
            );
            _loadAllData();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("行程已加入！")));
          },
        )),
        _buildIfVisited(AssistantAction.import, AssistantImportPage(
          key: const ValueKey('import_pane'),
          isSubPane: true,
          onImportComplete: _loadAllData,
        )),
        _buildIfVisited(AssistantAction.export, AssistantExportPage(
          key: const ValueKey('export_pane'),
          isSubPane: true,
          courses: _assistantCourses,
        )),
        _buildIfVisited(AssistantAction.aiAssistant, AssistantAiPane(
          key: const ValueKey('ai_assistant_pane'),
          aiService: _aiService,
          aiConfigs: _aiConfigs,
          selectedConfigId: _selectedAiConfigId,
          onConfigChanged: _onAiConfigChanged,
          onRefreshRequested: () => _loadAllData(silent: true),
          hasEmbeddingApiKey: _hasEmbeddingApiKey,
        )),
      ],
    );
  }

  Widget _buildIfVisited(AssistantAction action, Widget child) {
    return _builtActions.contains(action) ? child : const SizedBox.shrink();
  }

  Widget _buildTimeTable() {
    // 加入 colorScheme 存取
    final colorScheme = Theme.of(context).colorScheme;
    int maxDay = 5;

    // 計算課程的最大天數與節次
    for (var c in _assistantCourses) {
      for (var t in c.parsedTimes) {
        if (t.day == 6 && maxDay < 6) maxDay = 6;
        if (t.day == 7) maxDay = 7;
      }
    }
    // 計算自訂行程的最大天數與節次
    for (var e in _customEvents) {
      if (e.day == 6 && maxDay < 6) maxDay = 6;
      if (e.day == 7) maxDay = 7;
    }

    List<String> visibleWeekDays = _fullWeekDays.sublist(0, maxDay);

    bool hasPeriodA = false;
    int maxPeriodIndex = _periods.indexOf('8');

    for (var c in _assistantCourses) {
      for (var t in c.parsedTimes) {
        if (t.period == 'A') hasPeriodA = true;
        int currentIndex = _periods.indexOf(t.period);
        if (currentIndex > maxPeriodIndex) maxPeriodIndex = currentIndex;
      }
    }
    for (var e in _customEvents) {
      for (var p in e.periods) {
        if (p == 'A') hasPeriodA = true;
        int currentIndex = _periods.indexOf(p);
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

    // 建立課程 Map
    Map<String, List<Course>> courseMap = {};
    for (var c in _assistantCourses) {
      for (var t in c.parsedTimes) {
        String key = "${t.day}-${t.period}";
        if (!courseMap.containsKey(key)) courseMap[key] = [];
        courseMap[key]!.add(c);
      }
    }

    // 建立自訂行程 Map
    Map<String, List<CustomEvent>> eventMap = {};
    for (var e in _customEvents) {
      for (var p in e.periods) {
        String key = "${e.day}-$p";
        if (!eventMap.containsKey(key)) eventMap[key] = [];
        eventMap[key]!.add(e);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.borderColor, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: colorScheme.borderColor, width: 0.8),
          verticalInside: BorderSide(color: colorScheme.borderColor, width: 0.8),
        ),
        columnWidths: const {0: FixedColumnWidth(50)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: colorScheme.timetableHeader),
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
              ...visibleWeekDays.map(
                (d) => Container(
                  height: 35,
                  alignment: Alignment.center,
                  child: Text(
                    d,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.primaryText,
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
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: Container(
                    color: colorScheme.timetableSlot,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          period,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.primaryText,
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
                ...List.generate(maxDay, (dayIndex) {
                  int currentDay = dayIndex + 1;
                  List<Course> cellCourses =
                      courseMap["$currentDay-$period"] ?? [];
                  List<CustomEvent> cellEvents =
                      eventMap["$currentDay-$period"] ?? [];

                  // 情況一：完全空堂
                  if (cellCourses.isEmpty && cellEvents.isEmpty) {
                    return Container(height: 70);
                  }

                  // 情況二：這個時段「只有一堂正規課程」
                  if (cellCourses.length == 1 && cellEvents.isEmpty) {
                    final cellCourse = cellCourses.first;
                    return Container(
                      height: 70, // 保留基本高度，不被壓縮
                      padding: const EdgeInsets.all(1.0),
                      child: Material(
                        color: _getCourseColor(cellCourse.name),
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () {
                            final isWide =
                                MediaQuery.of(context).size.width > 900;
                            if (isWide) {
                              setState(() {
                                _selectedCourseForDetail = cellCourse;
                                _selectedEventForDetail = null;
                              });
                            } else {
                              _showCourseDetail(cellCourse);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: double.infinity, // 內部撐滿高度
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  keepUntilLastChinese(cellCourse.name),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _extractLocation(cellCourse.location),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
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
                  }

                  // 情況三：這個時段「只有一個自訂行程」
                  if (cellEvents.length == 1 && cellCourses.isEmpty) {
                    final cellEvent = cellEvents.first;
                    return Container(
                      height: 70, // 保留基本高度，不被壓縮
                      padding: const EdgeInsets.all(1.0),
                      child: Material(
                        color: _getCourseColor(cellEvent.title), // 套用彩色
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () {
                            final isWide =
                                MediaQuery.of(context).size.width > 900;
                            if (isWide) {
                              setState(() {
                                _selectedEventForDetail = cellEvent;
                                _selectedCourseForDetail = null;
                              });
                            } else {
                              _showCustomEventDetail(cellEvent);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: double.infinity, // 內部撐滿高度
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cellEvent.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                if (cellEvent.location.isNotEmpty)
                                  Text(
                                    cellEvent.location,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
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
                  }

                  // 情況四：同一個時段有多個項目 (衝堂：包含多堂課、多個行程、或課跟行程重疊)
                  List<Widget> cellWidgets = [];

                  // 渲染多堂正規課程
                  for (var cellCourse in cellCourses) {
                    cellWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Material(
                          color: _getCourseColor(cellCourse.name),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () {
                              final isWide =
                                  MediaQuery.of(context).size.width > 900;
                              if (isWide) {
                                setState(() {
                                  _selectedCourseForDetail = cellCourse;
                                  _selectedEventForDetail = null;
                                });
                              } else {
                                _showCourseDetail(cellCourse);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    keepUntilLastChinese(cellCourse.name),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _extractLocation(cellCourse.location),
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // 渲染多個自訂行程
                  for (var cellEvent in cellEvents) {
                    cellWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Material(
                          color: _getCourseColor(cellEvent.title),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () {
                              final isWide =
                                  MediaQuery.of(context).size.width > 900;
                              if (isWide) {
                                setState(() {
                                  _selectedEventForDetail = cellEvent;
                                  _selectedCourseForDetail = null;
                                });
                              } else {
                                _showCustomEventDetail(cellEvent);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cellEvent.title,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  if (cellEvent.location.isNotEmpty)
                                    Text(
                                      cellEvent.location,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    constraints: const BoxConstraints(
                      minHeight: 70,
                    ), // 多堂課時讓他自適應長高
                    padding: const EdgeInsets.all(1),
                    color: Colors.grey[30],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: cellWidgets,
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ],
      ), // Table
      ), // Container
    ); // Padding
  }

  void _showCourseDetail(Course course) {
    String prettyTime = _formatCourseTimeWithRange(course);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                course.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (course.english)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "英語授課",
                  style: TextStyle(
                    color: Colors.blueGrey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 10,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("課號", course.code),
                _buildDetailRow("學分", "${course.credits} (${course.required})"),
                _buildDetailRow("教授", course.professor),
                _buildDetailRow("地點", _extractLocation(course.location)),
                _buildDetailRow("時間", prettyTime.replaceAll('\n', ' ')),
                const Divider(),
                const Text(
                  "開課現況",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSmallQuotaInfo("名額", "${course.restrict}"),
                    _buildSmallQuotaInfo("餘額", "${course.remaining}"),
                    _buildSmallQuotaInfo("機率", _calculateProb(course)),
                  ],
                ),
                if (course.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "對應學程",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: course.tags
                        .map(
                          (t) => Chip(
                            label: Text(
                              t,
                              style: const TextStyle(fontSize: 10),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (course.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "備註",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.description,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeCourseFromAssistant(course);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("從助手移除"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("關閉"),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallQuotaInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _calculateProb(Course course) {
    if (course.remaining <= 0) return "0% (已滿)";
    double prob = course.remaining / course.select;
    if (course.select <= 0 || prob > 1) return "100%"; // 無人選
    return "${(prob * 100).toStringAsFixed(1)}%";
  }

  // ✅ 新增：顯示自訂行程詳細內容的 Dialog
  void _showCustomEventDetail(CustomEvent event) {
    String timeStr =
        "星期${_fullWeekDays[event.day - 1]} (${event.periods.join(', ')}節)";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.event_note, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 10,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("時間", timeStr),
                if (event.details.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text(
                    "詳細內容",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.details,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeCustomEvent(event.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除此行程"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("關閉"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
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
    if (c.parsedTimes.isEmpty) return "";
    Map<int, List<String>> dayGroups = {};
    for (var t in c.parsedTimes) {
      if (!dayGroups.containsKey(t.day)) dayGroups[t.day] = [];
      dayGroups[t.day]!.add(t.period);
    }
    List<String> results = [];
    List<int> sortedDays = dayGroups.keys.toList()..sort();

    for (var d in sortedDays) {
      List<String> periods = dayGroups[d]!;
      periods.removeWhere((p) => p.contains("&nbsp") || p.trim().isEmpty);
      if (periods.isEmpty) continue;
      periods.sort(
        (a, b) => _periods.indexOf(a).compareTo(_periods.indexOf(b)),
      );

      String dayName = "星期${_fullWeekDays[d - 1]}";
      String periodStr = periods.join(", ");

      String timeRange = "";
      if (_timeRangeMap.isNotEmpty) {
        String? startT = _timeRangeMap[periods.first]?[0];
        String? endT = _timeRangeMap[periods.last]?[1];
        if (startT != null && endT != null) {
          timeRange = " ($startT - $endT)";
        }
      }
      results.add("$dayName ($periodStr節)$timeRange");
    }
    return results.join("\n");
  }

  Color _getCourseColor(String name, {String? id}) {
    final colors = [
      Colors.blue[700]!, // 藍
      Colors.orange[800]!, // 橘
      Colors.purple[600]!, // 紫
      Colors.teal[700]!, // 藍綠
      Colors.pink[500]!, // 粉紅      // 金黃
      Colors.indigo[600]!, // 靛藍
      Colors.deepOrange[600]!, // 橘紅
      Colors.cyan[700]!, // 青
      Colors.red[700]!, // 紅
      Colors.deepPurple[600]!, // 深紫
      Colors.green[700]!, // 正綠
    ];

    // 組合 key 並取絕對值雜湊
    final String key = id != null ? name + id : name;
    final int hash = key.hashCode.abs();

    return colors[hash % colors.length];
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text("選課助手功能說明", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "1. 提供自訂排課功能，模擬你的專屬課表。\n\n"
          "2. 方便在加簽時快速查看教室與上課時間等資訊。\n\n"
          "3. 支援新增「其他行程」(如工讀、社團)，協助管理個人時間。\n\n"
          "4. 支援從「選課小幫手」網站匯入課表。\n\n"
          "5. 排好的正規課程可直接匯出至「選課系統」進行快速選課。",
          style: TextStyle(height: 1.5, fontSize: 15),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "我知道了",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
