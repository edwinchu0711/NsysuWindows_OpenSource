import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/course_query_service.dart';
import '../../../theme/app_theme.dart';

class HoverableCourseName extends StatefulWidget {
  final CourseJsonData course;
  const HoverableCourseName({super.key, required this.course});

  @override
  State<HoverableCourseName> createState() => _HoverableCourseNameState();
}

class _HoverableCourseNameState extends State<HoverableCourseName> {
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
