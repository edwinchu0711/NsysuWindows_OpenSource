import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/program_model.dart';
import '../services/ai_personalization_service.dart';
import '../services/department_service.dart';
import '../services/eligibility_checker.dart';
import '../services/program_service.dart';
import '../services/compulsory_simulation_service.dart';
import '../services/program_link_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/course_progress_left_panel.dart';
import '../widgets/course_progress_right_panel.dart';
import '../widgets/group_card_widget.dart';
import '../widgets/hover_icon_button.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'course_progress_detail_page.dart';

class CompulsorySimulationPage extends StatefulWidget {
  const CompulsorySimulationPage({super.key});

  @override
  State<CompulsorySimulationPage> createState() =>
      _CompulsorySimulationPageState();
}

class _CompulsorySimulationPageState extends State<CompulsorySimulationPage> {
  final _programService = ProgramService.instance;
  final _deptService = DepartmentService.instance;
  final _personalizationService = AiPersonalizationService.instance;

  // Crawl options state
  List<SimDeptOption> _depts = [];
  bool _isLoadingDepts = true;
  String? _deptsLoadError;

  // User input settings
  SimDeptOption? _selectedDept;
  String? _selectedYear;

  // Controllers and focus nodes for input
  final _deptController = TextEditingController();
  final _deptFocusNode = FocusNode();
  final _yearController = TextEditingController();
  final _yearFocusNode = FocusNode();

  // Simulation status & calculations
  bool _isSimulating = false;
  bool _hasSimulated = false;
  List<String> _simulatedCompulsoryCourses = [];
  List<CourseTakenInput> _simulatedCoursesTaken = [];
  Map<String, EligibilityResult> _simulatedProgramResults = {};

  // Selection state
  LeftTab _currentTab = LeftTab.allPrograms;
  ProgramRule? _selectedProgram;
  int? _selectedYearForProgram;
  EligibilityResult? _selectedResult;
  String? _pdfLink;

