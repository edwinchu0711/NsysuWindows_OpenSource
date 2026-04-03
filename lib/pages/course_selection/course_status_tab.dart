import 'package:flutter/material.dart';
import '../../services/course_selection_service.dart';

class CourseStatusTab extends StatelessWidget {
  final bool isLoading;
  final String message;
  final bool isSystemClosed;
  final List<CourseSelectionData> courses;
  final Future<void> Function() onRefresh;

  const CourseStatusTab({
    Key? key,
    required this.isLoading,
    required this.message,
    required this.isSystemClosed,
    required this.courses,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("目前沒有任何選課紀錄", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    double selectedCredits = 0;
    double registeringCredits = 0;

    List<CourseSelectionData> registeringList = [];
    List<CourseSelectionData> selectedList = [];
    List<CourseSelectionData> otherList = [];

    for (var course in courses) {
      double credit = double.tryParse(course.credits) ?? 0.0;
      if (course.status.contains("未選上")) {
        otherList.add(course);
      } else if (course.status.contains("選上")) {
        selectedCredits += credit;
        selectedList.add(course);
      } else if (course.status.contains("登記") || course.status.contains("加選")) {
        registeringCredits += credit;
        registeringList.add(course);
      }
    }

    double totalCredits = selectedCredits + registeringCredits;

    List<Widget> listChildren = [];
    listChildren.addAll(registeringList.map((c) => _buildCourseCard(c)));
    listChildren.addAll(selectedList.map((c) => _buildCourseCard(c)));

    if (otherList.isNotEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            children: [
              const Expanded(child: Divider(thickness: 1, color: Colors.black12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "以下為 未選上 / 退選 紀錄",
                  style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const Expanded(child: Divider(thickness: 1, color: Colors.black12)),
            ],
          ),
        ),
      );
      listChildren.addAll(otherList.map((c) => _buildCourseCard(c, isDimmed: true)));
    }

    return Column(
      children: [
        // 頂部統計面板
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("本學分期選課統計", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: "${selectedCredits.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                          const TextSpan(text: " 已選上  +  ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          TextSpan(
                            text: "${registeringCredits.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                          const TextSpan(text: " 登記中  =  ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          TextSpan(
                            text: "${totalCredits.toStringAsFixed(0)}",
                            style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 24),
                          ),
                          const TextSpan(text: " 總學分", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 已移除預覽課表按鈕
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: listChildren,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(CourseSelectionData course, {bool isDimmed = false}) {
    Color statusColor = Colors.grey;
    bool isRegistration = false;

    if (course.status.contains("退選") || course.status.contains("未選上")) {
      statusColor = Colors.grey;
    } else if (course.status.contains("選上")) {
      statusColor = Colors.green;
    } else if (course.status.contains("登記") || course.status.contains("加選")) {
      statusColor = Colors.deepOrange;
      isRegistration = true;
    }

    return Opacity(
      opacity: isDimmed ? 0.6 : 1.0, 
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDimmed ? Colors.grey[100]!.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDimmed ? Colors.transparent : Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      course.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  if (isRegistration) 
                    Row(
                      children: [
                        const Text("志願/權重 ", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(course.remarks ?? "0", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    )
                  else
                    Text(course.dept, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      course.name, 
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                        decoration: isDimmed ? TextDecoration.lineThrough : null,
                        color: isDimmed ? Colors.grey[600] : Colors.black87,
                      )
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text("${course.courseNo} • ${course.credits}學分 • ${course.grade}年級", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              const Divider(height: 16, color: Colors.black12),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(course.professor, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Expanded(child: Text(course.timeRoom, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoursePreviewPage extends StatelessWidget {
  final List<CourseSelectionData> courses;
  CoursePreviewPage({Key? key, required this.courses}) : super(key: key);

  final List<String> _allPeriods = ['A', '1', '2', '3', '4', 'B', '5', '6', '7', '8','9','C', 'D','E','F'];
  final Map<String, String> _timeMapping = {
    'A': '07:00\n07:50', '1': '08:10\n09:00', '2': '09:10\n10:00', '3': '10:10\n11:00',
    '4': '11:10\n12:00', 'B': '12:10\n13:00', '5': '13:10\n14:00', '6': '14:10\n15:00',
    '7': '15:10\n16:00', '8': '16:10\n17:00', '9': '17:10\n18:00', 'C': '18:20\n19:10',
    'D': '19:15\n20:05', 'E': '20:10\n21:00', 'F': '21:05\n21:55',
  };
  final List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final scheduleMap = _parseCoursesToSchedule();
    List<int> visibleDays = [0, 1, 2, 3, 4];
    if (_hasCourseInDay(scheduleMap, 5)) visibleDays.add(5);
    if (_hasCourseInDay(scheduleMap, 6)) visibleDays.add(6);
    List<String> visiblePeriods = _calculateVisiblePeriods(scheduleMap);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: null, // 移除 AppBar
      body: Column(
        children: [
          // 自定義桌面 Header
          _buildDesktopHeader(context),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        height: 45,
                        color: Colors.grey[50],
                        child: Row(
                          children: [
                            const SizedBox(width: 60, child: Center(child: Text("時段", style: TextStyle(fontSize: 12, color: Colors.grey)))),
                            ...visibleDays.map((dayIndex) => Expanded(
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey[200]!))),
                                child: Text(_weekDays[dayIndex], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            )),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: Colors.black12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: visiblePeriods.map((period) {
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 60,
                                      constraints: const BoxConstraints(minHeight: 80),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        border: Border(bottom: BorderSide(color: Colors.grey[100]!), right: BorderSide(color: Colors.grey[200]!)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(period, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                                          const SizedBox(height: 4),
                                          Text(_timeMapping[period] ?? "", style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
                                        ],
                                      ),
                                    ),
                                    ...visibleDays.map((dayIndex) {
                                      final coursesInThisSlot = scheduleMap[dayIndex]?[period] ?? [];
                                      return Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey[100]!), left: BorderSide(color: Colors.grey[100]!)),
                                          ),
                                          padding: const EdgeInsets.all(3),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: coursesInThisSlot.isEmpty ? [] : coursesInThisSlot.map((c) => _buildCourseCell(c)).toList(),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }).toList(),
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

  Widget _buildDesktopHeader(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 20, top: 25, bottom: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text("選課課表預覽", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCell(CourseSelectionData course) {
    Color bgColor;
    if (course.status.contains("選上")) {
      bgColor = Colors.green[500]!; 
    } else if (course.status.contains("退選") || course.status.contains("未選上")) {
      bgColor = Colors.grey[400]!;
    } else {
      bgColor = Colors.orange[400]!;
    }

    String room = _parseRoomName(course.timeRoom);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60), 
      margin: const EdgeInsets.only(bottom: 2), 
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            course.name,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          if (room.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(room, style: const TextStyle(fontSize: 9, color: Colors.white70), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ]
        ],
      ),
    );
  }

  List<String> _calculateVisiblePeriods(Map<int, Map<String, List<CourseSelectionData>>> map) {
    List<String> result = [];
    List<String> corePeriods = ['1', '2', '3', '4', 'B', '5', '6', '7', '8', '9','C'];
    if (_checkPeriodHasCourse(map, 'A')) result.add('A');
    result.addAll(corePeriods);
    if (_checkPeriodHasCourse(map, 'F')) { result.addAll(['D', 'E', 'F']); }
    else if (_checkPeriodHasCourse(map, 'E')) { result.addAll(['D', 'E']); }
    else if (_checkPeriodHasCourse(map, 'D')) { result.addAll(['D']); }
    return result;
  }

  bool _checkPeriodHasCourse(Map<int, Map<String, List<CourseSelectionData>>> map, String period) {
    for (var dayData in map.values) { if (dayData.containsKey(period) && dayData[period]!.isNotEmpty) return true; }
    return false;
  }

  bool _hasCourseInDay(Map<int, Map<String, List<CourseSelectionData>>> map, int dayIndex) {
    return map.containsKey(dayIndex) && map[dayIndex]!.isNotEmpty;
  }

  String _parseRoomName(String timeRoom) {
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(timeRoom);
    return match?.group(1)?.trim() ?? ""; 
  }

  Map<int, Map<String, List<CourseSelectionData>>> _parseCoursesToSchedule() {
    Map<int, Map<String, List<CourseSelectionData>>> map = {};
    for (var course in courses) {
      if (course.status.contains("退選") || course.status.contains("未選上")) continue;
      if (course.timeRoom.isEmpty) continue;
      String rawTimeOnly = course.timeRoom.replaceAll(RegExp(r'[(\uff08].*?[)\uff09]'), '');
      int? currentDay; 
      for (int i = 0; i < rawTimeOnly.length; i++) {
        String char = rawTimeOnly[i];
        int dayIndex = _weekDays.indexOf(char);
        if (dayIndex != -1) { currentDay = dayIndex; continue; }
        if (_allPeriods.contains(char)) {
          if (currentDay != null) {
            if (!map.containsKey(currentDay)) map[currentDay] = {};
            if (!map[currentDay]!.containsKey(char)) map[currentDay]![char] = [];
            if (!map[currentDay]![char]!.contains(course)) map[currentDay]![char]!.add(course);
          }
        }
      }
    }
    return map;
  }
}