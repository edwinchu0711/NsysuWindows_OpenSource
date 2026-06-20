import 'dart:convert';
import 'package:NSYSU/pages/compulsory_simulation_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/program_model.dart';
import '../services/ai_personalization_service.dart';
import '../services/department_service.dart';
import '../services/eligibility_checker.dart';
import '../services/program_application_service.dart';
import '../services/program_link_service.dart';
import '../services/program_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/course_progress_left_panel.dart';
import '../widgets/course_progress_profile_bar.dart';
import '../widgets/course_progress_right_panel.dart';
import '../widgets/course_progress_passed_courses.dart';
import '../widgets/hover_icon_button.dart';
import 'course_progress_detail_page.dart';

class CourseProgressPage extends StatefulWidget {
  const CourseProgressPage({super.key});

  @override
  State<CourseProgressPage> createState() => _CourseProgressPageState();
}

class _CourseProgressPageState extends State<CourseProgressPage> {
  final _programService = ProgramService.instance;
  final _deptService = DepartmentService.instance;
  final _courseService = AiPersonalizationService.instance;

  // Profile fields (committed values -- only updated on save)
  String _selectedDept = '';
  String _doubleMajor = '';
  String _minor = '';

  // Dirty state tracking
  bool _isDirty = false;

  // Left panel state
  LeftTab _currentTab = LeftTab.allPrograms;
  ProgramRule? _selectedProgram;
  int? _selectedYear;
  EligibilityResult? _selectedResult;

  // All programs completion data
  Map<String, EligibilityResult> _allProgramResults = {};
  bool _isComputingAll = false;
  bool _hasComputedAll = false;
  bool _isLoading = true;
  String? _loadError;
  bool _isPassedCoursesTileHovered = false;
  bool _isCompulsorySimulationTileHovered = false;

  // Waivers
  final Map<String, List<String>> _waivers = {};

  // Cross-dept verification statuses: key = "courseName::department"
  Map<String, VerificationStatus> _verificationStatuses = {};

  // In-memory cache of verification statuses per program+year (populated by _computeAllPrograms)
  // Key: "programId_year", Value: the verification map for that program/year
  final Map<String, Map<String, VerificationStatus>> _verificationCache = {};

  // Selected program/year for verification persistence
  String? _lastProgramId;
  int? _lastYear;

  // Favorites
  List<FavoriteProgram> _favoritePrograms = [];

  // PDF link for selected program
  String? _pdfLink;

