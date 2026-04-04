import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course_model.dart'; // 請確認路徑
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

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

  // 執行匯入程式碼 (JSON 格式) - 改為直接複製
  void _exportAsCode() {
    if (_selectedCourseIds.isEmpty) {
      return; // 靜默處理，因為按鈕已設為 disabled
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
    
    // 直接複製到剪貼簿
    Clipboard.setData(ClipboardData(text: codeString));
    
    // 顯示短暫提示 (考慮到用戶之前希望減少通知，這裡用較不干擾的方式或是遵照慣例顯示)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("已複製匯出程式碼至剪貼簿！"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isAllSelected =
        _selectedCourseIds.length == _assistantCourses.length &&
        _assistantCourses.isNotEmpty;

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _assistantCourses.isEmpty
        ? Center(
            child: Text(
              "助手課表目前沒有正式課程，無法匯出",
              style: TextStyle(color: colorScheme.subtitleText),
            ),
          )
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: colorScheme.isDark ? Colors.orange[900]!.withOpacity(0.2) : Colors.orange[50],
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "勾選您想匯出的課程，點擊下方按鈕後，前往「選課系統」頁面即可自動加入待加選清單！",
                        style: TextStyle(color: colorScheme.isDark ? Colors.orange[200] : Colors.orange[800], fontSize: 13),
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
                        foregroundColor: colorScheme.accentBlue,
                      ),
                      child: Text(isAllSelected ? "取消全選" : "全選"),
                    ),
                ],
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _assistantCourses.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: colorScheme.borderColor),
                  itemBuilder: (context, index) {
                    final course = _assistantCourses[index];
                    final isSelected = _selectedCourseIds.contains(course.code);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(
                        course.name.split('\n')[0],
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primaryText),
                      ),
                      subtitle: Text("${course.code} · ${course.professor}", style: TextStyle(color: colorScheme.subtitleText)),
                      activeColor: colorScheme.accentBlue,
                      checkColor: Colors.white,
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
                  color: colorScheme.cardBackground,
                  boxShadow: colorScheme.isDark ? [] : [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  border: Border(top: BorderSide(color: colorScheme.borderColor)),
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
                              side: BorderSide(color: colorScheme.accentBlue),
                              foregroundColor: colorScheme.accentBlue,
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
                              backgroundColor: colorScheme.accentBlue,
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
      return Container(color: colorScheme.pageBackground, child: content);
    }

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: AppBar(
        title: const Text("匯出至選課系統"),
        backgroundColor: colorScheme.headerBackground,
        foregroundColor: colorScheme.primaryText,
        elevation: 0.5,
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
              style: TextButton.styleFrom(foregroundColor: colorScheme.accentBlue),
              child: Text(isAllSelected ? "取消全選" : "全選"),
            ),
        ],
      ),
      body: content,
    );
  }
}
