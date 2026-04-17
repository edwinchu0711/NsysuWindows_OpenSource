import 'skill_result.dart';
import 'skill_context.dart';

class ContextBuilder {
  static String build({
    required String userText,
    required List<SkillResult> results,
    required SkillContext ctx,
  }) {
    const langInstruction =
        '請務必只使用「繁體中文」或「英文」回答，若是使用者用用英文問你那就回復英文，反之則用「繁體中文」，並且回答方式可以使用 markdown 格式。\n並且回復不要太簡陋，稍微詳細一點點就好。';

    final parts = <String>[langInstruction];

    // 彙整所有 Skill 的資訊
    final combinedContext = results
        .map((r) => r.contextInfo)
        .where((info) => info.isNotEmpty)
        .join('\n\n');

    if (combinedContext.isNotEmpty) {
      parts.add('【參考資訊與背景】\n$combinedContext');
    }

    if (ctx.scheduleStr.isNotEmpty) {
      parts.add('【目前課表】\n${ctx.scheduleStr}');
    }

    parts.add('請根據以上資訊與上下文回答使用者的問題：$userText');

    return parts.join('\n\n');
  }
}