  bool _viewingPassedCourses = false;
  bool _isRightPanelLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _programService.programsNotifier.addListener(_onDataChanged);
    _programService.isLoadingNotifier.addListener(_onDataChanged);
    _deptService.departmentsNotifier.addListener(_onDataChanged);
    _courseService.resultsNotifier.addListener(_onDataChanged);
    _courseService.isLoadingNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _programService.programsNotifier.removeListener(_onDataChanged);
    _programService.isLoadingNotifier.removeListener(_onDataChanged);
    _deptService.departmentsNotifier.removeListener(_onDataChanged);
    _courseService.resultsNotifier.removeListener(_onDataChanged);
    _courseService.isLoadingNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {});
      if (_selectedDept.isNotEmpty &&
          _coursesTaken.isNotEmpty &&
          !_hasComputedAll &&
          !_isComputingAll) {
        _computeAllPrograms();
      }
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    // 延遲載入以確保首頁 Bento 轉場動畫流暢播放完畢，避免阻塞 UI 線程
    await Future.delayed(const Duration(milliseconds: 400));

    await Future.wait([
      _programService.loadFromCache(),
      _deptService.loadFromCache(),
      _courseService.loadFromCache(),
      ProgramApplicationService.instance.loadFromCache(),
    ]);

    // 如果修課資料快取為空，嘗試從歷年成績抓取
    if (_courseService.resultsNotifier.value.isEmpty) {
      _courseService.fetchCourseHistory();
    }

    await _loadFavorites();

    final savedDept = await StorageService.instance.read(
      'progress_selected_dept',
    );
    final savedDoubleMajor = await StorageService.instance.read(
      'progress_double_major',
    );
    final savedMinor = await StorageService.instance.read('progress_minor');
    final savedProgramId = await StorageService.instance.read(
      'progress_last_program_id',
    );
    final savedYearStr = await StorageService.instance.read(
      'progress_last_year',
    );
    final savedYear = savedYearStr != null ? int.tryParse(savedYearStr) : null;

    if (!mounted) return;
    setState(() {
      _selectedDept = savedDept ?? '';
      _doubleMajor = savedDoubleMajor ?? '';
      _minor = savedMinor ?? '';
    });

    // 如果快取有資料，先結束 loading 讓使用者看到內容
    final hasCachedPrograms = _programService.programsNotifier.value.isNotEmpty;
    final hasCachedDepts = _deptService.departmentsNotifier.value.isNotEmpty;
    if (hasCachedPrograms && hasCachedDepts) {
      if (mounted) setState(() => _isLoading = false);
    }

    // 從網路取得最新資料（如果快取是空的）
    try {
      if (!hasCachedPrograms) {
        await _programService.fetchPrograms();
      }
      if (!hasCachedDepts) {
        await _deptService.fetchDepartments();
      }
    } catch (e) {
      debugPrint('Network fetch error: $e');
    }

    if (!mounted) return;

    // 檢查最終狀態：如果都沒有資料就是錯誤
    if (_programService.programsNotifier.value.isEmpty ||
        _deptService.departmentsNotifier.value.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = '無法載入資料，請檢查網路連線後重試';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    }

    if (savedProgramId != null && savedYear != null) {
      final programs = _programService.programsNotifier.value;
      final savedProgram = programs
          .where((p) => p.programId == savedProgramId)
          .toList();
      if (savedProgram.isNotEmpty) {
        final isWideScreen = MediaQuery.of(context).size.width >= 900;
        setState(() {
          _lastProgramId = savedProgramId;
          _lastYear = savedYear;
        });
        await _loadVerificationStatuses();

        if (isWideScreen && mounted && _selectedDept.isNotEmpty) {
          final prog = savedProgram.first;
          setState(() {
            _selectedProgram = prog;
            _selectedYear = savedYear;
          });
          ProgramLinkService.instance.getPdfLink(prog.programName).then((link) {
            if (mounted) {
              setState(() => _pdfLink = link);
            }
          });
          final result = EligibilityChecker.checkEligibility(
            prog,
            savedYear,
            null,
            _selectedDept,
            _coursesTaken,
            _waivers,
            _doubleMajorDepts,
            _minorDepts,
            _verificationStatuses,
          );
          setState(() {
            _selectedResult = result;
          });
        }
      }
    }

    if (mounted && _selectedDept.isNotEmpty && _coursesTaken.isNotEmpty) {
      await _computeAllPrograms();
    }
  }

  Future<void> _saveProfile(
    String dept,
    String doubleMajor,
    String minor,
  ) async {
    await StorageService.instance.save('progress_selected_dept', dept);
    await StorageService.instance.save('progress_double_major', doubleMajor);
    await StorageService.instance.save('progress_minor', minor);

    if (mounted) {
      setState(() {
        _selectedDept = dept;
        _doubleMajor = doubleMajor;
        _minor = minor;
        _isDirty = false;
        _hasComputedAll = false;
        _allProgramResults = {};
        _selectedResult = null;
        _viewingPassedCourses = false;
      });
      _computeAllPrograms();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
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
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_selectedProgram == null || _selectedYear == null) return;

    final existingIndex = _favoritePrograms.indexWhere(
      (f) =>
          f.programId == _selectedProgram!.programId &&
          f.academicYear == _selectedYear!,
    );

    setState(() {
      if (existingIndex >= 0) {
        _favoritePrograms.removeAt(existingIndex);
      } else {
        _favoritePrograms.add(
          FavoriteProgram(
            programId: _selectedProgram!.programId,
            academicYear: _selectedYear!,
          ),
        );
      }
    });

    try {
      final encoded = jsonEncode(
        _favoritePrograms.map((e) => e.toJson()).toList(),
      );
      await StorageService.instance.save('progress_favorite_programs', encoded);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  bool get _isCurrentFavorite {
    if (_selectedProgram == null || _selectedYear == null) return false;
    return _favoritePrograms.any(
      (f) =>
          f.programId == _selectedProgram!.programId &&
          f.academicYear == _selectedYear,
    );
  }

  Future<void> _removeFavorite(FavoriteProgram fav) async {
    setState(() {
      _favoritePrograms.removeWhere(
        (f) =>
            f.programId == fav.programId && f.academicYear == fav.academicYear,
      );
    });
    try {
      final encoded = jsonEncode(
        _favoritePrograms.map((e) => e.toJson()).toList(),
      );
      await StorageService.instance.save('progress_favorite_programs', encoded);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  List<CourseTakenInput> get _coursesTaken => _courseService
      .resultsNotifier
      .value
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

  List<String> get _doubleMajorDepts => _doubleMajor.isEmpty
      ? []
      : _doubleMajor
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

  Future<void> _loadVerificationStatuses() async {
    if (_lastProgramId == null || _lastYear == null) return;
    final key = 'progress_verifications_${_lastProgramId}_$_lastYear';
    final jsonStr = await StorageService.instance.read(key);

    if (!mounted) return;

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        setState(() {
          _verificationStatuses = decoded.map(
            (k, v) => MapEntry(
              k,
              VerificationStatus.values.firstWhere(
                (e) => e.name == v,
                orElse: () => VerificationStatus.unfilled,
              ),
            ),
          );
        });
      } catch (_) {
        setState(() => _verificationStatuses = {});
      }
    } else {
      setState(() => _verificationStatuses = {});
    }
  }

  Future<void> _saveVerificationStatuses() async {
    if (_lastProgramId == null || _lastYear == null) return;
    final key = 'progress_verifications_${_lastProgramId}_$_lastYear';
    final encoded = jsonEncode(
      _verificationStatuses.map((k, v) => MapEntry(k, v.name)),
    );
    await StorageService.instance.save(key, encoded);
  }

  void _updateVerificationStatus(String vKey, VerificationStatus status) {
    setState(() {
      _verificationStatuses[vKey] = status;
    });
    _saveVerificationStatuses();

    // Keep in-memory cache in sync
    if (_lastProgramId != null && _lastYear != null) {
      final cacheKey = '${_lastProgramId}_$_lastYear';
      _verificationCache[cacheKey] = Map.from(_verificationStatuses);
    }

    if (_selectedProgram != null && _selectedYear != null) {
      final result = EligibilityChecker.checkEligibility(
        _selectedProgram!,
        _selectedYear!,
        null,
        _selectedDept,
        _coursesTaken,
        _waivers,
        _doubleMajorDepts,
        _minorDepts,
        _verificationStatuses,
      );
      setState(() {
        _selectedResult = result;
        _allProgramResults[_selectedProgram!.programId] = result;
      });
    }

    _computeAllPrograms();
  }

  void _updateWaiver(String subject, String waiverId, bool checked) {
    setState(() {
      if (checked) {
        _waivers.putIfAbsent(subject, () => []);
        if (!_waivers[subject]!.contains(waiverId)) {
          _waivers[subject]!.add(waiverId);
        }
      } else {
        _waivers[subject]?.remove(waiverId);
        if (_waivers[subject]?.isEmpty ?? false) {
          _waivers.remove(subject);
        }
      }
    });

    if (_selectedProgram != null && _selectedYear != null) {
      final result = EligibilityChecker.checkEligibility(
        _selectedProgram!,
        _selectedYear!,
        null,
        _selectedDept,
        _coursesTaken,
        _waivers,
        _doubleMajorDepts,
        _minorDepts,
        _verificationStatuses,
      );
      setState(() {
        _selectedResult = result;
        _allProgramResults[_selectedProgram!.programId] = result;
      });
    }

    _computeAllPrograms();
  }

  List<String> get _minorDepts => _minor.isEmpty
      ? []
      : _minor
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

  Future<void> _computeAllPrograms() async {
    if (_selectedDept.isEmpty || _coursesTaken.isEmpty) return;
    if (_isComputingAll) return;
    setState(() => _isComputingAll = true);

    try {
      final programs = _programService.programsNotifier.value;
      final results = <String, EligibilityResult>{};

      for (final program in programs) {
        if (program.isDiscontinued) continue;
        if (program.versions.isEmpty) continue;

        final latestVersion = program.versions.reduce(
          (a, b) => b.academicYear > a.academicYear ? b : a,
        );

        Map<String, VerificationStatus> programVerifications = {};
        try {
          final vKey =
              'progress_verifications_${program.programId}_${latestVersion.academicYear}';
          final jsonStr = await StorageService.instance.read(vKey);
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
            programVerifications = decoded.map(
              (k, v) => MapEntry(
                k,
                VerificationStatus.values.firstWhere(
                  (e) => e.name == v,
                  orElse: () => VerificationStatus.unfilled,
                ),
              ),
            );
          }
        } catch (_) {}

        final result = EligibilityChecker.checkEligibility(
          program,
          latestVersion.academicYear,
          null,
          _selectedDept,
          _coursesTaken,
          _waivers,
          _doubleMajorDepts,
          _minorDepts,
          programVerifications,
        );
        results[program.programId] = result;

        // Cache the verification statuses in memory for instant access in _checkProgram
        final cacheKey = '${program.programId}_${latestVersion.academicYear}';
        _verificationCache[cacheKey] = programVerifications;
      }

      if (mounted) {
        setState(() {
          _allProgramResults = results;
          _hasComputedAll = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isComputingAll = false);
    }
  }

  Future<void> _checkProgram(ProgramRule program, int year) async {
    if (_selectedDept.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先填寫你的科系並儲存')));
      return;
    }

    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    if (!isWideScreen) {
      setState(() {
        _selectedProgram = program;
        _selectedYear = year;
        _lastProgramId = program.programId;
        _lastYear = year;
      });

      // Save to storage asynchronously (non-blocking)
      StorageService.instance.save(
        'progress_last_program_id',
        program.programId,
      );
      StorageService.instance.save('progress_last_year', year.toString());

      // Load verification statuses before navigation to ensure they are available in parent's map
      await _loadVerificationStatuses();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseProgressDetailPage(
              result: null,
              program: program,
              academicYear: year,
              isFavorite: _favoritePrograms.any(
                (f) =>
                    f.programId == program.programId && f.academicYear == year,
              ),
              onFavoriteToggle: _toggleFavorite,
              waivers: _waivers,
              onWaiverChanged: _updateWaiver,
              verificationStatuses: _verificationStatuses,
              onVerificationChanged: _updateVerificationStatus,
              pdfLink: _pdfLink,
              selectedDept: _selectedDept,
              coursesTaken: _coursesTaken,
              doubleMajorDepts: _doubleMajorDepts,
              minorDepts: _minorDepts,
            ),
          ),
        ).then((_) {
          _loadData();
        });
      }
      return;
    }

    // Use cached verification statuses (populated by _computeAllPrograms) for instant access
    final cacheKey = '${program.programId}_$year';
    final cachedVerifications = _verificationCache[cacheKey] ?? {};

    _verificationStatuses = cachedVerifications;
    _lastProgramId = program.programId;
    _lastYear = year;

    final result = EligibilityChecker.checkEligibility(
      program,
      year,
      null,
      _selectedDept,
      _coursesTaken,
      _waivers,
      _doubleMajorDepts,
      _minorDepts,
      cachedVerifications,
    );

    setState(() {
      _viewingPassedCourses = false;
      _selectedProgram = program;
      _selectedYear = year;
      _selectedResult = result;
      _isRightPanelLoading = false;
      _pdfLink = null;
    });

    // Non-blocking: fetch PDF link & persist selection in background
    ProgramLinkService.instance.getPdfLink(program.programName).then((link) {
      if (mounted) {
        setState(() => _pdfLink = link);
      }
    });

    StorageService.instance.save('progress_last_program_id', program.programId);
    StorageService.instance.save('progress_last_year', year.toString());
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
                onPressed: () => context.go('/home'),
                tooltip: "返回主選單",
                color: colorScheme.primaryText,
                iconSize: 18,
                padding: 8,
              ),
              const SizedBox(width: 4),
              Text(
                "學程進度",
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
                onPressed: () => _showInfoDialog(colorScheme),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final programs = _programService.programsNotifier.value;
    final departments = _deptService.departmentsNotifier.value;
    final isDisabled = _selectedDept.isEmpty;
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: null,
      body: _isLoading
          ? _buildSkeletonLoading(colorScheme)
          : _loadError != null
          ? _buildErrorState(colorScheme)
          : Column(
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
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: CourseProgressProfileBar(
                                      departments: departments,
                                      savedDept: _selectedDept,
                                      savedDoubleMajor: _doubleMajor,
                                      savedMinor: _minor,
                                      isDirty: _isDirty,
                                      onFieldChanged: _markDirty,
                                      onSave: _saveProfile,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: isWideScreen ? 180 : 95,
                                    child: _buildPassedCoursesTile(
                                      colorScheme,
                                      isWideScreen,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: isWideScreen ? 180 : 95,
                                    child: _buildCompulsorySimulationTile(
                                      colorScheme,
                                      isWideScreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _coursesTaken.isEmpty
                                  ? _buildManualSyncCard(colorScheme)
                                  : IgnorePointer(
                                      ignoring: isDisabled,
                                      child: Opacity(
                                        opacity: isDisabled ? 0.4 : 1.0,
                                        child: isWideScreen
                                            ? Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: CourseProgressLeftPanel(
                                                      currentTab: _currentTab,
                                                      onTabChanged: (tab) =>
                                                          setState(
                                                            () => _currentTab =
                                                                tab,
                                                          ),
                                                      isComputingAll:
                                                          _isComputingAll,
                                                      isLoading: _isLoading,
                                                      isCourseDataLoading:
                                                          _courseService
                                                              .isLoadingNotifier
                                                              .value,
                                                      selectedDept:
                                                          _selectedDept,
                                                      programs: programs,
                                                      departments: departments,
                                                      allProgramResults:
                                                          _allProgramResults,
                                                      selectedProgramId:
                                                          _selectedProgram
                                                              ?.programId,
                                                      onProgramSelected:
                                                          _checkProgram,
                                                      isDisabled: isDisabled,
                                                      favoritePrograms:
                                                          _favoritePrograms,
                                                      verificationStatuses:
                                                          _verificationStatuses,
                                                      onRemoveFavorite:
                                                          _removeFavorite,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 20),
                                                  Expanded(
                                                    flex: 3,
                                                    child: _viewingPassedCourses
                                                        ? CourseProgressPassedCoursesPanel(
                                                            onClose: () {
                                                              setState(() {
                                                                _viewingPassedCourses =
                                                                    false;
                                                              });
                                                            },
                                                            onStartManualSync:
                                                                _startManualSync,
                                                          )
                                                        : CourseProgressRightPanel(
                                                            result:
                                                                _selectedResult,
                                                            program:
                                                                _selectedProgram,
                                                            isFavorite:
                                                                _isCurrentFavorite,
                                                            onFavoriteToggle:
                                                                _toggleFavorite,
                                                            waivers: _waivers,
                                                            onWaiverChanged:
                                                                _updateWaiver,
                                                            verificationStatuses:
                                                                _verificationStatuses,
                                                            onVerificationChanged:
                                                                _updateVerificationStatus,
                                                            pdfLink: _pdfLink,
                                                            isLoading:
                                                                _isRightPanelLoading,
                                                          ),
                                                  ),
                                                ],
                                              )
                                            : CourseProgressLeftPanel(
                                                currentTab: _currentTab,
                                                onTabChanged: (tab) => setState(
                                                  () => _currentTab = tab,
                                                ),
                                                isComputingAll: _isComputingAll,
                                                isLoading: _isLoading,
                                                isCourseDataLoading:
                                                    _courseService
                                                        .isLoadingNotifier
                                                        .value,
                                                selectedDept: _selectedDept,
                                                programs: programs,
                                                departments: departments,
                                                allProgramResults:
                                                    _allProgramResults,
                                                selectedProgramId:
                                                    _selectedProgram?.programId,
                                                onProgramSelected:
                                                    _checkProgram,
                                                isDisabled: isDisabled,
                                                favoritePrograms:
                                                    _favoritePrograms,
                                                verificationStatuses:
                                                    _verificationStatuses,
                                                onRemoveFavorite:
                                                    _removeFavorite,
                                              ),
                                      ),
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

  Widget _buildPassedCoursesTile(ColorScheme colorScheme, bool isWideScreen) {
    return ValueListenableBuilder<List<CourseHistoryResult>>(
      valueListenable: _courseService.resultsNotifier,
      builder: (context, results, _) {
        final coursesCount = results.length;
        int totalCredits = 0;
        for (var r in results) {
          if (r.passed) {
            totalCredits += int.tryParse(r.credits) ?? 0;
          }
        }

        final isHovered = _isPassedCoursesTileHovered;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isPassedCoursesTileHovered = true),
          onExit: (_) => setState(() => _isPassedCoursesTileHovered = false),
          child: GestureDetector(
            onTap: () {
              if (MediaQuery.of(context).size.width >= 900) {
                setState(() {
                  _viewingPassedCourses = true;
                  _selectedProgram = null;
                  _selectedResult = null;
                });
              } else {
                _showPassedCoursesBottomSheet();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isWideScreen ? 16 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colorScheme.isDark
                      ? [
                          const Color(
                            0xFF1E2D4A,
                          ).withValues(alpha: isHovered ? 0.85 : 1.0),
                          const Color(
                            0xFF172030,
                          ).withValues(alpha: isHovered ? 0.85 : 1.0),
                        ]
                      : [
                          const Color(
                            0xFFE3F2FD,
                          ).withValues(alpha: isHovered ? 0.95 : 1.0),
                          const Color(
                            0xFFBBDEFB,
                          ).withValues(alpha: isHovered ? 0.95 : 1.0),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.isDark
                      ? colorScheme.accentBlue.withValues(
                          alpha: isHovered ? 0.75 : 0.4,
                        )
                      : colorScheme.accentBlue.withValues(
                          alpha: isHovered ? 0.45 : 0.2,
                        ),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.accentBlue.withValues(
                      alpha: isHovered ? 0.12 : 0.05,
                    ),
                    blurRadius: isHovered ? 12 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_turned_in_rounded,
                        size: 16,
                        color: colorScheme.accentBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '已修課程',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$coursesCount',
                        style: TextStyle(
                          fontSize: isWideScreen ? 28 : 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '門',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                    ],
                  ),
                  if (isWideScreen) ...[
                    const SizedBox(height: 2),
                    Text(
                      '共 $totalCredits 學分',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '查看詳細清單',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.accentBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 11,
                        color: colorScheme.accentBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompulsorySimulationTile(
    ColorScheme colorScheme,
    bool isWideScreen,
  ) {
    final isHovered = _isCompulsorySimulationTileHovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isCompulsorySimulationTileHovered = true),
      onExit: (_) => setState(() => _isCompulsorySimulationTileHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CompulsorySimulationPage(),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isWideScreen ? 16 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colorScheme.isDark
                  ? [
                      const Color(
                        0xFF3B2E5C,
                      ).withValues(alpha: isHovered ? 0.85 : 1.0),
                      const Color(
                        0xFF261D40,
                      ).withValues(alpha: isHovered ? 0.85 : 1.0),
                    ]
                  : [
                      const Color(
                        0xFFF3E5F5,
                      ).withValues(alpha: isHovered ? 0.95 : 1.0),
                      const Color(
                        0xFFE1BEE7,
                      ).withValues(alpha: isHovered ? 0.95 : 1.0),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.isDark
                  ? Colors.purpleAccent.withValues(
                      alpha: isHovered ? 0.75 : 0.4,
                    )
                  : Colors.purple.withValues(alpha: isHovered ? 0.45 : 0.2),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: isHovered ? 0.12 : 0.05),
                blurRadius: isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '完成必修模擬',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: isWideScreen ? 24 : 18,
                    color: colorScheme.isDark
                        ? Colors.purpleAccent
                        : Colors.purple,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '模擬',
                    style: TextStyle(
                      fontSize: isWideScreen ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.isDark
                          ? Colors.purpleAccent
                          : Colors.purple,
                    ),
                  ),
                ],
              ),
              if (isWideScreen) ...[
                const SizedBox(height: 2),
                Text(
                  '畢業必修學分模擬',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.subtitleText,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Text(
                    '開始模擬分析',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.isDark
                          ? Colors.purpleAccent
                          : Colors.purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 11,
                    color: colorScheme.isDark
                        ? Colors.purpleAccent
                        : Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPassedCoursesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CourseProgressPassedCoursesBottomSheet(
          onStartManualSync: _startManualSync,
        );
      },
    );
  }

  Widget _buildManualSyncCard(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: _courseService.isLoadingNotifier,
            builder: (context, isLoading, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.accentBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLoading ? Icons.sync : Icons.cloud_download_outlined,
                      size: 48,
                      color: colorScheme.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isLoading ? "正在同步已修課程..." : "同步已修課程資料",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      isLoading
                          ? "正在與學校選課系統連線，這可能需要幾十秒鐘，請不要關閉此畫面..."
                          : "在分析您的學程進度前，系統需要讀取您的已修課程資料。請點擊下方按鈕進行同步。",
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.subtitleText,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading) ...[
                    ValueListenableBuilder<String>(
                      valueListenable: _courseService.statusMessageNotifier,
                      builder: (context, statusMsg, _) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  color: colorScheme.accentBlue,
                                  backgroundColor: colorScheme.borderColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              statusMsg.isNotEmpty ? statusMsg : "準備中...",
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.accentBlue,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _startManualSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.accentBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '立即同步已修課程',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _startManualSync() async {
    try {
      await _courseService.fetchCourseHistory();
      if (_coursesTaken.isEmpty) {
        _showErrorSnackBar("同步失敗，或未找到您的已修課程。請確認登入狀態，或稍後再試！");
      } else {
        _showSuccessSnackBar("同步成功！已載入 ${_coursesTaken.length} 門已修課程。");
        _loadData();
      }
    } catch (e) {
      _showErrorSnackBar("同步發生異常，請確認連線或稍後再試！");
    }
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Error / no-network state
  // ─────────────────────────────────────────────
  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: colorScheme.subtitleText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              _loadError ?? '無法載入資料',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '請確認網路連線狀態後再試一次',
              style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  '重新載入',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Loading state
  // ─────────────────────────────────────────────
  Widget _buildSkeletonLoading(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colorScheme.accentBlue),
          const SizedBox(height: 16),
          Text(
            '載入中…',
            style: TextStyle(fontSize: 15, color: colorScheme.subtitleText),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(ColorScheme colorScheme) {
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
                  '關於學程進度',
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
                  accentColor: Colors.orange.shade400,
                  title: 'AI 數據轉換',
                  body: '學程規則由 AI 自動解析，數據可能存在誤差，請務必以官方公告為準。',
                ),

                const SizedBox(height: 20),

                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: Colors.teal.shade400,
                  title: '跨院課程確認',
                  body: '部分課程認定較為複雜，系統無法自動涵蓋所有情況，建議與系辦再次確認。',
                ),

                const SizedBox(height: 20),

                _buildInfoRow(
                  colorScheme: colorScheme,
                  accentColor: colorScheme.accentBlue,
                  title: '完成度參考',
                  body: '進度百分比為系統估算值，僅供選課參考，不代表最終審核結果。',
                ),

                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.subtleBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '⚠️ 提醒：因資訊落差導致的任何問題，本系統不負擔相關責任。',
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
}
