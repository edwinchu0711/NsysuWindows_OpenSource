import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/course_query_service.dart'; // 請確認路徑是否正確
import 'package:http/http.dart' as http;

class CourseSearchPickerPage extends StatefulWidget {
  final bool isEmbedded;
  final Function(String)? onCourseSelected;
  final VoidCallback? onCancel;

  const CourseSearchPickerPage({
    Key? key,
    this.isEmbedded = false,
    this.onCourseSelected,
    this.onCancel,
  }) : super(key: key);

  @override
  State<CourseSearchPickerPage> createState() => _CourseSearchPickerPageState();
}

class _CourseSearchPickerPageState extends State<CourseSearchPickerPage> {
  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  final Map<String, List<String>> _evaluationCache = {};

  final TextEditingController _mergedQueryCtrl = TextEditingController();
  Set<String> _selectedDays = {};
  Set<String> _selectedPeriods = {};

  @override
  void dispose() {
    _mergedQueryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: const Text(
                    "搜尋課程",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                if (widget.onCancel != null)
                  TextButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("取消"),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 搜尋表單
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildInlineSearchForm(),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          // 結果列表
          Expanded(
            child: ColoredBox(
              color: Colors.grey[50]!,
              child: _buildSearchResults(),
            ),
          ),
        ],
      );
    }

    String semDisplay = "";

    return Scaffold(
      appBar: AppBar(
        title: Text("$semDisplay 選擇課程"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildInlineSearchForm(),
          ),
          const Divider(height: 1),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildInlineSearchForm() {
    return Column(
      children: [
        // 第一行：合併搜尋
        _buildTextField(
          "合併關鍵字搜尋",
          _mergedQueryCtrl,
          hint: "可用空白區隔多個關鍵字，如：資工 物件",
        ),
        const SizedBox(height: 12),
        // 第二行：篩選器與按鈕
        Row(
          children: [
            Expanded(
              child: _buildMultiSelectDropdown(
                label: "星期",
                values: _selectedDays,
                options: const {
                  "1": "一",
                  "2": "二",
                  "3": "三",
                  "4": "四",
                  "5": "五",
                  "6": "六",
                  "7": "日",
                },
                onChanged: (v) => setState(() => _selectedDays = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMultiSelectDropdown(
                label: "節次",
                values: _selectedPeriods,
                options: const {
                  "A": "A (07:00)",
                  "1": "1 (08:10)",
                  "2": "2 (09:10)",
                  "3": "3 (10:10)",
                  "4": "4 (11:10)",
                  "B": "B (12:10)",
                  "5": "5 (13:10)",
                  "6": "6 (14:10)",
                  "7": "7 (15:10)",
                  "8": "8 (16:10)",
                  "9": "9 (17:10)",
                  "C": "C (18:20)",
                },
                onChanged: (v) => setState(() => _selectedPeriods = v),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.search, size: 16),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  label: const Text("搜尋", style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isQueryLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("搜尋中...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "輸入關鍵字並點擊搜尋按鈕",
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text("找不到符合條件的課程"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final course = _searchResults[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      course.name.split('\n')[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildMiniInfoChip(Icons.person_outline, course.teacher),
                    _buildMiniInfoChip(Icons.tag, course.id),
                    _buildMiniInfoChip(
                      Icons.account_balance_outlined,
                      course.department.split(' ')[0],
                    ),
                    if (course.english)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "英語授課",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  if (widget.isEmbedded && widget.onCourseSelected != null) {
                    widget.onCourseSelected!(course.id);
                  } else {
                    Navigator.pop(context, course.id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text("選取", style: TextStyle(fontSize: 13)),
              ),
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              Icons.grade_outlined,
                              "學分",
                              "${course.credit} 學分",
                            ),
                          ),
                          Expanded(
                            child: _buildDetailRow(
                              Icons.group_outlined,
                              "對象",
                              "${course.grade}年級 ${course.className}",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.room_outlined,
                        "教室",
                        _parseRoomLocation(course.room),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "上課時間",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildTimeDisplay(course.classTime),
                      if (course.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "相關學程",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: course.tags
                              .map(
                                (p) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.blue[100]!,
                                    ),
                                  ),
                                  child: Text(
                                    p,
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (course.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "課程備註",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          course.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        "評分方式",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<String>>(
                        future: _getCourseEvaluation(course.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Text(
                              "無法取得資料",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: snapshot.data!
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: Colors.blueGrey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 與 AssistantAddCoursePage 共用的私有方法組 ---

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDisplay(List<String> times) {
    final days = ["一", "二", "三", "四", "五", "六", "日"];
    List<Widget> timeWidgets = [];
    for (int i = 0; i < times.length && i < 7; i++) {
      if (times[i].isNotEmpty) {
        timeWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "星期${days[i]}",
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "第 ${times[i]} 節",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (timeWidgets.isEmpty)
      return const Text("無時間資訊", style: TextStyle(color: Colors.grey));
    return Column(children: timeWidgets);
  }

  Future<void> _performSearch() async {
    setState(() {
      _isQueryLoading = true;
      _hasSearched = true;
    });
    try {
      await CourseQueryService.instance.getCourses();

      final results = CourseQueryService.instance.search(
        query: _mergedQueryCtrl.text.trim(),
        days: _selectedDays.toList(),
        periods: _selectedPeriods.toList(),
      );
      setState(() {
        _searchResults = results;
        _isQueryLoading = false;
      });
    } catch (e) {
      setState(() => _isQueryLoading = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("搜尋失敗: $e")));
    }
  }

  Widget _buildMultiSelectDropdown({
    required String label,
    required Set<String> values,
    required Map<String, String> options,
    required Function(Set<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        const SizedBox(height: 2),
        InkWell(
          onTap: () async {
            final Set<String>? newValues = await showDialog<Set<String>>(
              context: context,
              builder: (ctx) {
                Set<String> tempSet = Set.from(values);
                return StatefulBuilder(
                  builder: (ctx, setInnerState) {
                    return AlertDialog(
                      title: Text("選擇$label"),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: options.entries.map((e) {
                            return CheckboxListTile(
                              title: Text(e.value),
                              value: tempSet.contains(e.key),
                              onChanged: (val) {
                                setInnerState(() {
                                  if (val == true)
                                    tempSet.add(e.key);
                                  else
                                    tempSet.remove(e.key);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("取消"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, tempSet),
                          child: const Text("確定"),
                        ),
                      ],
                    );
                  },
                );
              },
            );
            if (newValues != null) onChanged(newValues);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    values.isEmpty
                        ? "全部"
                        : values.map((e) => options[e]).join(', '),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMiniInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  String _parseRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "不明";
    final RegExp regex = RegExp(r'[(\uff08]([^)\uff09]*)[)\uff09]');
    final match = regex.firstMatch(rawRoom);
    if (match != null) return match.group(1)?.trim() ?? "不明";
    return "不明";
  }

  Future<List<String>> _getCourseEvaluation(String courseId) async {
    if (_evaluationCache.containsKey(courseId))
      return _evaluationCache[courseId]!;
    final semStr = CourseQueryService.instance.currentSemester;
    if (semStr.length != 4) return ["無法取得學期資訊"];
    final syear = semStr.substring(0, 3);
    final sem = semStr.substring(3, 4);
    final url = Uri.parse(
      'https://selcrs.nsysu.edu.tw/menu5/showoutline.asp?SYEAR=$syear&SEM=$sem&CrsDat=$courseId',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String html = utf8.decode(response.bodyBytes, allowMalformed: true);
        final RegExp exp = RegExp(
          r'SS4_\d+1[^>]*>([^<]*)</span>[^<]*<span[^>]*SS4_\d+2[^>]*>([^<]*)</span>',
          caseSensitive: false,
        );
        final matches = exp.allMatches(html);
        List<String> evals = [];
        int index = 1;
        for (var match in matches) {
          String item = match.group(1)?.trim() ?? "";
          String pct = match.group(2)?.trim() ?? "";
          if (item.isNotEmpty) {
            evals.add('$index. $item：${pct.isNotEmpty ? pct : "0"}%');
            index++;
          }
        }
        if (evals.isEmpty) evals.add("尚無評分方式資料");
        _evaluationCache[courseId] = evals;
        return evals;
      }
    } catch (e) {
      return ["載入失敗"];
    }
    return ["查無資料"];
  }
}
