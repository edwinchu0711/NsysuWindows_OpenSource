import 'package:flutter/material.dart';
import '../services/ai_personalization_service.dart';
import '../theme/app_theme.dart';
import 'hover_icon_button.dart';

class CourseProgressPassedCoursesPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onStartManualSync;

  const CourseProgressPassedCoursesPanel({
    super.key,
    required this.onClose,
    required this.onStartManualSync,
  });

  @override
  State<CourseProgressPassedCoursesPanel> createState() =>
      _CourseProgressPassedCoursesPanelState();
}

class _CourseProgressPassedCoursesPanelState
    extends State<CourseProgressPassedCoursesPanel> {
  final _searchQueryNotifier = ValueNotifier<String>('');
  final _courseService = AiPersonalizationService.instance;

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已修課程',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _courseService.isLoadingNotifier,
                      builder: (context, isLoading, _) {
                        return isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.accentBlue,
                                ),
                              )
                            : HoverIconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                color: colorScheme.accentBlue,
                                onPressed: widget.onStartManualSync,
                                padding: 6,
                              );
                      },
                    ),
                    const SizedBox(width: 8),
                    HoverIconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: widget.onClose,
                      color: colorScheme.subtitleText,
                      padding: 6,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Sync status loading message
          ValueListenableBuilder<bool>(
            valueListenable: _courseService.isLoadingNotifier,
            builder: (context, isLoading, _) {
              if (!isLoading) return const SizedBox.shrink();
              return ValueListenableBuilder<String>(
                valueListenable: _courseService.statusMessageNotifier,
                builder: (context, statusMsg, _) {
                  return Container(
                    width: double.infinity,
                    color: colorScheme.accentBlue.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 20,
                    ),
                    child: Text(
                      statusMsg.isNotEmpty ? statusMsg : "正在載入選課資料...",
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.accentBlue,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              );
            },
          ),
          // Static Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: colorScheme.timetableHeader,
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    '課程名稱',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '開課科系',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '學分',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '分數',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '狀態',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<CourseHistoryResult>>(
              valueListenable: _courseService.resultsNotifier,
              builder: (context, allHistory, _) {
                if (allHistory.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_late_outlined,
                          size: 48,
                          color: colorScheme.subtitleText.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '尚無已修課程資料',
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.subtitleText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<bool>(
                          valueListenable: _courseService.isLoadingNotifier,
                          builder: (context, isLoading, _) {
                            if (isLoading) return const SizedBox.shrink();
                            return ElevatedButton.icon(
                              onPressed: widget.onStartManualSync,
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text('立即同步'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.accentBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                return ValueListenableBuilder<String>(
                  valueListenable: _searchQueryNotifier,
                  builder: (context, query, _) {
                    // Filter
                    final filtered = allHistory.where((c) {
                      if (query.isEmpty) return true;
                      final q = query.toLowerCase();
                      return c.courseName.toLowerCase().contains(q) ||
                          c.courseNo.toLowerCase().contains(q) ||
                          c.department.toLowerCase().contains(q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            '找不到符合的課程',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.subtitleText,
                            ),
                          ),
                        ),
                      );
                    }

                    final Map<String, List<CourseHistoryResult>> grouped = {};
                    for (var c in filtered) {
                      grouped.putIfAbsent(c.semester, () => []).add(c);
                    }
                    final sortedSemesters = grouped.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: sortedSemesters.length,
                      itemBuilder: (context, index) {
                        final sem = sortedSemesters[index];
                        final courses = grouped[sem] ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              color: colorScheme.secondaryCardBackground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              child: Text(
                                sem,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                            ),
                            ...courses.map((c) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: colorScheme.borderColor,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Course Name & No
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            c.courseName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primaryText,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Department
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        c.department,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.bodyText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Credits
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        c.credits,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.primaryText,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    // Score
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        c.score,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: c.passed
                                              ? (colorScheme.isDark
                                                    ? Colors.greenAccent
                                                    : Colors.green.shade700)
                                              : Colors.redAccent,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    // Status
                                    SizedBox(
                                      width: 80,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: c.passed
                                                ? colorScheme.successContainer
                                                : (colorScheme.isDark
                                                      ? Colors.red.withValues(
                                                          alpha: 0.2,
                                                        )
                                                      : Colors.red.shade50),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            c.passed ? '已通過' : '未通過',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: c.passed
                                                  ? (colorScheme.isDark
                                                        ? Colors.greenAccent
                                                        : Colors.green.shade800)
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CourseProgressPassedCoursesBottomSheet extends StatefulWidget {
  final VoidCallback onStartManualSync;

  const CourseProgressPassedCoursesBottomSheet({
    super.key,
    required this.onStartManualSync,
  });

  @override
  State<CourseProgressPassedCoursesBottomSheet> createState() =>
      _CourseProgressPassedCoursesBottomSheetState();
}

class _CourseProgressPassedCoursesBottomSheetState
    extends State<CourseProgressPassedCoursesBottomSheet> {
  final _searchQueryNotifier = ValueNotifier<String>('');
  final _courseService = AiPersonalizationService.instance;

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已修課程',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _courseService.isLoadingNotifier,
                      builder: (context, isLoading, _) {
                        return isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.accentBlue,
                                ),
                              )
                            : HoverIconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                color: colorScheme.accentBlue,
                                onPressed: widget.onStartManualSync,
                                padding: 6,
                              );
                      },
                    ),
                    const SizedBox(width: 8),
                    HoverIconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: colorScheme.subtitleText,
                      padding: 6,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Sync status loading message
          ValueListenableBuilder<bool>(
            valueListenable: _courseService.isLoadingNotifier,
            builder: (context, isLoading, _) {
              if (!isLoading) return const SizedBox.shrink();
              return ValueListenableBuilder<String>(
                valueListenable: _courseService.statusMessageNotifier,
                builder: (context, statusMsg, _) {
                  return Container(
                    width: double.infinity,
                    color: colorScheme.accentBlue.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 20,
                    ),
                    child: Text(
                      statusMsg.isNotEmpty ? statusMsg : "正在載入選課資料...",
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.accentBlue,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              );
            },
          ),
          // Static Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: colorScheme.timetableHeader,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    '課程名稱 / 科系',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '學分',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '成績/狀態',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.subtitleText,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ValueListenableBuilder<List<CourseHistoryResult>>(
              valueListenable: _courseService.resultsNotifier,
              builder: (context, allHistory, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: _searchQueryNotifier,
                  builder: (context, query, _) {
                    // Filter
                    final filtered = allHistory.where((c) {
                      if (query.isEmpty) return true;
                      final q = query.toLowerCase();
                      return c.courseName.toLowerCase().contains(q) ||
                          c.courseNo.toLowerCase().contains(q) ||
                          c.department.toLowerCase().contains(q);
                    }).toList();

                    if (allHistory.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.assignment_late_outlined,
                              size: 48,
                              color: colorScheme.subtitleText.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '尚無已修課程資料',
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.subtitleText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ValueListenableBuilder<bool>(
                              valueListenable: _courseService.isLoadingNotifier,
                              builder: (context, isLoading, _) {
                                if (isLoading) return const SizedBox.shrink();
                                return ElevatedButton.icon(
                                  onPressed: widget.onStartManualSync,
                                  icon: const Icon(Icons.sync_rounded),
                                  label: const Text('立即同步'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.accentBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            '找不到符合的課程',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.subtitleText,
                            ),
                          ),
                        ),
                      );
                    }

                    // Group by semester, sorted descending
                    final Map<String, List<CourseHistoryResult>> grouped = {};
                    for (var c in filtered) {
                      grouped.putIfAbsent(c.semester, () => []).add(c);
                    }
                    final sortedSemesters = grouped.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: sortedSemesters.length,
                      itemBuilder: (context, index) {
                        final sem = sortedSemesters[index];
                        final courses = grouped[sem] ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Semester Header
                            Container(
                              width: double.infinity,
                              color: colorScheme.secondaryCardBackground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              child: Text(
                                sem,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                            ),
                            // Courses
                            ...courses.map((c) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: colorScheme.borderColor,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Course Name & No & Dept
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.courseName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primaryText,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.department,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.subtitleText,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Credits
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        c.credits,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.primaryText,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    // Score & Status
                                    SizedBox(
                                      width: 80,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            c.score,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: c.passed
                                                  ? (colorScheme.isDark
                                                        ? Colors.greenAccent
                                                        : Colors.green.shade700)
                                                  : Colors.redAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.passed ? '已通過' : '未通過',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: c.passed
                                                  ? (colorScheme.isDark
                                                        ? Colors.greenAccent
                                                        : Colors.green.shade800)
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
