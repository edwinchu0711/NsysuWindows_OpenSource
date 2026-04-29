import 'dart:math';

/// 配分項目資料模型
/// 支援基本項目與擴展子項目
class ScoreItem {
  String id; // UUID
  String name; // 項目名稱，例如 "期中考"
  double weight; // 權重百分比，例如 30.0
  double? score; // 使用者輸入的分數，null 表示未輸入
  List<ScoreItem> children; // 擴展後的子項目
  bool isExpanded; // UI 展開狀態（是否已擴展為子項目）

  ScoreItem({
    required this.id,
    required this.name,
    required this.weight,
    this.score,
    this.children = const [],
    this.isExpanded = false,
  });

  /// 有效分數：如果有子項目，回傳子項目的加權平均；否則回傳自己的分數
  double? get effectiveScore {
    if (children.isEmpty) return score;

    double totalScore = 0;
    double totalWeight = 0;
    for (var child in children) {
      if (child.effectiveScore != null) {
        totalScore += child.effectiveScore! * child.weight;
        totalWeight += child.weight;
      }
    }
    if (totalWeight <= 0) return null;
    return totalScore / totalWeight;
  }

  /// 是否為父項目（有子項目）
  bool get hasChildren => children.isNotEmpty;

  /// 已輸入的權重（以本項目的 weight 為基準，根據子項目的輸入比例計算）
  double get enteredWeight {
    if (children.isEmpty) {
      return score != null ? weight : 0.0;
    }

    double childrenTotalWeight = 0;
    double childrenEnteredWeight = 0;

    for (var child in children) {
      childrenTotalWeight += child.weight;
      childrenEnteredWeight += child.enteredWeight;
    }

    if (childrenTotalWeight <= 0) return 0.0;

    // 子項目的輸入比例 * 本項目的權重
    return (childrenEnteredWeight / childrenTotalWeight) * weight;
  }

  /// 計算目前總分（此項目在整體中的貢獻）
  double? get weightedScore {
    if (children.isEmpty) {
      if (score == null) return null;
      return score! * weight / 100;
    }

    double total = 0;
    bool hasAnyScore = false;
    for (var child in children) {
      final ws = child.weightedScore;
      if (ws != null) {
        total += ws;
        hasAnyScore = true;
      }
    }
    
    // 子項目加權分數的總和，再依照本項目的權重比例縮放
    // 假設子項目的 weight 總和 == parent.weight，那就直接回傳 total
    // 但如果子項目 weight 總和是 100，那就要縮放
    // 為了安全起見，我們用比例來算：
    double childrenTotalWeight = children.fold(0.0, (sum, child) => sum + child.weight);
    if (childrenTotalWeight <= 0) return null;
    
    return hasAnyScore ? (total / childrenTotalWeight) * weight : null;
  }

  /// 複製
  ScoreItem copyWith({
    String? id,
    String? name,
    double? weight,
    double? score,
    List<ScoreItem>? children,
    bool? isExpanded,
  }) {
    return ScoreItem(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      score: score ?? this.score,
      children: children ?? List.from(this.children),
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  /// 序列化為 Map（用於本地儲存）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'score': score,
      'children': children.map((c) => c.toJson()).toList(),
      'isExpanded': isExpanded,
    };
  }

  /// 從 Map 反序列化
  factory ScoreItem.fromJson(Map<String, dynamic> json) {
    return ScoreItem(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as num).toDouble(),
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => ScoreItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isExpanded: json['isExpanded'] as bool? ?? false,
    );
  }

  /// 從抓取的原始資料建立（名稱與權重）
  factory ScoreItem.fromRawData(String name, double weight) {
    return ScoreItem(
      id: _generateId(),
      name: name,
      weight: weight,
      children: [],
    );
  }

  /// 生成唯一 ID
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }

  static final Random _random = Random();
}

/// 課程配分資料（包含所有項目與目標等第）
class CourseScoreData {
  String courseId; // 課程代碼
  String courseName; // 課程名稱
  List<ScoreItem> items; // 配分項目清單
  String? targetGrade; // 目標等第（A+, A, A- ...）
  bool isCustomized; // 是否為使用者自訂配分（手動編輯過）
  DateTime? lastUpdated; // 最後更新時間

  CourseScoreData({
    required this.courseId,
    required this.courseName,
    this.items = const [],
    this.targetGrade,
    this.isCustomized = false,
    this.lastUpdated,
  });

  /// 計算目前總分（加權總和）
  double? get currentTotal {
    double total = 0;
    bool hasAnyScore = false;
    for (var item in items) {
      final ws = item.weightedScore;
      if (ws != null) {
        total += ws;
        hasAnyScore = true;
      }
    }
    return hasAnyScore ? total : null;
  }

  /// 已輸入項目的權重總和
  double get enteredWeight {
    double total = 0;
    for (var item in items) {
      total += item.enteredWeight;
    }
    return total;
  }

  /// 序列化
  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'items': items.map((i) => i.toJson()).toList(),
      'targetGrade': targetGrade,
      'isCustomized': isCustomized,
      'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
    };
  }

  /// 反序列化
  factory CourseScoreData.fromJson(Map<String, dynamic> json) {
    return CourseScoreData(
      courseId: json['courseId'] as String,
      courseName: json['courseName'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => ScoreItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      targetGrade: json['targetGrade'] as String?,
      isCustomized: json['isCustomized'] as bool? ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
          : null,
    );
  }
}
