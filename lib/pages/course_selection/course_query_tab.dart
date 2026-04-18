import 'package:flutter/material.dart';
import '../../services/course_selection_service.dart';
import '../../services/course_query_service.dart';
import '../../services/course_selection_submit_service.dart' as submit_service;
import '../../models/course_selection_models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class CourseQueryTab extends StatefulWidget {
  final List<CourseSelectionData> currentCourses;
  final VoidCallback onRequestRefresh;

  const CourseQueryTab({
    Key? key,
    required this.currentCourses,
    required this.onRequestRefresh,
  }) : super(key: key);

  @override
  State<CourseQueryTab> createState() => _CourseQueryTabState();
}

class _CourseQueryTabState extends State<CourseQueryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isQueryLoading = false;
  List<CourseJsonData> _searchResults = [];
  bool _hasSearched = false;
  bool _showEditListMode = false;
  bool _showImportCodeMode = false;
  bool _filterConflict = false; // 新傳：過濾衝堂
  final TextEditingController _importCodeController = TextEditingController();

  final List<PendingTransaction> _pendingItems = [];
  bool _hasCheckedExported = false;

  final TextEditingController _mergedQueryCtrl = TextEditingController();
  Set<String> _selectedGrades = {};
  String? _selectedClass;
  Set<String> _selectedDays = {};
  Set<String> _selectedPeriods = {};

  @override
  void initState() {
    super.initState();
    _loadCartFromPrefs();
    CourseQueryService.instance.getCourses().catchError((e) {
      print("背景載入失敗: $e");
      return <CourseJsonData>[];
    });

    // 在進入頁面後，檢查是否有從選課助手匯出的課程
    // 移至 didUpdateWidget 以確保資料已載入
  }

  @override
  void didUpdateWidget(covariant CourseQueryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasCheckedExported && widget.currentCourses.isNotEmpty) {
      _hasCheckedExported = true;
      _checkExportedCourses();
    }
  }

  @override
  void dispose() {
    _mergedQueryCtrl.dispose();
    for (var p in _pendingItems) {
      p.pointsController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // _checkExportedCourses(); 移至 initState 了

    return Column(
      children: [
        // 1. 功能導航列
        _buildTopActionBar(),
        if (!_showEditListMode && !_showImportCodeMode)
          _buildDesktopSearchPanel(),

        Expanded(
          child: _showEditListMode
              ? _buildEditListMode()
              : (_showImportCodeMode
                    ? _buildImportCodePanel()
                    : _buildSearchResults()),
        ),
      ],
    );
  }

  Widget _buildTopActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionToggleButton(
              icon: Icons.search_rounded,
              label: "搜尋課程",
              isSelected: !_showEditListMode && !_showImportCodeMode,
              onPressed: () => setState(() {
                _showEditListMode = false;
                _showImportCodeMode = false;
              }),
            ),
            const SizedBox(width: 8),
            _buildActionToggleButton(
              icon: Icons.shopping_cart_checkout_rounded,
              label: "加退選選單(${_pendingItems.length})",
              isSelected: _showEditListMode,
               activeColor: Theme.of(context).colorScheme.isDark ? Colors.orange[300]! : Colors.orange[800]!,
              onPressed: () => setState(() {
                _showEditListMode = true;
                _showImportCodeMode = false;
              }),
            ),
            const SizedBox(width: 8),
            _buildActionToggleButton(
              icon: Icons.code_rounded,
              label: "代碼匯入",
              isSelected: _showImportCodeMode,
               activeColor: Theme.of(context).colorScheme.isDark ? Colors.purple[200]! : Colors.purple[700]!,
              onPressed: () => setState(() {
                _showImportCodeMode = true;
                _showEditListMode = false;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
    Color activeColor = Colors.blue,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
               color: isSelected ? activeColor : Theme.of(context).colorScheme.subtitleText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                 color: isSelected ? activeColor : Theme.of(context).colorScheme.subtitleText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 同步選課助手的搜尋面板佈局
  Widget _buildDesktopSearchPanel() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  "合併關鍵字搜尋 (名稱、教師、系所、學程)",
                  _mergedQueryCtrl,
                  hint: "可用空白區隔多個關鍵字，如：資工 物件",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildMultiSelectDropdown(
                  label: "年級",
                  values: _selectedGrades,
                  options: {"1": "1", "2": "2", "3": "3", "4": "4", "5": "5"},
                  onChanged: (newSet) =>
                      setState(() => _selectedGrades = newSet),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildMultiSelectDropdown(
                  label: "星期",
                  values: _selectedDays,
                  options: {
                    "1": "一",
                    "2": "二",
                    "3": "三",
                    "4": "四",
                    "5": "五",
                    "6": "六",
                    "7": "日",
                  },
                  onChanged: (newSet) => setState(() => _selectedDays = newSet),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildMultiSelectDropdown(
                  label: "節次",
                  values: _selectedPeriods,
                  options: {
                    "A": "A",
                    "1": "1",
                    "2": "2",
                    "3": "3",
                    "4": "4",
                    "5": "5",
                    "6": "6",
                    "7": "7",
                    "8": "8",
                    "9": "9",
                    "B": "B",
                    "C": "C",
                  },
                  onChanged: (newSet) =>
                      setState(() => _selectedPeriods = newSet),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text("過濾衝堂", style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.subtitleText)),
                   SizedBox(
                     height: 32,
                     child: Switch(
                        value: _filterConflict,
                        activeColor: Theme.of(context).colorScheme.accentBlue,
                        onChanged: (v) {
                          setState(() => _filterConflict = v);
                          _performSearch();
                        },
                     ),
                   ),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: ElevatedButton.icon(
                    onPressed: _performSearch,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text("搜尋"),
                    style: ElevatedButton.styleFrom(
                       backgroundColor: Theme.of(context).colorScheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isQueryLoading)
      return const Center(child: CircularProgressIndicator());
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(Icons.manage_search_rounded, size: 64, color: Theme.of(context).colorScheme.subtitleText.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text("設定搜尋條件並點擊搜尋按鈕開始", style: TextStyle(color: Theme.of(context).colorScheme.subtitleText)),
          ],
        ),
      );
    }
    if (_searchResults.isEmpty) return const Center(child: Text("找不到符合條件的課程"));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final course = _searchResults[index];
        bool isAdded = _pendingItems.any((p) => p.id == course.id);
        bool isAlreadySelected = widget.currentCourses.any(
          (c) => c.code == course.id,
        );

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.borderColor),
            boxShadow: colorScheme.isDark ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            backgroundColor: colorScheme.secondaryCardBackground.withOpacity(0.5),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              course.name.split('\n')[0],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorScheme.primaryText,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildMiniInfoChip(
                    Icons.person_outline_rounded,
                    course.teacher,
                  ),
                  _buildMiniInfoChip(Icons.tag_rounded, course.id),
                  _buildMiniInfoChip(
                    Icons.account_balance_rounded,
                    course.department,
                  ),
                  _buildMiniInfoChip(
                    Icons.room_outlined,
                    _extractRoomLocation(course.room),
                  ),
                  if (course.english)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryCardBackground,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.isDark ? Colors.orange[900]!.withOpacity(0.3) : Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "機率: ${_calculateProbability(course)}",
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.isDark ? Colors.orange[200] : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: isAlreadySelected
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "已在課表中",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : isAdded
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 28,
                  )
                : ElevatedButton(
                    onPressed: () => _addToPendingList(course),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(60, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      "加選",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDetailCol("課程資訊", [
                            "學分: ${course.credit} 學分",
                            "名額: ${course.restrict} 人",
                            "已選: ${course.selected} 人 (餘 ${course.remaining})",
                            "地點: ${course.room.isEmpty ? "地點不明" : _extractRoomLocation(course.room)}",
                          ]),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildDetailCol(
                            "對應學程",
                            course.tags.isEmpty ? ["無"] : course.tags,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (course.description.isNotEmpty) ...[
                      const Text(
                        "課程備註",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueAccent, // 更醒目的顏色
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      "評分比例",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: colorScheme.subtitleText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<String>>(
                      future: _getCourseEvaluation(course.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        if (!snapshot.hasData || snapshot.data!.isEmpty)
                          return Text(
                            "尚無評分細節",
                            style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
                          );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: snapshot.data!
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    "• $e",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.primaryText,
                                    ),
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
        );
      },
    );
  }

  Widget _buildDetailCol(String title, List<String> items) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: colorScheme.subtitleText,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (it) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              it,
              style: TextStyle(fontSize: 13, color: colorScheme.primaryText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditListMode() {
    final colorScheme = Theme.of(context).colorScheme;
    final activeExistingCourses = widget.currentCourses.where((c) {
      if (_pendingItems.any(
        (p) => p.id == c.code && p.type == TransactionType.drop,
      ))
        return false;
      return (c.status.contains("選上") && !c.status.contains("未選上")) ||
          c.status.contains("登記") ||
          c.status.contains("加選");
    }).toList();

    int totalCount = activeExistingCourses.length + _pendingItems.length;
    if (totalCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_remove_rounded,
              size: 64,
              color: colorScheme.subtitleText.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Text("您的選課清單是空的", style: TextStyle(color: colorScheme.subtitleText)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_pendingItems.isNotEmpty) ...[
                const Text(
                  "加退選項目",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(height: 12),
                ..._pendingItems.map((item) {
                  bool isAdd = item.type == TransactionType.add;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAdd
                          ? colorScheme.isDark ? Colors.orange[900]!.withOpacity(0.2) : Colors.orange[50]!.withOpacity(0.5)
                          : colorScheme.isDark ? Colors.red[900]!.withOpacity(0.2) : Colors.red[50]!.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAdd ? (colorScheme.isDark ? Colors.orange[700]! : Colors.orange[200]!) : (colorScheme.isDark ? Colors.red[700]! : Colors.red[100]!),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isAdd ? Colors.orange : Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdd ? "加選" : "退選",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: item.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primaryText,
                                      ),
                                    ),
                                    TextSpan(
                                      text: " / ${item.id}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.subtitleText,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.grey,
                              ),
                              onPressed: () => _confirmRemovePendingItem(item),
                            ),
                          ],
                        ),
                        if (isAdd) ...[
                          const Divider(),
                          Row(
                            children: [
                              const Text(
                                "志願序 / 權重點數：",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                height: 35,
                                child: TextField(
                                  controller: item.pointsController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ],
              if (activeExistingCourses.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  "目前已選上之課程",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.subtitleText,
                  ),
                ),
                const SizedBox(height: 12),
                ...activeExistingCourses.map((course) {
                  bool isOk = course.status.contains("選上");
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isOk ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                              Text(
                                "${course.courseNo}",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _confirmDropCourse(course),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[400],
                          ),
                          child: const Text("申請退選"),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        if (_pendingItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.cardBackground,
              border: Border(top: BorderSide(color: colorScheme.borderColor)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "確認送出並執行 (${_pendingItems.length} 項異動)",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _performSearch() async {
    setState(() {
      _isQueryLoading = true;
      _hasSearched = true;
    });
    try {
      await CourseQueryService.instance.getCourses();

      final results = CourseQueryService.instance.search(
        query: _mergedQueryCtrl.text.trim(),
        grades: _selectedGrades.toList(),
        days: _selectedDays.toList(),
        periods: _selectedPeriods.toList(),
        classType: _selectedClass,
        filterConflict: _filterConflict,
        existingCourses: _parseSelectedCoursesForConflict(),
      );
      setState(() {
        _searchResults = results;
        _isQueryLoading = false;
      });
    } catch (e) {
      setState(() {
        _isQueryLoading = false;
      });
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
    return _GlassMultiSelectDropdown(
      label: label,
      values: values,
      options: options,
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
            hintStyle: TextStyle(fontSize: 12, color: colorScheme.subtitleText.withOpacity(0.5)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
          style: TextStyle(fontSize: 13, color: colorScheme.primaryText),
        ),
      ],
    );
  }

  Widget _buildMiniInfoChip(IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.subtitleText),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.primaryText),
          ),
        ],
      ),
    );
  }

  String _calculateProbability(CourseJsonData course) {
    if (course.remaining <= 0) return "0% (已滿)";
    double prob = course.remaining / course.select;
    if (course.select <= 0 || prob > 1) return "100%"; // 無人選
    return "${(prob * 100).toStringAsFixed(1)}%";
  }

  // 其他原有方法如 _addToPendingList, _submitSelection 等保持不變，但根據需要微調 UI
  void _addToPendingList(CourseJsonData course) {
    if (_pendingItems.length >= 15) return;
    if (_pendingItems.any((p) => p.id == course.id)) return;
    setState(() {
      final controller = TextEditingController();
      controller.addListener(() => _saveCart());
      _pendingItems.add(
        PendingTransaction(
          id: course.id,
          courseNo: course.id,
          name: course.name.split('\n')[0],
          type: TransactionType.add,
          originalData: course,
          pointsController: controller,
        ),
      );
      _saveCart();
    });
  }

  void _confirmDropCourse(CourseSelectionData course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("確認退選"),
        content: Text("確定要將「${course.name}」加入退選清單嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingItems.add(
                  PendingTransaction(
                    id: course.code,
                    courseNo: course.courseNo,
                    name: course.name,
                    type: TransactionType.drop,
                    originalData: course,
                    pointsController: null,
                  ),
                );
                _saveCart();
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("確認加入"),
          ),
        ],
      ),
    );
  }

  void _confirmRemovePendingItem(PendingTransaction item) {
    setState(() {
      _pendingItems.remove(item);
      item.pointsController?.dispose();
      _saveCart();
    });
  }

  void _submitSelection() {
    _processSubmission();
  }

  Future<void> _processSubmission() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) =>
          const Center(child: CircularProgressIndicator()),
    );
    try {
      List<submit_service.PendingTransaction> serviceItems = _pendingItems.map((
        uiItem,
      ) {
        return submit_service.PendingTransaction(
          id: uiItem.id,
          name: uiItem.name,
          type: uiItem.type == TransactionType.add
              ? submit_service.TransactionType.add
              : submit_service.TransactionType.drop,
          points: uiItem.pointsController?.text.trim() ?? "",
        );
      }).toList();
      final result = await submit_service.CourseSelectionSubmitService.instance
          .submitTransactions(serviceItems);
      if (!mounted) return;
      Navigator.pop(context);
      if (result.success == true) {
        _showSuccessDialog();
        setState(() {
          for (var p in _pendingItems) p.pointsController?.dispose();
          _pendingItems.clear();
          _showEditListMode = false;
          _saveCart();
        });
        widget.onRequestRefresh();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message ?? "送出失敗")));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("出錯了: $e")));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("加退選成功"),
          ],
        ),
        content: const Text("請求已送出，請務必稍後至官方網站確認最終課表狀態。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("我了解"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> cartList = _pendingItems.map((item) {
        dynamic original;
        if (item.originalData is CourseJsonData) {
          original = (item.originalData as CourseJsonData).toJson();
        } else if (item.originalData is CourseSelectionData) {
          original = (item.originalData as CourseSelectionData).toJson();
        } else {
          // 如果已經是 Map 或其他，直接存
          original = item.originalData;
        }

        return {
          'id': item.id,
          'courseNo': item.courseNo,
          'name': item.name,
          'type': item.type.index,
          'points': item.pointsController?.text ?? "",
          'original': original,
        };
      }).toList();
      await prefs.setString('selection_cart', jsonEncode(cartList));
    } catch (e) {
      print("儲存預選清單失敗: $e");
    }
  }

  Future<void> _loadCartFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString('selection_cart');
    if (jsonStr != null) {
      List<dynamic> decoded = jsonDecode(jsonStr);
      setState(() {
        _pendingItems.clear();
        for (var map in decoded) {
          final ctrl = TextEditingController(text: map['points']);
          ctrl.addListener(() => _saveCart());
          _pendingItems.add(
            PendingTransaction(
              id: map['id'],
              courseNo: map['courseNo'] ?? "",
              name: map['name'],
              type: TransactionType.values[map['type']],
              originalData: map['original'],
              pointsController: ctrl,
            ),
          );
        }
      });
    }
  }

  void _checkExportedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString('selection_export');
    if (jsonStr == null) return;

    try {
      List<dynamic> list = jsonDecode(jsonStr);
      if (list.isEmpty) return;

      int addedCount = 0;
      for (var item in list) {
        if (item == null || item is! Map) continue;

        final String? itemId = item['id']?.toString();
        if (itemId == null) continue;

        // 防止重複加入 (同時檢查預選清單與已選上課程)
        final String searchId = itemId.trim().toUpperCase();
        if (_pendingItems.any((p) => p.id.trim().toUpperCase() == searchId) ||
            widget.currentCourses.any(
              (c) => c.courseNo.trim().toUpperCase() == searchId,
            )) {
          continue;
        }

        final String itemName = (item['name']?.toString() ?? "未命名課程").split(
          '\n',
        )[0];
        final ctrl = TextEditingController(
          text: item['points']?.toString() ?? "0",
        );
        ctrl.addListener(() => _saveCart());

        setState(() {
          _pendingItems.add(
            PendingTransaction(
              id: itemId,
              courseNo: item['id']?.toString() ?? "", // 在選課助手中，id 就是課號
              name: itemName,
              type: TransactionType.add,
              pointsController: ctrl,
              originalData: item['originalData'] ?? item,
            ),
          );
        });
        addedCount++;
      }
      if (addedCount > 0) {
        _saveCart();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("已從外部匯入 $addedCount 門課程至預選清單")));
      } else if (list.isNotEmpty) {
        // 如果列表不為空但沒加入任何課，代表全是重複的
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("外部匯入的課程均已存在於清單中")));
      }
      // 領收完畢後清除
      await prefs.remove('selection_export');
    } catch (e) {
      print("匯入課程失敗: $e");
    }
  }

  final Map<String, List<String>> _evaluationCache = {};
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
        for (var match in matches) {
          String item = match.group(1)?.trim() ?? "";
          String pct = match.group(2)?.trim() ?? "";
          if (item.isNotEmpty)
            evals.add('$item：${pct.isNotEmpty ? pct : "0"}%');
        }
        if (evals.isEmpty) evals.add("尚無具體評分比例資料");
        _evaluationCache[courseId] = evals;
        return evals;
      }
    } catch (e) {
      return ["載入失敗 $e"];
    }
    return ["查與紀錄"];
  }

  // ✅ 新增：從程式碼匯入面板
  Widget _buildImportCodePanel() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.isDark ? Colors.purple[900]!.withOpacity(0.2) : Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.isDark ? Colors.purple[700]! : Colors.purple[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.isDark ? Colors.purple[200] : Colors.purple[700],
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                      Text(
                        "快速匯入說明",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.isDark ? Colors.purple[200] : Colors.purple[900],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "請貼上從「選課助手」匯出的程式碼內容。系統會解析其中的課程代碼並自動加入您的待加選清單中。",
                  style: TextStyle(
                    color: colorScheme.isDark ? colorScheme.subtitleText : Colors.purple[800],
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "程式碼內容：",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.subtitleText,
                ),
              ),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste_rounded, size: 18),
                label: const Text("剪貼簿貼上"),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.isDark ? Colors.purple[200] : Colors.purple[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _importCodeController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: "const exportClass = [...];",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.secondaryCardBackground,
              ),
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: colorScheme.primaryText),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _handleImportCode(_importCodeController.text),
              icon: const Icon(Icons.download_rounded),
              label: const Text(
                "解析並匯入至預選清單",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.isDark ? Colors.purple[800] : Colors.purple[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _importCodeController.text = data!.text!);
    }
  }

  void _handleImportCode(String code) async {
    if (code.trim().isEmpty) return;

    try {
      // 解析格式: const exportClass = [...];
      final regex = RegExp(r'exportClass\s*=\s*(\[.*?\]);', dotAll: true);
      final match = regex.firstMatch(code);
      if (match == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("格式錯誤，找不到有效的課程資料")));
        return;
      }

      String jsonItems = match.group(1)!;
      List<dynamic> parsed = jsonDecode(jsonItems);

      int added = 0;
      int skipped = 0;

      // 確保基礎資料已載入
      await CourseQueryService.instance.getCourses();

      for (var item in parsed) {
        String id = item['id'].toString();

        // 檢查是否已存在 (同時檢查預選清單與已選上課程)
        final String searchId = id.trim().toUpperCase();
        if (_pendingItems.any((p) => p.id.trim().toUpperCase() == searchId) ||
            widget.currentCourses.any(
              (c) => c.courseNo.trim().toUpperCase() == searchId,
            )) {
          skipped++;
          continue;
        }

        // 搜尋課程完整資料 (為了補足 PendingTransaction 需要的 originalData)
        final results = CourseQueryService.instance.search(query: id);
        if (results.isNotEmpty) {
          final course = results.first;
          final ctrl = TextEditingController(text: "0"); // 預設權重
          ctrl.addListener(() => _saveCart());

          setState(() {
            _pendingItems.add(
              PendingTransaction(
                id: course.id,
                courseNo: course.id, // 在程式碼匯入中，id 就是課號
                name: course.name.split('\n')[0],
                type: TransactionType.add,
                pointsController: ctrl,
                originalData: course.toJson(),
              ),
            );
          });
          added++;
        }
      }

      if (added > 0) _saveCart();

      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("匯入結果"),
          content: Text("成功加入 $added 門課程\n跳過 $skipped 門已存在課程"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                setState(() => _showImportCodeMode = false); // 切換回列表
              },
              child: const Text("查看清單"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("解析失敗: $e")));
    }
  }

  // ✅ 新增：解析已選課程的時間格式以供衝堂過濾
  List<Map<String, dynamic>> _parseSelectedCoursesForConflict() {
    List<Map<String, dynamic>> results = [];
    final dayNames = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7};

    for (var c in widget.currentCourses) {
      // timeRoom 範例: "一1234(B101) 二56(B102)"
      String tr = c.timeRoom;
      List<Map<String, dynamic>> pTimes = [];
      
      // 使用 Regex 分解時間與教室
      // 匹配「星期」接著「節次」，後面可能有括號教室
      final reg = RegExp(r'([一二三四五六日])([A1-9BC]+)');
      final matches = reg.allMatches(tr);
      
      for (var m in matches) {
        int? day = dayNames[m.group(1)];
        String periods = m.group(2) ?? "";
        if (day != null) {
          for (int i = 0; i < periods.length; i++) {
            pTimes.add({'day': day, 'period': periods[i]});
          }
        }
      }
      
      results.add({
        'id': c.code,
        'parsedTimes': pTimes,
      });
    }
    return results;
  }

  String _extractRoomLocation(String rawRoom) {
    if (rawRoom.isEmpty) return "地點不明";
    final regex = RegExp(r'[\(\uff08](.*?)[\)\uff09]');
    final match = regex.firstMatch(rawRoom);
    if (match != null) {
      String content = match.group(1)?.trim() ?? "";
      return content.isNotEmpty ? content : "地點不明";
    }
    return "地點不明";
  }
}

