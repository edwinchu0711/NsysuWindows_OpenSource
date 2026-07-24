import 'package:flutter/material.dart';
import '../../../services/course_query_service.dart';
import '../../../services/course_evaluation_service.dart';
import '../../../theme/app_theme.dart';
import 'hoverable_course_name.dart';

class CourseSearchResultCard extends StatefulWidget {
  final CourseJsonData course;
  final bool isAdded;
  final VoidCallback onAddPressed;
  final Future<List<String>> Function(String) getCourseEvaluation;
  final Function(String) launchEvaluationSearch;
  final List<dynamic>? preloadedQuickReviews;

  const CourseSearchResultCard({
    super.key,
    required this.course,
    required this.isAdded,
    required this.onAddPressed,
    required this.getCourseEvaluation,
    required this.launchEvaluationSearch,
    this.preloadedQuickReviews,
  });

  @override
  State<CourseSearchResultCard> createState() => _CourseSearchResultCardState();
}

class _CourseSearchResultCardState extends State<CourseSearchResultCard> {


  String _formatClassTime(List<String> times) {
    if (times.length < 7) return times.join(', ');
    final dayNames = ["一", "二", "三", "四", "五", "六", "日"];
    List<String> formattedParts = [];
    for (int i = 0; i < 7; i++) {
      String p = times[i].trim();
      if (p.isNotEmpty) {
        String periods = p.split('').join(',');
        formattedParts.add("${dayNames[i]}$periods");
      }
    }
    return formattedParts.isEmpty ? "未定" : formattedParts.join(', ');
  }

  String _calculateProbability(CourseJsonData course) {
    if (course.remaining <= 0) return "0% (已滿)";
    double prob = course.remaining / course.select;
    if (course.select <= 0 || prob > 1) return "100%";
    return "${(prob * 100).toStringAsFixed(1)}%";
  }

  Widget _buildMiniInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.borderColor,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: Theme.of(context).colorScheme.subtitleText,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityChip(CourseJsonData course) {
    double prob = 1.0;
    if (course.remaining <= 0) {
      prob = 0.0;
    } else if (course.select > 0) {
      prob = course.remaining / course.select;
      if (prob > 1.0) prob = 1.0;
    }

    final isDark = Theme.of(context).colorScheme.isDark;
    Color backgroundColor;
    Color textColor;

    if (prob >= 0.7) {
      backgroundColor = isDark
          ? Colors.green[900]!.withValues(alpha: 0.3)
          : Colors.green[50]!;
      textColor = isDark ? Colors.green[200]! : Colors.green[800]!;
    } else if (prob >= 0.3) {
      backgroundColor = isDark
          ? Colors.orange[900]!.withValues(alpha: 0.3)
          : Colors.orange[50]!;
      textColor = isDark ? Colors.orange[200]! : Colors.orange[800]!;
    } else {
      backgroundColor = isDark
          ? Colors.red[900]!.withValues(alpha: 0.3)
          : Colors.red[50]!;
      textColor = isDark ? Colors.red[200]! : Colors.red[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pie_chart_outline, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            "機率: ${_calculateProbability(course)}",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
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
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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



  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final isAdded = widget.isAdded;
    final semStr = CourseQueryService.instance.currentSemester;
    List<String>? cached;
    if (semStr.length == 4) {
      final syear = semStr.substring(0, 3);
      final sem = semStr.substring(3, 4);
      cached = CourseEvaluationService.instance.getCachedEvaluation(
        year: syear,
        semester: sem,
        courseId: course.id,
      );
    }

    final hasQuickReviews =
        widget.preloadedQuickReviews != null &&
        widget.preloadedQuickReviews!.isNotEmpty;

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
      child: Container(
        decoration: const BoxDecoration(),
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
              children: [Expanded(child: HoverableCourseName(course: course))],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Icons.assignment_outlined,
                      course.compulsory ? "必修" : "選修",
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
                    _buildProbabilityChip(course),
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
                      onPressed: widget.onAddPressed,
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
                ).colorScheme.secondaryCardBackground.withValues(alpha: 0.5),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: cached != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: cached
                                    .map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6.0,
                                        ),
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
                                    )
                                    .toList(),
                              )
                            : FutureBuilder<List<String>>(
                                future: widget.getCourseEvaluation(course.id),
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
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: snapshot.data!
                                        .map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
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
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 12),
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
                        if (course.teacher != "待聘")
                          _buildActionButton(
                            icon: Icons.person_search,
                            label: "教授評價",
                            color: Colors.orangeAccent,
                            onTap: () =>
                                widget.launchEvaluationSearch(course.teacher),
                          ),
                        _buildActionButton(
                          icon: Icons.forum_outlined,
                          label: "課程評價",
                          color: Colors.purpleAccent,
                          onTap: () => widget.launchEvaluationSearch(
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
      ),
    );
  }
}
