class ExecutionProof {
  final bool success;
  final String evidence;
  final String? errorDetail;

  const ExecutionProof({
    required this.success,
    required this.evidence,
    this.errorDetail,
  });

  static const defaultSuccess = ExecutionProof(
    success: true,
    evidence: 'Operation successful',
  );
}

class SkillResult {
  final String contextInfo;
  final String statusMessage;
  final bool needsRefresh;
  final ExecutionProof executionProof;
  final Map<String, dynamic> data;

  const SkillResult({
    this.contextInfo = '',
    this.statusMessage = '',
    this.needsRefresh = false,
    this.executionProof = ExecutionProof.defaultSuccess,
    this.data = const {},
  });

  /// 合併多個 SkillResult
  SkillResult merge(SkillResult other) {
    // 合併 data 字典
    final mergedData = Map<String, dynamic>.from(data)..addAll(other.data);

    // 簡化版的 merge executionProof，只要有一個失敗就算整體不完全成功 (這裡只做簡單保留)
    final mergedProof =
        (!executionProof.success) ? executionProof : other.executionProof;

    return SkillResult(
      contextInfo: [
        contextInfo,
        other.contextInfo,
      ].where((s) => s.isNotEmpty).join('\n'),
      statusMessage: other.statusMessage.isNotEmpty
          ? other.statusMessage
          : statusMessage,
      needsRefresh: needsRefresh || other.needsRefresh,
      executionProof: mergedProof,
      data: mergedData,
    );
  }

  static const empty = SkillResult();
}