class _GlassMultiSelectDropdown extends StatefulWidget {
  final String label;
  final Set<String> values;
  final Map<String, String> options;
  final Function(Set<String>) onChanged;

  const _GlassMultiSelectDropdown({
    Key? key,
    required this.label,
    required this.values,
    required this.options,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_GlassMultiSelectDropdown> createState() => _GlassMultiSelectDropdownState();
}

class _GlassMultiSelectDropdownState extends State<_GlassMultiSelectDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late Set<String> _tempSet;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown(true);
    } else {
      _tempSet = Set.from(widget.values);
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isOpen = true);
    }
  }

  void _closeDropdown([bool save = false]) {
    if (save) {
      widget.onChanged(Set.from(_tempSet));
    }
    // 解決 Windows 平台在移除 Overlay 時可能發生的焦點/鍵盤狀態斷言錯誤
    FocusManager.instance.primaryFocus?.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final colorScheme = Theme.of(context).colorScheme;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _closeDropdown(true),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(
                  builder: (context, setInnerState) {
                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 200),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutBack,
                      builder: (context, val, child) {
                        return Transform.scale(
                          scale: 0.95 + 0.05 * val,
                          alignment: Alignment.topCenter,
                          child: Opacity(
                            opacity: val.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: size.width < 180 ? 180 : size.width,
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: colorScheme.headerBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.borderColor.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: widget.options.entries.map((e) {
                                    final isSelected = _tempSet.contains(e.key);
                                    return _HoverableMultiSelectOption(
                                      label: e.value,
                                      isSelected: isSelected,
                                      colorScheme: colorScheme,
                                      onTap: () {
                                        setInnerState(() {
                                          if (isSelected) {
                                            _tempSet.remove(e.key);
                                          } else {
                                            _tempSet.add(e.key);
                                          }
                                          // Save immediately upon ticking for real-time feel
                                          widget.onChanged(Set.from(_tempSet));
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.borderColor,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.values.isEmpty
                          ? "全部"
                          : widget.values
                                .map((e) => widget.options[e] ?? e)
                                .join(', '),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colorScheme.accentBlue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableMultiSelectOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _HoverableMultiSelectOption({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  }) : super(key: key);

  @override
  State<_HoverableMultiSelectOption> createState() => _HoverableMultiSelectOptionState();
}

class _HoverableMultiSelectOptionState extends State<_HoverableMultiSelectOption> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.accentBlue.withValues(alpha: 0.1)
                : (_isHovering ? cs.accentBlue.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? cs.accentBlue.withValues(alpha: 0.3)
                  : (_isHovering ? cs.accentBlue.withValues(alpha: 0.2) : Colors.transparent),
            ),
            boxShadow: _isHovering && !isSelected
                ? [
                    BoxShadow(
                      color: cs.accentBlue.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: isSelected ? cs.accentBlue : (_isHovering ? cs.accentBlue.withValues(alpha: 0.6) : cs.subtitleText),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected || _isHovering ? cs.primaryText : cs.subtitleText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
