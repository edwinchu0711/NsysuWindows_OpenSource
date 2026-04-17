enum UserIntent {
  conversational, // 純聊天，不需工具
  simpleTool, // 單一工具呼叫，跳過 Planner
  complex, // 多步驟任務，需要規劃
  ambiguous, // 無法判斷，走預設 Router
}

class IntentClassifier {
  // 明確的聊天/寒暄模式
  static final _conversationalPatterns = [
    RegExp(
      r'^(你好|嗨|hi|hello|謝謝|感謝|再見|bye|ok|好|對|是|不是|否|嗯|哈|哈哈)$',
      caseSensitive: false,
    ),
    RegExp(r'^(請問|我想問|可以問|不好意思)$'),
  ];

  // 工具相關關鍵字
  static final _toolSignals = [
    RegExp(r'(加|新增|移除|刪除|清空|推薦|搜尋|查|找|比較|評價|排|課表|課|加入|更多|還有|其他|再)'),
  ];

  // 複雜度信號
  static final _complexitySignals = [RegExp(r'(並且|然後|之後|再|同時|而且|接著|幫我.*並)')];

  UserIntent classify(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return UserIntent.conversational;

    // 1. 短訊息匹配聊天模式
    if (trimmed.length <= 10) {
      for (var p in _conversationalPatterns) {
        if (p.hasMatch(trimmed)) return UserIntent.conversational;
      }
    }

    // 2. 檢查是否有工具信號
    final hasToolSignal = _toolSignals.any((p) => p.hasMatch(trimmed));
    if (!hasToolSignal) {
      // 無工具信號且短 → 聊天；較長可能是模糊詢問
      if (trimmed.length <= 20) return UserIntent.conversational;
      return UserIntent.ambiguous;
    }

    // 3. 有工具信號 → 判斷複雜度
    final complexityCount = _complexitySignals
        .where((p) => p.hasMatch(trimmed))
        .length;
    if (complexityCount >= 1 || trimmed.length > 60) {
      return UserIntent.complex;
    }

    return UserIntent.simpleTool;
  }
}
