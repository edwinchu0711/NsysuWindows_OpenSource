import 'package:flutter/material.dart';
import '../models/program_model.dart';
import '../theme/app_theme.dart';
import '../utils/completion_rate.dart';
import '../widgets/staggered_appear.dart';
import '../widgets/progress_header_widget.dart';
import '../widgets/eligibility_banner_widget.dart';
import '../widgets/special_notes_widget.dart';
import '../widgets/own_departments_info_widget.dart';
import '../widgets/tag_details_widget.dart';
import '../widgets/cross_dept_verification_widget.dart';
import '../widgets/waiver_section_widget.dart';
import '../widgets/group_card_widget.dart';

class CourseProgressRightPanel extends StatefulWidget {
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
  final bool isLoading;
  final CourseSourceResolver? courseSourceResolver;

  const CourseProgressRightPanel({
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
    this.isLoading = false,
    this.courseSourceResolver,
  });

  @override
  State<CourseProgressRightPanel> createState() =>
      _CourseProgressRightPanelState();
}

class _CourseProgressRightPanelState extends State<CourseProgressRightPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(CourseProgressRightPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      // Scroll to top when switching programs
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isLoading) {
      return _buildSkeletonLoader(colorScheme);
    }

    if (widget.result == null) {
      return _buildEmptyState(colorScheme);
    }

    if (widget.result!.error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                widget.result!.error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final completionRate = computeEffectiveCompletionRate(widget.result!);
    final completionRange = widget.result!.completionRange;

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        key: ValueKey('${widget.result?.programId ?? widget.program?.programId ?? 'loading'}_${widget.result?.academicYear ?? widget.program?.versions.first.academicYear ?? 0}'),
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggeredAppear(
              delayMs: 0,
              child: ProgressHeaderWidget(
                result: widget.result!,
                completionRate: completionRate,
                completionRange: completionRange,
                isFavorite: widget.isFavorite,
                onFavoriteToggle: widget.onFavoriteToggle,
                pdfLink: widget.pdfLink,
              ),
            ),
            const SizedBox(height: 16),
            StaggeredAppear(
              delayMs: 80,
              child: EligibilityBannerWidget(result: widget.result!),
            ),
            // Special notes section
            if (widget.result!.specialNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              StaggeredAppear(
                delayMs: 120,
                child: SpecialNotesWidget(notes: widget.result!.specialNotes),
              ),
            ],
            if (widget.program != null) ...[
              const SizedBox(height: 12),
              StaggeredAppear(
                delayMs: 160,
                child: WaiverSectionWidget(
                  program: widget.program!,
                  selectedYear: widget.result?.academicYear,
                  waivers: widget.waivers,
                  onWaiverChanged: widget.onWaiverChanged,
                ),
              ),
            ],
            if (widget.result!.ownDepartments.length > 1) ...[
              const SizedBox(height: 12),
              StaggeredAppear(
                delayMs: 240,
                child: OwnDepartmentsInfoWidget(
                  ownDepartments: widget.result!.ownDepartments,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.result!.tagDetails.isNotEmpty) ...[
              StaggeredAppear(
                delayMs: 320,
                child: TagDetailsWidget(
                  tagDetails: widget.result!.tagDetails,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.result!.crossDeptVerifications.isNotEmpty) ...[
              StaggeredAppear(
                delayMs: 400,
                child: CrossDeptVerificationWidget(
                  verifications: widget.result!.crossDeptVerifications,
                  verificationStatuses: widget.verificationStatuses,
                  onVerificationChanged: widget.onVerificationChanged,
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...widget.result!.groups.asMap().entries.map(
              (entry) => StaggeredAppear(
                delayMs: 400 + entry.key * 50,
                child: GroupCardWidget(
                  group: entry.value,
                  colorScheme: colorScheme,
                  verificationStatuses: widget.verificationStatuses,
                  onVerificationChanged: widget.onVerificationChanged,
                  waivers: widget.waivers,
                  onWaiverChanged: widget.onWaiverChanged,
                  courseSourceResolver: widget.courseSourceResolver,
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.borderColor),
            ),
            child: Row(
              children: [
                const SkeletonWidget(width: 100, height: 100, borderRadius: 50),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonWidget(width: 150, height: 20),
                      const SizedBox(height: 8),
                      const SkeletonWidget(width: 80, height: 14),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          SkeletonWidget(width: 70, height: 24),
                          SizedBox(width: 8),
                          SkeletonWidget(width: 70, height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Banner Skeleton
          const SkeletonWidget(width: double.infinity, height: 48, borderRadius: 8),
          const SizedBox(height: 16),
          // Groups Skeletons
          const SkeletonWidget(width: double.infinity, height: 120, borderRadius: 12),
          const SizedBox(height: 12),
          const SkeletonWidget(width: double.infinity, height: 160, borderRadius: 12),
          const SizedBox(height: 12),
          const SkeletonWidget(width: double.infinity, height: 100, borderRadius: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: colorScheme.subtitleText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '請從左側選擇一個學程',
            style: TextStyle(fontSize: 16, color: colorScheme.subtitleText),
          ),
        ],
      ),
    );
  }
}

class SkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonWidget> createState() => _SkeletonWidgetState();
}

class _SkeletonWidgetState extends State<SkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.isDark;
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? Colors.white12 : Colors.black12,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}