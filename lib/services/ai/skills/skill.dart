import '../skill_context.dart';
import '../skill_result.dart';

abstract class Skill {
  /// 技能名稱
  String get name;

  /// 技能描述
  String get description;

  /// 回傳符合 OpenAI/Google 工具定義的 JSON Schema
  Map<String, dynamic> toToolJson();

  /// 執行技能
  Future<SkillResult> execute(Map<String, dynamic> params, SkillContext ctx);
}
