import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_model.dart'; // 請確認路徑
import 'package:flutter/services.dart';

class AssistantExportPage extends StatefulWidget {
  final bool isSubPane;
  const AssistantExportPage({Key? key, this.isSubPane = false})
    : super(key: key);

  @override
  State<AssistantExportPage> createState() => _AssistantExportPageState();
}

class _AssistantExportPageState extends State<AssistantExportPage> {
  List<Course> _assistantCourses = [];
  Set<String> _selectedCourseIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssistantCourses();
  }

  Future<void> _loadAssistantCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('assistant_courses');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _assistantCourses = decoded
              .map((v) => Course.fromJson(Map<String, dynamic>.from(v)))
              .toList();
          // 預設全選
          _selectedCourseIds = _assistantCourses.map((c) => c.code).toSet();
        });
      }
    } catch (e) {
      print("讀取助手課表失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 執行匯出
  Future<void> _exportToCart() async {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請至少選擇一門課程")));
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 根據 CourseQueryTab 的需求，準備 JSON 資料
      List<Map<String, dynamic>> exportList = _assistantCourses
          .where((c) => _selectedCourseIds.contains(c.code))
          .map(
            (c) => {
              'id': c.code,
              'name': c.name,
              'points': "0",
              'originalData': c.toJson(), // 存入原始資料以便後續顯示
            },
          )
          .toList();

      // 使用 CourseQueryTab 認定的 Key: 'selection_export'
      await prefs.setString('selection_export', jsonEncode(exportList));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text("匯出成功"),
              ],
            ),
            content: const Text(
              "已成功將課程匯出！\n\n請在選課開放期間，前往「選課系統」頁面，系統會自動將這些課程加入待加選清單中。",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 關閉 Dialog
                  Navigator.pop(context); // 返回助手頁面
                },
                child: const Text("我知道了"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("匯出失敗：$e")));
    }
  }

  // 執行匯入程式碼 (JSON 格式)
  void _exportAsCode() {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請至少選擇一門課程")));
      return;
    }

    // 格式: const exportClass = [{"id":"GEAE2347","name":"名稱","value":50,"isSel":"+"}];
    List<Map<String, dynamic>> exportData = _assistantCourses
        .where((c) => _selectedCourseIds.contains(c.code))
        .map(
          (c) => {
            "id": c.code,
            "name": c.name.split('\n')[0], // 僅保留名稱主體
            "value": 0,
            "isSel": "+",
          },
        )
        .toList();

    String codeString = "const exportClass = ${jsonEncode(exportData)};";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("匯出程式碼"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "請複製下方完整程式碼，並貼進選課系統的匯入面板中，或是NSYSU手機應用程式：",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  codeString,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codeString));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("已複製到剪貼簿！")));
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text("直接複製"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAllSelected =
        _selectedCourseIds.length == _assistantCourses.length &&
        _assistantCourses.isNotEmpty;

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _assistantCourses.isEmpty
        ? const Center(
            child: Text(
              "助手課表目前沒有正式課程，無法匯出",
              style: TextStyle(color: Colors.grey),
            ),
          )
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.orange[50],
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "勾選您想匯出的課程，點擊下方按鈕後，前往「選課系統」頁面即可自動加入待加選清單！",
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_assistantCourses.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (isAllSelected) {
                            _selectedCourseIds.clear();
                          } else {
                            _selectedCourseIds = _assistantCourses
                                .map((c) => c.code)
                                .toSet();
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[800],
                      ),
                      child: Text(isAllSelected ? "取消全選" : "全選"),
                    ),
                ],
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _assistantCourses.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final course = _assistantCourses[index];
                    final isSelected = _selectedCourseIds.contains(course.code);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(
                        course.name.split('\n')[0],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("${course.code} · ${course.professor}"),
                      activeColor: Colors.blue[700],
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedCourseIds.add(course.code);
                          } else {
                            _selectedCourseIds.remove(course.code);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _selectedCourseIds.isEmpty
                                ? null
                                : _exportAsCode,
                            icon: const Icon(Icons.code_rounded),
                            label: const Text(
                              "匯出程式碼",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blue[700]!),
                              foregroundColor: Colors.blue[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _selectedCourseIds.isEmpty
                                ? null
                                : _exportToCart,
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: Text(
                              "匯出至選課系統 (${_selectedCourseIds.length})",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

    if (widget.isSubPane) {
      return Container(color: Colors.white, child: content);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("匯出至選課系統"),
        actions: [
          if (_assistantCourses.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (isAllSelected) {
                    _selectedCourseIds.clear();
                  } else {
                    _selectedCourseIds = _assistantCourses
                        .map((c) => c.code)
                        .toSet();
                  }
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.blue[800]),
              child: Text(isAllSelected ? "取消全選" : "全選"),
            ),
        ],
      ),
      body: content,
    );
  }
}
