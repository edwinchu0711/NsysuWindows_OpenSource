import 'skill.dart';
import '../skill_context.dart';
import '../skill_result.dart';
import '../../database_embedding_service.dart';

class RuleQuerySkill implements Skill {
  @override
  String get name => 'rule_query';

  @override
  String get description =>
      '查詢本學期選課規則與相關規定。適用於：加退選時程、選課點數、必修確認流程、超修學分、棄選規定、選課異常處理等「本學期選課制度」相關問題。';

  @override
  Map<String, dynamic> toToolJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                '使用者關於選課規則的問題（例如：「加退選一是什麼時候」「選課點數怎麼填」「超修學分上限是多少」「棄選規定是什麼」）',
          },
        },
        'required': ['query'],
      },
    },
  };

  @override
  Future<SkillResult> execute(
    Map<String, dynamic> params,
    SkillContext ctx,
  ) async {
    // Guard: check database availability
    if (!DatabaseEmbeddingService.instance.isInitialized) {
      return const SkillResult(
        contextInfo: '\n[選課規則資料庫尚未下載，請前往設定 > 資料庫下載]\n',
        statusMessage: '資料庫未初始化',
      );
    }

    final query = params['query'] as String?;
    if (query == null || query.isEmpty) {
      return SkillResult.empty;
    }

    ctx.onStatusUpdate?.call("正在查詢選課規則");

    try {
      await DatabaseEmbeddingService.instance.init();
      final results = await DatabaseEmbeddingService.instance.searchRules(
        query,
        k: 8,
        threshold: 0.40,
      );

      if (results.isEmpty) {
        return SkillResult(
          contextInfo: '\n[選課規則查詢結果]\n找不到與「$query」相關的選課規則。建議您參閱選課須知或聯繫教務處。\n',
          statusMessage: '找不到相關規則',
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('\n[選課規則查詢結果]');
      buffer.writeln('以下是與「$query」相關的選課規定：\n');

      for (final r in results) {
        final content = r['content']?.toString() ?? '';
        final similarity = r['similarity'] as double? ?? 0.0;
        if (content.isNotEmpty && similarity > 0) {
          // Clean up markdown artifacts for readability
          final cleaned = content
              .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
              .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
              .replaceAll(RegExp(r'<u>(.*?)</u>'), r'$1')
              .replaceAll(RegExp(r'<mark>(.*?)</mark>'), r'$1')
              .replaceAll(RegExp(r'<br\s*/?>'), '\n')
              .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
              .trim();
          if (cleaned.isNotEmpty) {
            buffer.writeln('---');
            buffer.writeln(cleaned);
          }
        }
      }
      buffer.writeln('\n（以上資訊來自本學期選課須知，如有疑問請洽教務處課務組）');

      return SkillResult(
        contextInfo: buffer.toString(),
        statusMessage: '已找到相關選課規則',
      );
    } catch (e) {
      print('[RuleQuerySkill] Error: $e');
      return SkillResult(
        contextInfo: '\n[選課規則查詢結果]\n查詢選課規則時發生錯誤，請稍後再試。\n',
        statusMessage: '查詢失敗',
      );
    }
  }
}
