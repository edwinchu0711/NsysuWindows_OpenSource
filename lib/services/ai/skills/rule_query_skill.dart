import 'skill.dart';
import '../skill_context.dart';
import '../skill_result.dart';
import '../../pdf_rule_service.dart';

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
    final query = params['query'] as String?;
    if (query == null || query.isEmpty) {
      return SkillResult.empty;
    }

    ctx.onStatusUpdate?.call("正在下載選課須知...");

    final success = await PdfRuleService.instance.fetchAndCache();

    if (!success || !PdfRuleService.instance.isLoaded) {
      final error = PdfRuleService.instance.lastErrorMessage ?? '無法載入選課須知，請稍後再試。';
      return SkillResult(
        contextInfo: '\n[選課規則查詢結果]\n無法載入選課須知：$error\n',
        statusMessage: '選課須知載入失敗',
      );
    }

    final fullText = PdfRuleService.instance.fullText ?? '';
    if (fullText.isEmpty) {
      return SkillResult(
        contextInfo: '\n[選課規則查詢結果]\n選課須知內容為空，請稍後再試。\n',
        statusMessage: '選課須知內容為空',
      );
    }

    ctx.onStatusUpdate?.call("已載入選課須知，正在整理回覆");

    final buffer = StringBuffer();
    buffer.writeln('\n[選課規則查詢結果]');
    buffer.writeln('以下是本學期選課須知的完整內容：\n');
    buffer.writeln(fullText);
    buffer.writeln('\n（以上為本學期選課須知完整內容，如有疑問請洽教務處課務組）');

    return SkillResult(
      contextInfo: buffer.toString(),
      statusMessage: '已載入選課須知全文',
    );
  }
}
