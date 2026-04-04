import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';// ✅ 新增：用於開啟外部連結
import '../../../models/course_model.dart';
import '../../../models/custom_event_model.dart';
import '../../../services/course_query_service.dart'; // ✅ 新增：用於獲取學期資訊
import '../../../theme/app_theme.dart';

class AssistantLeftPane extends StatelessWidget {
  final List<Course> assistantCourses;
  final List<CustomEvent> customEvents;
  final List<String> fullWeekDays;
  final String totalCredits;
  final Function(Course) onRemoveCourse;
  final Function(String) onRemoveEvent;
  final VoidCallback onClearAll;
  final Function(Course) onFormatTime; // Callback for _formatCourseTimeWithRange
  
  // 新增區域：詳細資訊與選擇狀態
  final Course? selectedCourse;
  final CustomEvent? selectedEvent;
  final VoidCallback onClearSelection;

  const AssistantLeftPane({
    Key? key,
    required this.assistantCourses,
    required this.customEvents,
    required this.fullWeekDays,
    required this.totalCredits,
    required this.onRemoveCourse,
    required this.onRemoveEvent,
    required this.onClearAll,
    required this.onFormatTime,
    this.selectedCourse,
    this.selectedEvent,
    required this.onClearSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (selectedCourse != null) {
      return _buildCourseDetailView(context, selectedCourse!);
    }
    if (selectedEvent != null) {
      return _buildEventDetailView(context, selectedEvent!);
    }

    return Container(
      color: colorScheme.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("管理清單", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: "清除全部",
                onPressed: onClearAll,
                mouseCursor: SystemMouseCursors.click,
              )
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colorScheme.secondaryCardBackground, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.accentBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("目前統計", style: TextStyle(fontSize: 12, color: colorScheme.bodyText)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "$totalCredits 學分 / ${assistantCourses.length} 門課",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: (assistantCourses.isEmpty && customEvents.isEmpty)
                ? const Center(child: Text("目前沒有任何模擬項目", style: TextStyle(color: Colors.grey)))
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: ListView(
                        children: [
                          if (assistantCourses.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text("正規課程", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                            ...assistantCourses.map((c) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: ListTile(
                                  dense: true,
                                  title: Text(c.name.split('\n')[0], style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("${c.code} / ${_extractRoomLocation(c.location)}", style: TextStyle(color: colorScheme.bodyText)),
                                      Text(_formatShortTime(c), style: TextStyle(color: colorScheme.bodyText, fontSize: 11)),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () => onRemoveCourse(c),
                                    mouseCursor: SystemMouseCursors.click,
                                  ),
                                ),
                              ),
                            )),
                          ],
                          if (customEvents.isNotEmpty) ...[
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text("其他行程", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                            ),
                            ...customEvents.map((e) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: ListTile(
                                  dense: true,
                                  title: Text(e.title, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
                                  subtitle: Text("星期${fullWeekDays[e.day - 1]} (${e.periods.join(', ')}節)\n${e.details}", style: TextStyle(color: colorScheme.bodyText)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () => onRemoveEvent(e.id),
                                    mouseCursor: SystemMouseCursors.click,
                                  ),
                                ),
                              ),
                            )),
                          ],
                        ],
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseDetailView(BuildContext context, Course course) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onClearSelection,
              ),
              Text("詳情", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(course.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.accentBlue)),
                        ),
                        if (course.english)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: colorScheme.subtleBackground, borderRadius: BorderRadius.circular(4)),
                            child: Text("英語授課", style: TextStyle(color: colorScheme.subtitleText, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailInfoRow(Icons.tag, "課號", course.code),
                    _buildDetailInfoRow(Icons.grade, "學分", "${course.credits} (${course.required})"),
                    _buildDetailInfoRow(Icons.person, "教授", course.professor),
                    _buildDetailInfoRow(Icons.room, "地點", _extractRoomLocation(course.location)),
                    _buildDetailInfoRow(Icons.access_time, "時間", onFormatTime(course)),
                    
                    if (course.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text("對應學程", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: course.tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryCardBackground, 
                            borderRadius: BorderRadius.circular(4), 
                            border: Border.all(color: colorScheme.borderColor)
                          ),
                          child: Text(t, style: TextStyle(fontSize: 11, color: colorScheme.accentBlue)),
                        )).toList(),
                      ),
                    ],
  
                    if (course.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text("課程備註", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      Text(course.description, style: TextStyle(fontSize: 14, color: colorScheme.primaryText)),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text("評價與連結", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionBtn(
                            icon: Icons.person_search, 
                            label: "教授評價", 
                            color: Colors.orange[700]!,
                            onTap: () => _launchEvaluationSearch(course.professor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionBtn(
                            icon: Icons.forum_outlined, 
                            label: "課程評價", 
                            color: Colors.purple[700]!,
                            onTap: () => _launchEvaluationSearch(course.name),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActionBtn(
                      icon: Icons.description_outlined, 
                      label: "課程詳細資料 (教學大綱)", 
                      color: colorScheme.accentBlue,
                      onTap: () => _launchOutline(course.code),
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onRemoveCourse(course),
              icon: const Icon(Icons.delete_outline),
              label: const Text("移除此課程"),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.isDark ? Colors.red.withOpacity(0.1) : Colors.red[50],
                foregroundColor: Colors.red,
                side: BorderSide(color: colorScheme.isDark ? Colors.red.withOpacity(0.5) : Colors.red),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEventDetailView(BuildContext context, CustomEvent event) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onClearSelection,
              ),
              Text("行程詳情", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.subtitleText)),
                    const SizedBox(height: 16),
                    _buildDetailInfoRow(Icons.access_time, "時間", "星期${fullWeekDays[event.day - 1]} (${event.periods.join(', ')}節)"),
                    if (event.location.isNotEmpty) _buildDetailInfoRow(Icons.room, "地點", event.location),
                    if (event.details.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text("內容備註：", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(event.details, style: TextStyle(fontSize: 15, color: colorScheme.primaryText)),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onRemoveEvent(event.id),
              icon: const Icon(Icons.delete_outline),
              label: const Text("刪除此行程"),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.isDark ? Colors.red.withOpacity(0.1) : Colors.red[50],
                foregroundColor: Colors.red,
                side: BorderSide(color: colorScheme.isDark ? Colors.red.withOpacity(0.5) : Colors.red),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDetailInfoRow(IconData icon, String label, String value) {
    return Builder(
      builder: (context) {
        final curColorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: curColorScheme.subtitleText),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: curColorScheme.bodyText)),
                    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: curColorScheme.primaryText)),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // ✅ 新增：詳情頁專用操作按鈕樣式
  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap, bool isFullWidth = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: isFullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  void _launchEvaluationSearch(String keyword) async {
    if (keyword.isEmpty) return;
    
    // 清理關鍵字：保留至最後一個中文字 (避免課程名稱包含中英雙語導致搜尋困難)
    String searchKeyword = keyword;
    final lastChineseIdx = keyword.lastIndexOf(RegExp(r'[\u4e00-\u9fa5]'));
    if (lastChineseIdx != -1) {
      searchKeyword = keyword.substring(0, lastChineseIdx + 1);
    }

    final query = '中山大學 "$searchKeyword" DCard | PTT';
    final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _launchOutline(String courseId) async {
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return;
    final syear = semStr.substring(0, 3);
    final sem = semStr.substring(3, 4);
    final url = Uri.parse('https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }


  String _formatShortTime(Course c) {
    if (c.parsedTimes.isEmpty) return "";
    Map<int, List<String>> dayMap = {};
    for (var t in c.parsedTimes) {
      dayMap.putIfAbsent(t.day, () => []).add(t.period);
    }
    
    List<String> result = [];
    var sortedDays = dayMap.keys.toList()..sort();
    for (var day in sortedDays) {
      String dayStr = fullWeekDays[day - 1];
      String periods = dayMap[day]!.join('');
      result.add("週$dayStr($periods)");
    }
    return result.join(' ');
  }

  String _extractRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "地點不明";
    // 尋找傳統弧括號 (B101) 或全型括號 （B101）
    final regex = RegExp(r'[\(\uff08](.*?)[\)\uff09]');
    final match = regex.firstMatch(rawRoom);
    if (match != null) {
      String content = match.group(1)?.trim() ?? "";
      return content.isNotEmpty ? content : "地點不明";
    }
    return "地點不明";
  }
}
