import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/score_item.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_dropdown.dart';

class ScoreTrackingDetail extends StatefulWidget {
  final CourseScoreData courseData;
  final Future<void> Function() onRefresh;
  final VoidCallback onSave;

  const ScoreTrackingDetail({
    Key? key,
    required this.courseData,
    required this.onRefresh,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ScoreTrackingDetail> createState() => _ScoreTrackingDetailState();
}

class _ScoreTrackingDetailState extends State<ScoreTrackingDetail> {
  bool _isEditing = false;
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScoreTrackingDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseData.courseId != widget.courseData.courseId) {
      _clearControllers();
      setState(() {
        _isEditing = false;
      });
    }
  }

  TextEditingController _getController(String key, String? initialText) {
    if (!_textControllers.containsKey(key)) {
      _textControllers[key] = TextEditingController(text: initialText ?? '');
    } else if (initialText != null &&
        _textControllers[key]!.text != initialText &&
        !_textControllers[key]!.selection.isValid) {
      _textControllers[key]!.text = initialText;
    }
    return _textControllers[key]!;
  }

  void _clearControllers() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
  }

  String _formatWeight(double weight) {
    String s = weight.toStringAsFixed(2);
    s = s.replaceAll(RegExp(r'0*$'), '');
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void _enterEditMode() {
    final preferredOrder = ['出席', '小考', '期中考', '期末考', '期中報告', '期末報告'];

    if (widget.courseData.items.isEmpty) {
      widget.courseData.items = preferredOrder
          .map((name) => ScoreItem.fromRawData(name, 0))
          .toList();
      widget.courseData.isCustomized = true;
      widget.onSave();
    } else {
      widget.courseData.items.sort((a, b) {
        int indexA = preferredOrder.indexOf(a.name);
        int indexB = preferredOrder.indexOf(b.name);
        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;
        return indexA.compareTo(indexB);
      });
    }

    setState(() {
      _isEditing = true;
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditing = false;
    });
  }

  void _saveEditMode() {
    double totalWeight = widget.courseData.items.fold(
      0,
      (sum, item) => sum + item.weight,
    );
    if ((totalWeight - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("權重總和必須為 100%，目前為 ${totalWeight.toStringAsFixed(2)}%"),
        ),
      );
      return;
    }

    widget.courseData.isCustomized = true;
    widget.courseData.lastUpdated = DateTime.now();

    setState(() {
      _isEditing = false;
    });

    widget.onSave();
  }

  Future<void> _handleRefresh() async {
    await widget.onRefresh();
    if (mounted) {
      setState(() {
        _isEditing = false;
      });
      _clearControllers();
    }
  }

  bool _areWeightsEvenlyDistributed(List<ScoreItem> children) {
    if (children.length <= 1) return true;
    final firstWeight = children.first.weight;
    for (final child in children.skip(1)) {
      if ((child.weight - firstWeight).abs() > 0.01) return false;
    }
    return true;
  }

  void _addChildItem(ScoreItem parent) {
    // Ensure children list is mutable (fromRawData defaults to const [])
    if (parent.children.isEmpty) {
      parent.children = [];
    }
    final children = parent.children;
    String newName;
    double newWeight;

    if (children.isEmpty) {
      // First split: create two children with equal weight
      final childWeight = double.parse((parent.weight / 2).toStringAsFixed(2));
      children.add(ScoreItem.fromRawData('${parent.name} 1', childWeight));
      newName = '${parent.name} 2';
      newWeight = double.parse(
        (parent.weight - childWeight).toStringAsFixed(2),
      );
    } else if (_areWeightsEvenlyDistributed(children)) {
      // Redistribute evenly across all children + new one
      final newCount = children.length + 1;
      final baseWeight = double.parse(
        (parent.weight / newCount).toStringAsFixed(2),
      );
      double total = 0;
      for (int i = 0; i < children.length; i++) {
        children[i].weight = baseWeight;
        total += baseWeight;
      }
      newName = '${parent.name} $newCount';
      newWeight = double.parse((parent.weight - total).toStringAsFixed(2));
    } else {
      // Weights customized: add with 0
      newName = '${parent.name} ${children.length + 1}';
      newWeight = 0;
    }

    children.add(ScoreItem.fromRawData(newName, newWeight));
    parent.score = null;
    parent.isExpanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 預估分析
          _buildPredictionAnalysis(),

          const SizedBox(height: 16),

          // 目標等第選擇
          _buildTargetGradeSelector(),

          const SizedBox(height: 16),

          // 標題列
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "評分方式",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.subtitleText,
                ),
              ),
              Row(
                children: [
                  if (widget.courseData.isCustomized)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        "自訂",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: _handleRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: "重新抓取配分方式",
                    color: colorScheme.accentBlue,
                  ),
                  IconButton(
                    onPressed: _enterEditMode,
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: "編輯配分",
                    color: colorScheme.accentBlue,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 配分項目列表
          if (_isEditing) _buildEditableScoreItems() else _buildScoreItems(),
        ],
      ),
    );
  }

  Widget _buildScoreItems() {
    return Column(
      children: widget.courseData.items.map((item) {
        return _buildScoreItemRow(item);
      }).toList(),
    );
  }

  Widget _buildScoreItemRow(ScoreItem item, {int level = 0}) {
    final colorScheme = Theme.of(context).colorScheme;
    final controllerKey = '${widget.courseData.courseId}_${item.id}';
    final controller = _getController(
      controllerKey,
      item.score
              ?.toStringAsFixed(2)
              .replaceAll(RegExp(r'0*$'), '')
              .replaceAll(RegExp(r'\.$'), '') ??
          '',
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: level * 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 項目名稱與權重
              Expanded(
                flex: 2,
                child: Text(
                  "${item.name} (${_formatWeight(item.weight)}%)",
                  style: TextStyle(
                    fontSize: 14 - level * 1,
                    color: colorScheme.primaryText,
                    fontWeight: level == 0
                        ? FontWeight.normal
                        : FontWeight.w500,
                  ),
                ),
              ),

              // 分數輸入框
              if (!item.hasChildren)
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "未輸入",
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: colorScheme.subtitleText.withValues(alpha: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.accentBlue,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.cardBackground,
                      isDense: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d{0,3}(\.\d{0,2})?$'),
                      ),
                    ],
                    onChanged: (value) {
                      final score = double.tryParse(value);
                      setState(() {
                        item.score = score;
                      });
                      widget.onSave();
                    },
                  ),
                )
              else
                const SizedBox(width: 120),

              const SizedBox(width: 8),

              if (level == 0 && item.children.length < 5)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _addChildItem(item);
                    });
                    widget.onSave();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: "新增子項目",
                  color: colorScheme.accentBlue,
                )
              else if (level == 0)
                const SizedBox(width: 40),
            ],
          ),

          // 子項目列表
          if (item.hasChildren) ...[
            const SizedBox(height: 4),
            ...item.children.map((child) {
              return _buildScoreItemRow(child, level: level + 1);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableScoreItems() {
    return Column(
      children: [
        ...widget.courseData.items.asMap().entries.map((entry) {
          return _buildEditableScoreItemRow(
            widget.courseData.items,
            entry.key,
            0,
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  widget.courseData.items.add(ScoreItem.fromRawData('新項目', 0));
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text("新增項目"),
            ),
            const Spacer(),
            TextButton(onPressed: _exitEditMode, child: const Text("取消")),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _saveEditMode, child: const Text("完成編輯")),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableScoreItemRow(
    List<ScoreItem> list,
    int index,
    int level,
  ) {
    final item = list[index];
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: level * 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.secondaryCardBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.borderColor, width: 0.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: item.name),
                    onChanged: (value) => item.name = value,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                    ),
                    decoration: InputDecoration(
                      hintText: "項目名稱",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.cardBackground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(
                      text: _formatWeight(item.weight),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,3}(\.\d{0,2})?$'),
                      ),
                    ],
                    onChanged: (value) {
                      item.weight = double.tryParse(value) ?? 0;
                    },
                    decoration: InputDecoration(
                      suffixText: "%",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.cardBackground,
                    ),
                  ),
                ),
                if (level == 0 && item.children.length < 5)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _addChildItem(item);
                      });
                    },
                    icon: const Icon(Icons.add, size: 20),
                    color: colorScheme.accentBlue,
                    tooltip: "新增子項目",
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  )
                else if (level == 0)
                  const SizedBox(width: 28),
                IconButton(
                  onPressed: () {
                    setState(() {
                      list.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.redAccent,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (item.children.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...item.children.asMap().entries.map((childEntry) {
                return _buildEditableScoreItemRow(
                  item.children,
                  childEntry.key,
                  level + 1,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTargetGradeSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final grades = [
      'A+',
      'A',
      'A-',
      'B+',
      'B',
      'B-',
      'C+',
      'C',
      'C-',
      'D',
      'E',
      'F',
    ];

    return Row(
      children: [
        Text(
          "目標等第：",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.subtitleText,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: GlassSingleSelectDropdown(
            label: "",
            items: grades,
            value: widget.courseData.targetGrade ?? 'A+',
            dense: true,
            onChanged: (value) {
              setState(() {
                widget.courseData.targetGrade = value;
              });
              widget.onSave();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionAnalysis() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTotal = widget.courseData.currentTotal;
    final enteredWeight = widget.courseData.enteredWeight;
    final remainingWeight = 100 - enteredWeight;

    double? targetMinScore;
    if (widget.courseData.targetGrade != null) {
      targetMinScore = _getGradeMinScore(widget.courseData.targetGrade!);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "預估分析",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.subtitleText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          if (currentTotal != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.accentBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "目前總分",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.subtitleText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${currentTotal.toStringAsFixed(1)} / 100",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.subtitleText.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "已輸入權重",
                style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
              ),
              const SizedBox(width: 8),
              Text(
                "${enteredWeight.toStringAsFixed(2)}%",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          if (targetMinScore != null && remainingWeight > 0) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final needed = targetMinScore! - (currentTotal ?? 0);
                final avgNeeded = needed / (remainingWeight / 100);
                final isUnreachable = avgNeeded > 100;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isUnreachable
                        ? Colors.red.withValues(alpha: 0.1)
                        : colorScheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _calculateNeededText(targetMinScore),
                    style: TextStyle(
                      fontSize: 13,
                      color: isUnreachable
                          ? Colors.redAccent
                          : colorScheme.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ] else if (targetMinScore != null && remainingWeight <= 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                currentTotal != null && currentTotal >= targetMinScore
                    ? "目前已達成目標！"
                    : "目前總分 ${currentTotal?.toStringAsFixed(1)} 未達目標 ${targetMinScore.toStringAsFixed(0)} 分",
                style: TextStyle(
                  fontSize: 13,
                  color: currentTotal != null && currentTotal >= targetMinScore
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calculateNeededText(double targetMinScore) {
    final currentTotal = widget.courseData.currentTotal ?? 0;
    final remainingWeight = 100 - widget.courseData.enteredWeight;

    if (remainingWeight <= 0) return "所有項目已輸入完成";

    final needed = targetMinScore - currentTotal;
    final avgNeeded = needed / (remainingWeight / 100);

    if (avgNeeded <= 0) {
      return "目前已達成目標！";
    }

    return "剩餘項目平均需要：${avgNeeded.toStringAsFixed(1)} 分（目標 ${widget.courseData.targetGrade}，需達 ${targetMinScore.toStringAsFixed(0)} 分）";
  }

  double _getGradeMinScore(String grade) {
    switch (grade) {
      case 'A+':
        return 90;
      case 'A':
        return 85;
      case 'A-':
        return 80;
      case 'B+':
        return 77;
      case 'B':
        return 73;
      case 'B-':
        return 70;
      case 'C+':
        return 67;
      case 'C':
        return 63;
      case 'C-':
        return 60;
      case 'D':
        return 50;
      case 'E':
        return 40;
      case 'F':
        return 0;
      default:
        return 0;
    }
  }
}
