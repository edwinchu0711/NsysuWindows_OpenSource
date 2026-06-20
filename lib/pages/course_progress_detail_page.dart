import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../services/eligibility_checker.dart';
import '../services/program_link_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/course_progress_right_panel.dart';
import '../widgets/hover_icon_button.dart';
import '../widgets/group_card_widget.dart';

class CourseProgressDetailPage extends StatefulWidget {
  final EligibilityResult? result;
  final ProgramRule? program;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final Map<String, List<String>> waivers;
  final void Function(String subject, String waiverId, bool checked)?
  onWaiverChanged;
  final Map<String, VerificationStatus> verificationStatuses;
  final void Function(String vKey, VerificationStatus status)?
  onVerificationChanged;
  final String? pdfLink;
  final CourseSourceResolver? courseSourceResolver;

  // Inputs needed for local recomputation
  final String selectedDept;
  final List<CourseTakenInput> coursesTaken;
  final List<String> doubleMajorDepts;
  final List<String> minorDepts;
  final int? academicYear;

  const CourseProgressDetailPage({
    super.key,
    required this.result,
    required this.program,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.waivers = const {},
    this.onWaiverChanged,
    this.verificationStatuses = const {},
    this.onVerificationChanged,
    this.pdfLink,
    this.courseSourceResolver,
    required this.selectedDept,
    required this.coursesTaken,
    required this.doubleMajorDepts,
    required this.minorDepts,
    this.academicYear,
  });

  @override
  State<CourseProgressDetailPage> createState() =>
      _CourseProgressDetailPageState();
}

class _CourseProgressDetailPageState extends State<CourseProgressDetailPage> {
  late bool _localIsFavorite;
  EligibilityResult? _localResult;
  late Map<String, List<String>> _localWaivers;
  late Map<String, VerificationStatus> _localVerificationStatuses;
  String? _localPdfLink;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _localIsFavorite = widget.isFavorite;
    _localWaivers = _deepCopyWaivers(widget.waivers);
    _localVerificationStatuses = Map<String, VerificationStatus>.from(
      widget.verificationStatuses,
    );
    _localPdfLink = widget.pdfLink;
    if (widget.result != null) {
      _localResult = widget.result;
    } else {
      _isLoading = true;
      _loadDataAndCompute();
    }
  }

  Future<void> _loadDataAndCompute() async {
    final programId = widget.program?.programId;
    final year = widget.academicYear ?? widget.result?.academicYear;

    if (_localPdfLink == null && widget.program != null) {
      ProgramLinkService.instance.getPdfLink(widget.program!.programName).then((
        link,
      ) {
        if (mounted) {
          setState(() {
            _localPdfLink = link;
          });
        }
      });
    }

    if (programId != null &&
        year != null &&
        _localVerificationStatuses.isEmpty) {
      final key = 'progress_verifications_${programId}_$year';
      final jsonStr = await StorageService.instance.read(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          final loaded = decoded.map(
            (k, v) => MapEntry(
              k,
              VerificationStatus.values.firstWhere(
                (e) => e.name == v,
                orElse: () => VerificationStatus.unfilled,
              ),
            ),
          );
          if (mounted) {
            setState(() {
              _localVerificationStatuses = loaded;
            });
          }
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _localResult = EligibilityChecker.checkEligibility(
          widget.program!,
          year!,
          null,
          widget.selectedDept,
          widget.coursesTaken,
          _localWaivers,
          widget.doubleMajorDepts,
          widget.minorDepts,
          _localVerificationStatuses,
        );
        _isLoading = false;
      });
    }
  }

  Map<String, List<String>> _deepCopyWaivers(
    Map<String, List<String>> original,
  ) {
    return original.map((k, v) => MapEntry(k, List<String>.from(v)));
  }

  void _recomputeResult() {
    if (widget.program == null || _localResult == null) return;
    setState(() {
      _localResult = EligibilityChecker.checkEligibility(
        widget.program!,
        _localResult!.academicYear,
        null,
        widget.selectedDept,
        widget.coursesTaken,
        _localWaivers,
        widget.doubleMajorDepts,
        widget.minorDepts,
        _localVerificationStatuses,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program?.programName ?? '學程進度'),
        backgroundColor: colorScheme.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colorScheme.primaryText,
        iconTheme: IconThemeData(color: colorScheme.primaryText),
        titleTextStyle: TextStyle(
          color: colorScheme.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
        actions: [
          if (widget.onFavoriteToggle != null)
            HoverIconButton(
              icon: Icon(
                _localIsFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
              ),
              color: _localIsFavorite
                  ? Colors.amber[600]
                  : colorScheme.primaryText,
              tooltip: _localIsFavorite ? '移除最愛' : '加入最愛',
              onPressed: () {
                widget.onFavoriteToggle?.call();
                setState(() {
                  _localIsFavorite = !_localIsFavorite;
                });
              },
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 14.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CourseProgressRightPanel(
              result: _localResult,
              program: widget.program,
              isFavorite: _localIsFavorite,
              onFavoriteToggle: () {
                widget.onFavoriteToggle?.call();
                setState(() {
                  _localIsFavorite = !_localIsFavorite;
                });
              },
              waivers: _localWaivers,
              onWaiverChanged: (subject, waiverId, checked) {
                widget.onWaiverChanged?.call(subject, waiverId, checked);
                setState(() {
                  if (checked) {
                    _localWaivers.putIfAbsent(subject, () => []);
                    if (!_localWaivers[subject]!.contains(waiverId)) {
                      _localWaivers[subject]!.add(waiverId);
                    }
                  } else {
                    _localWaivers[subject]?.remove(waiverId);
                    if (_localWaivers[subject]?.isEmpty ?? false) {
                      _localWaivers.remove(subject);
                    }
                  }
                });
                _recomputeResult();
              },
              verificationStatuses: _localVerificationStatuses,
              onVerificationChanged: (vKey, status) {
                widget.onVerificationChanged?.call(vKey, status);
                setState(() {
                  _localVerificationStatuses[vKey] = status;
                });
                _recomputeResult();
              },
              pdfLink: _localPdfLink,
              isLoading: _isLoading,
              courseSourceResolver: widget.courseSourceResolver,
            ),
          ),
        ),
      ),
    );
  }
}