  // Favorites
  List<FavoriteProgram> _favoritePrograms = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _deptController.dispose();
    _deptFocusNode.dispose();
    _yearController.dispose();
    _yearFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingDepts = true;
      _deptsLoadError = null;
    });

    try {
      // 1. Fetch simulation departments from URL A & B
      final simulationDepts = await CompulsorySimulationService.instance
          .fetchSimulationDepts();

      // 2. Fetch/Load standard programs & departments if not loaded
      await Future.wait([
        _programService.loadFromCache(),
        _deptService.loadFromCache(),
        _personalizationService.loadFromCache(),
      ]);

      if (_programService.programsNotifier.value.isEmpty) {
        await _programService.fetchPrograms();
      }
      if (_deptService.departmentsNotifier.value.isEmpty) {
        await _deptService.fetchDepartments();
      }
      if (_personalizationService.resultsNotifier.value.isEmpty) {
        // Try getting history but don't block
        _personalizationService.fetchCourseHistory();
      }

      await _loadFavorites();

      final savedDept = await StorageService.instance.read(
        'progress_selected_dept',
      );

      if (mounted) {
        setState(() {
          _depts = simulationDepts;
          _isLoadingDepts = false;

          // 1. Set default department to the saved one
          if (savedDept != null && savedDept.isNotEmpty) {
            final match = _depts
                .where((d) => d.displayName == savedDept)
                .toList();
            if (match.isNotEmpty) {
              _selectedDept = match.first;
            } else {
              // Try fuzzy match
              final fuzzyMatch = _depts
                  .where(
                    (d) =>
                        d.displayName.contains(savedDept) ||
                        savedDept.contains(d.displayName),
                  )
                  .toList();
              if (fuzzyMatch.isNotEmpty) {
                _selectedDept = fuzzyMatch.first;
              }
            }
          }

          if (_selectedDept == null && _depts.isNotEmpty) {
            _selectedDept = _depts.first;
          }

          if (_selectedDept != null) {
            _deptController.text = _selectedDept!.displayName;
          }

          // 2. Set default academic year to the oldest year in historical score
          int? oldestYear;
          final history = _personalizationService.resultsNotifier.value;
          for (var r in history) {
            final sem = r.semester;
            final parts = sem.split('-');
            if (parts.isNotEmpty) {
              final yr = int.tryParse(parts[0]);
              if (yr != null) {
                if (oldestYear == null || yr < oldestYear) {
                  oldestYear = yr;
                }
              }
            }
          }

          final years = _getYearOptions();
          if (oldestYear != null) {
            _selectedYear = oldestYear.toString();
          } else if (years.isNotEmpty) {
            _selectedYear = years.first.toString();
          }

          if (_selectedYear != null) {
            _yearController.text = '$_selectedYear 學年度';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDepts = false;
          _deptsLoadError = "無法取得學系名單，請確認網路連線。";
        });
      }
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final jsonStr = await StorageService.instance.read(
        'progress_favorite_programs',
      );
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        setState(() {
          _favoritePrograms = decoded
              .map((e) => FavoriteProgram.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Simulation: Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_selectedProgram == null || _selectedYearForProgram == null) return;

    final programId = _selectedProgram!.programId;
    final year = _selectedYearForProgram!;

    final existingIndex = _favoritePrograms.indexWhere(
      (f) => f.programId == programId && f.academicYear == year,
    );

    setState(() {
      if (existingIndex >= 0) {
        _favoritePrograms.removeAt(existingIndex);
      } else {
        _favoritePrograms.add(
          FavoriteProgram(programId: programId, academicYear: year),
        );
      }
    });

    try {
      final encoded = jsonEncode(
        _favoritePrograms.map((e) => e.toJson()).toList(),
      );
      await StorageService.instance.save('progress_favorite_programs', encoded);
    } catch (e) {
      debugPrint('Simulation: Error saving favorites: $e');
    }
  }

  bool get _isCurrentFavorite {
    if (_selectedProgram == null || _selectedYearForProgram == null)
      return false;
    return _favoritePrograms.any(
      (f) =>
          f.programId == _selectedProgram!.programId &&
          f.academicYear == _selectedYearForProgram,
    );
  }

  List<int> _getYearOptions() {
    final currentRoc = DateTime.now().year - 1911;
    return List.generate(
      11,
      (index) => currentRoc - index,
    ); // [115, 114, 113, ..., 105]
  }

  /// Run crawling and compute simulated eligibility
  Future<void> _runSimulation() async {
    if (_selectedDept == null || _selectedYear == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請選擇學年度與科系")));
      return;
    }

    setState(() {
      _isSimulating = true;
      _selectedProgram = null;
      _selectedResult = null;
      _selectedYearForProgram = null;
      _pdfLink = null;
    });

    try {
      // 1. Crawl general compulsory courses from school website
      final compulsoryCourses = await CompulsorySimulationService.instance
          .fetchCompulsoryCourses(_selectedYear!, _selectedDept!.code);

      // 2. Load actual passed courses
      final actualPassed = _personalizationService.resultsNotifier.value
          .where((r) => r.passed)
          .map(
            (r) => CourseTakenInput(
              name: r.courseName,
              department: r.department,
              courseNo: r.courseNo,
              semester: r.semester,
            ),
          )
          .toList();

      // 3. Build simulated courses taken list
      final simulatedCompulsory = compulsoryCourses.map((name) {
        return CourseTakenInput(
          name: name,
          department:
              _selectedDept!.displayName, // Matches the selected department
          courseNo: '',
          semester: '',
        );
      }).toList();

      final combinedCourses = [...actualPassed, ...simulatedCompulsory];

      // 4. Calculate eligibility for all program rules
      final programs = _programService.programsNotifier.value;
      final results = <String, EligibilityResult>{};

      for (final program in programs) {
        if (program.isDiscontinued) continue;
        if (program.versions.isEmpty) continue;

        // Use the latest version for simulation calculations
        final latestVersion = program.versions.reduce(
          (a, b) => b.academicYear > a.academicYear ? b : a,
        );

        final result = EligibilityChecker.checkEligibility(
          program,
          latestVersion.academicYear,
          null,
          _selectedDept!.displayName, // Simulated student's department
          combinedCourses,
          const {}, // Empty waivers for simulation
          const [], // Double major
          const [], // Minor
          const {}, // Empty verifications
        );

        results[program.programId] = result;
      }

      if (mounted) {
        setState(() {
          _simulatedCompulsoryCourses = compulsoryCourses;
          _simulatedCoursesTaken = combinedCourses;
          _simulatedProgramResults = results;
          _hasSimulated = true;
          _isSimulating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("模擬成功！已載入 ${compulsoryCourses.length} 門模擬必修課程。"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSimulating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "模擬抓取失敗: ${e.toString().replaceAll('Exception: ', '')}",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Custom badge resolver to color simulated courses
  CourseSource? _simulatedCourseSourceResolver(SubjectResult s) {
    if (!s.satisfied) {
      return CourseSource.missing;
    }

    final normalizedSatisfied = EligibilityChecker.normalize(
      s.satisfiedBy ?? '',
    );

    // Check if the student actually took this course
    final actualPassedNames = _personalizationService.resultsNotifier.value
        .where((r) => r.passed)
        .map((r) => EligibilityChecker.normalize(r.courseName))
        .toSet();

    bool isActualTaken = false;
    for (final actualName in actualPassedNames) {
      if (EligibilityChecker.nameMatches(actualName, s.satisfiedBy ?? '')) {
        isActualTaken = true;
        break;
      }
    }

    if (isActualTaken) {
      return CourseSource.taken; // Green "已修"
    }

    // Otherwise it was fulfilled by a simulated compulsory course
    return CourseSource.required; // Blue "必修課程"
  }

  Future<void> _checkProgram(ProgramRule program, int year) async {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    if (!isWideScreen) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseProgressDetailPage(
            result: null,
            program: program,
            academicYear: year,
            isFavorite: _favoritePrograms.any(
              (f) => f.programId == program.programId && f.academicYear == year,
            ),
            onFavoriteToggle: _toggleFavorite,
            waivers: const {},
            selectedDept: _selectedDept!.displayName,
            coursesTaken: _simulatedCoursesTaken,
            doubleMajorDepts: const [],
            minorDepts: const [],
            courseSourceResolver: _simulatedCourseSourceResolver,
          ),
        ),
      ).then((_) => _loadFavorites());
      return;
    }

    setState(() {
      _selectedProgram = program;
      _selectedYearForProgram = year;
      _selectedResult = null;
      _pdfLink = null;
    });

    ProgramLinkService.instance.getPdfLink(program.programName).then((link) {
      if (mounted) {
        setState(() => _pdfLink = link);
      }
    });

    final result = EligibilityChecker.checkEligibility(
      program,
      year,
      null,
      _selectedDept!.displayName,
      _simulatedCoursesTaken,
      const {},
      const [],
      const [],
      const {},
    );

    setState(() {
      _selectedResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: null,
      body: Column(
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: _buildHeader(),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      _buildSettingsCard(colorScheme, isWideScreen),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _isSimulating
                            ? _buildLoadingState(colorScheme)
                            : !_hasSimulated
                            ? _buildInitialState(colorScheme)
                            : _buildSimulationResults(
                                colorScheme,
                                isWideScreen,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 20, top: 10, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              HoverIconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => context.pop(),
                tooltip: "返回學程進度",
                color: colorScheme.primaryText,
                iconSize: 18,
                padding: 8,
              ),
              const SizedBox(width: 4),
              Text(
                "完成必修模擬",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              HoverIconButton(
                icon: const Icon(Icons.info_outline_rounded, size: 20),
                tooltip: "功能說明",
                onPressed: () => _showSimulationInfoDialog(colorScheme),
                color: colorScheme.primaryText,
                iconSize: 20,
                padding: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSimulationInfoDialog(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colorScheme.surface,
        elevation: 12,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '關於完成必修模擬',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primaryText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: Colors.purple.shade400,
                  title: '什麼是必修模擬？',
                  body: '此功能會模擬抓取指定科系與入學學年度畢業生的「一般必修」課程列表，並假裝您已修習並通過這些學分。',
                ),
                const SizedBox(height: 20),
                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: Colors.blue.shade400,
                  title: '學程進度融合判定',
                  body: '結合使用者「實際已修過且通過」的課程與「模擬抓取」的必修課，重新計算並展示每個學程的最新完成度。',
                ),
                const SizedBox(height: 20),
                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: Colors.teal.shade400,
                  title: '自訂顏色標記',
                  body: '在右側科目表中，您實際修畢的課程會標註綠色「已修」標籤；模擬抓取的必修課程會標註藍色「必修課程」標籤。',
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.subtleBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '⚠️ 提醒：模擬結果僅供選課規劃參考，最終學程合格與否仍以學校審查為準。',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.subtitleText.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '我知道了',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required ColorScheme colorScheme,
    required Color accentColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accentColor.withValues(alpha: 0.8),
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.subtitleText.withValues(alpha: 0.95),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(ColorScheme colorScheme, bool isWide) {
    final years = _getYearOptions();
    final yearSuggestions = years.map((y) => '$y 學年度').toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                Icons.psychology_outlined,
                size: 16,
                color: colorScheme.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                '完成必修模擬設定',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '你的科系',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 36,
                        child: SearchableDropdownField(
                          controller: _deptController,
                          focusNode: _deptFocusNode,
                          hintText: _isLoadingDepts ? '載入中...' : '搜尋模擬科系',
                          suggestions: _depts
                              .map((d) => d.displayName)
                              .toList(),
                          onChanged: (val) {
                            final match = _depts
                                .where((d) => d.displayName == val)
                                .toList();
                            setState(() {
                              _selectedDept = match.isNotEmpty
                                  ? match.first
                                  : null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '入學學年度',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 36,
                        child: SearchableDropdownField(
                          controller: _yearController,
                          focusNode: _yearFocusNode,
                          hintText: '選擇入學學年度',
                          suggestions: yearSuggestions,
                          enableSearch: false,
                          onChanged: (val) {
                            final year = val.replaceAll(' 學年度', '');
                            setState(() {
                              _selectedYear = year;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingDepts ? null : _runSimulation,
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text(
                      '確認模擬',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.accentBlue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '模擬科系',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: SearchableDropdownField(
                        controller: _deptController,
                        focusNode: _deptFocusNode,
                        hintText: _isLoadingDepts ? '載入中...' : '搜尋模擬科系',
                        suggestions: _depts.map((d) => d.displayName).toList(),
                        onChanged: (val) {
                          final match = _depts
                              .where((d) => d.displayName == val)
                              .toList();
                          setState(() {
                            _selectedDept = match.isNotEmpty
                                ? match.first
                                : null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '畢業學年度',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.subtitleText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: SearchableDropdownField(
                              controller: _yearController,
                              focusNode: _yearFocusNode,
                              hintText: '選擇學年度',
                              suggestions: yearSuggestions,
                              enableSearch: false,
                              onChanged: (val) {
                                final year = val.replaceAll(' 學年度', '');
                                setState(() {
                                  _selectedYear = year;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingDepts ? null : _runSimulation,
                        icon: const Icon(Icons.bolt, size: 16),
                        label: const Text(
                          '確認模擬',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.accentBlue,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (_deptsLoadError != null) ...[
            const SizedBox(height: 8),
            Text(
              _deptsLoadError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: colorScheme.subtitleText.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '請先選擇上方學年度與科系，點擊確認模擬開始分析。',
            style: TextStyle(fontSize: 15, color: colorScheme.subtitleText),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colorScheme.accentBlue),
          const SizedBox(height: 16),
          Text(
            '正在自動抓取該科系之畢業必修課程…',
            style: TextStyle(fontSize: 15, color: colorScheme.subtitleText),
          ),
          const SizedBox(height: 8),
          Text(
            '此動作將抓取即時資料並模擬為您已修過的必修學分',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.subtitleText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationResults(ColorScheme colorScheme, bool isWideScreen) {
    final programs = _programService.programsNotifier.value;
    final departments = _deptService.departmentsNotifier.value;

    if (isWideScreen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: CourseProgressLeftPanel(
              currentTab: _currentTab,
              onTabChanged: (tab) => setState(() => _currentTab = tab),
              isComputingAll: false,
              isLoading: false,
              selectedDept: _selectedDept!.displayName,
              programs: programs,
              departments: departments,
              allProgramResults: _simulatedProgramResults,
              selectedProgramId: _selectedProgram?.programId,
              onProgramSelected: _checkProgram,
              isDisabled: false,
              favoritePrograms: _favoritePrograms,
              onRemoveFavorite: (fav) {
                setState(() {
                  _favoritePrograms.removeWhere(
                    (f) =>
                        f.programId == fav.programId &&
                        f.academicYear == fav.academicYear,
                  );
                });
                try {
                  final encoded = jsonEncode(
                    _favoritePrograms.map((e) => e.toJson()).toList(),
                  );
                  StorageService.instance.save(
                    'progress_favorite_programs',
                    encoded,
                  );
                } catch (_) {}
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: CourseProgressRightPanel(
              result: _selectedResult,
              program: _selectedProgram,
              isFavorite: _isCurrentFavorite,
              onFavoriteToggle: _toggleFavorite,
              waivers: const {},
              verificationStatuses: const {},
              pdfLink: _pdfLink,
              isLoading: false,
              courseSourceResolver: _simulatedCourseSourceResolver,
            ),
          ),
        ],
      );
    } else {
      return CourseProgressLeftPanel(
        currentTab: _currentTab,
        onTabChanged: (tab) => setState(() => _currentTab = tab),
        isComputingAll: false,
        isLoading: false,
        selectedDept: _selectedDept!.displayName,
        programs: programs,
        departments: departments,
        allProgramResults: _simulatedProgramResults,
        selectedProgramId: _selectedProgram?.programId,
        onProgramSelected: _checkProgram,
        isDisabled: false,
        favoritePrograms: _favoritePrograms,
        onRemoveFavorite: (fav) {
          setState(() {
            _favoritePrograms.removeWhere(
              (f) =>
                  f.programId == fav.programId &&
                  f.academicYear == fav.academicYear,
            );
          });
          try {
            final encoded = jsonEncode(
              _favoritePrograms.map((e) => e.toJson()).toList(),
            );
            StorageService.instance.save('progress_favorite_programs', encoded);
          } catch (_) {}
        },
      );
    }
  }
}
