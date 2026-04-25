import 'skill.dart';
import '../skill_context.dart';
import '../skill_result.dart';
// import '../intent_classifier.dart';
import '../../../../models/course_model.dart';
import '../../course_query_service.dart';
import 'schedule_read_skill.dart';

class ScheduleWriteSkill implements Skill {
  @override
  String get name => 'schedule_write';

  @override
  String get description => '新增、移除或清空課表中的課程。';

  // 語義對照表，用於處理如「體育課」對應到「運動與健康」的情況
  final Map<String, List<String>> _semanticExpansion = {
    '體育': ['運動與健康', '運動', '健身'],
    '體育課': ['運動與健康', '運動', '健身'],
    '通識': ['博雅', '向度'],
  };

  List<String> _expandKeywords(String? input) {
    if (input == null || input.isEmpty) return [];
    return _semanticExpansion[input] ?? [input];
  }

  @override
  Map<String, dynamic> toToolJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['add', 'remove', 'clear'],
            'description': '具體動作：add (新增), remove (移除), clear (全部清空)',
          },
          'courseName': {'type': 'string', 'description': '課程名稱關鍵字'},
          'courseCode': {'type': 'string', 'description': '課程代碼 (優先級高於名稱)'},
          'days': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': ['1', '2', '3', '4', '5', '6', '7'],
            },
            'description': '指定星期幾 (1-7)',
          },
          'periods': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': [
                'A',
                '1',
                '2',
                '3',
                '4',
                'B',
                '5',
                '6',
                '7',
                '8',
                '9',
                'C',
                'D',
                'E',
                'F',
              ],
            },
            'description': '指定具體節次，可用於精確移除某個時段的課程',
          },
        },
        'required': ['action'],
      },
    },
  };

  @override
  Future<SkillResult> execute(
    Map<String, dynamic> params,
    SkillContext ctx,
  ) async {
    ctx.onStatusUpdate?.call('正在調整您的課表');
    String result = '';

    final actionType = params['action'] as String? ?? '';
    final name = params['courseName'] as String? ?? '';
    final targetCode =
        (params['courseCode'] != null && params['courseCode'] != 'null')
        ? params['courseCode'] as String
        : null;

    final periodsRaw = params['periods'];
    final periodsParam = (periodsRaw is List)
        ? periodsRaw
        : (periodsRaw != null ? [periodsRaw] : null);
    final List<String>? targetPeriods = periodsParam != null
        ? periodsParam
              .map(
                (e) => e
                    .toString()
                    .replaceAll('"', '') // 移除雙引號
                    .replaceAll("'", ''), // 移除單引號
              )
              .toList()
        : null;

    if (actionType.isEmpty) {
      return SkillResult(
        contextInfo: '❌ 未指定操作動作（新增或移除）。',
        executionProof: ExecutionProof(
          success: false,
          evidence: '',
          errorDetail: '未指定 action',
        ),
      );
    }

    await CourseQueryService.instance.getCourses();
    CourseJsonData? match;

    if (targetCode != null) {
      final codes = CourseQueryService.instance.search(query: targetCode);
      if (codes.isNotEmpty) match = codes.first;
    }

    if (match == null && name.isNotEmpty) {
      // 嘗試語義展開搜尋
      final expandedList = _expandKeywords(name);
      final daysRaw = params['days'];
      final List<String>? daysFilter = (daysRaw != null)
          ? (daysRaw is List ? daysRaw : [daysRaw])
                .map(
                  (e) => e
                      .toString()
                      .replaceAll('"', '') // 移除雙引號
                      .replaceAll("'", ''),
                ) // 移除單引號
                .toList()
          : null;

      for (final kw in expandedList) {
        final results = CourseQueryService.instance.search(
          query: kw,
          days: daysFilter, // 加入星期過濾
        );
        if (results.isNotEmpty) {
          match = results.first;
          break;
        }
      }
    }

    if (actionType == 'add') {
      result += _handleAdd(match, name, ctx);
    } else if (actionType == 'remove') {
      result += _handleRemove(
        match,
        name,
        targetCode,
        ctx,
        params,
        targetPeriods,
      );
    } else if (actionType == 'clear') {
      result += _handleClear(ctx);
    }

    // 儲存更新後的課表
    await ScheduleReadSkill.saveFromContext(ctx);

    bool isSuccess = result.contains('✅');
    if (result.isNotEmpty) result += '\n(頁面將自動重新整載)';

    return SkillResult(
      contextInfo:
          '[操作結果]\n$result\n[更新後的課表]\n${ctx.currentCourses.map((c) => c.name).join(', ')}',
      needsRefresh: isSuccess,
      executionProof: ExecutionProof(
        success: isSuccess,
        evidence: isSuccess ? result : '',
        errorDetail: !isSuccess ? result : null,
      ),
    );
  }

  String _handleAdd(CourseJsonData? match, String name, SkillContext ctx) {
    if (match == null) return '\n❌ 找不到課程「$name」。';
    if (ctx.currentCourses.any((c) => c.code == match.id)) {
      return '\n「${match.name}」已在課表中。';
    }

    final pts = <CourseTime>[];
    for (int i = 0; i < 7; i++) {
      final dayPeriods = match.classTime[i];
      if (dayPeriods.isNotEmpty) {
        final cleaned = dayPeriods.replaceAll(',', '').replaceAll(' ', '');
        for (int j = 0; j < cleaned.length; j++) {
          pts.add(CourseTime(i + 1, cleaned[j]));
        }
      }
    }

    ctx.currentCourses.add(
      Course(
        code: match.id,
        name: match.name,
        professor: match.teacher,
        credits: match.credit,
        timeString: match.classTime.join(', '),
        location: match.room,
        required: match.description.contains('必') ? '必' : '選',
        detailUrl: '',
        parsedTimes: pts,
        department: match.department,
        description: match.description,
      ),
    );

    return '\n✅ 已新增「${match.name}」。';
  }

  String _handleRemove(
    CourseJsonData? match,
    String name,
    String? targetCode,
    SkillContext ctx,
    Map<String, dynamic> params,
    List<String>? targetPeriods,
  ) {
    final removedNames = <String>[];

    // 1. 處理「星期幾」與「節次」組合刪除
    final daysParam = params['days'];
    if (daysParam != null || targetPeriods != null) {
      final daysToMatch = (daysParam != null)
          ? (daysParam is List
                ? daysParam
                      .map(
                        (e) => e
                            .toString()
                            .replaceAll('"', '') // 移除雙引號
                            .replaceAll("'", ''),
                      ) // 移除單引號
                      .toList()
                : [
                    daysParam
                        .toString()
                        .replaceAll('"', '') // 移除雙引號
                        .replaceAll("'", ''),
                  ]) // 移除單引號
          : null;

      final toRemove = ctx.currentCourses.where((course) {
        return course.parsedTimes.any((t) {
          final isDayMatch =
              daysToMatch == null || daysToMatch.contains(t.day.toString());
          final isPeriodMatch =
              targetPeriods == null || targetPeriods.contains(t.period);
          return isDayMatch && isPeriodMatch;
        });
      }).toList();

      for (var r in toRemove) {
        if (!removedNames.contains(r.name)) removedNames.add(r.name);
        ctx.currentCourses.removeWhere((c) => c.code == r.code);
      }
    }

    // 2. 如果沒提供 days 或沒刪到，按代碼刪除
    if (removedNames.isEmpty && targetCode != null && targetCode.isNotEmpty) {
      final toRemove = ctx.currentCourses
          .where((c) => c.code == targetCode)
          .toList();
      removedNames.addAll(toRemove.map((c) => c.name));
      ctx.currentCourses.removeWhere((c) => c.code == targetCode);
    }

    // 3. 如果還是沒刪到，用名稱關鍵字模糊匹配
    if (removedNames.isEmpty && name.isNotEmpty) {
      final kw = name.toLowerCase();
      final toRemove = ctx.currentCourses
          .where(
            (c) =>
                c.name.toLowerCase().contains(kw) ||
                c.code.toLowerCase().contains(kw) ||
                c.professor.toLowerCase().contains(kw),
          )
          .toList();
      removedNames.addAll(toRemove.map((c) => c.name));
      for (final r in toRemove) {
        ctx.currentCourses.removeWhere((c) => c.code == r.code);
      }
    }

    if (removedNames.isNotEmpty) {
      return '\n✅ 已成功移除：${removedNames.join('、')}。';
    } else {
      final courseList = ctx.currentCourses.isEmpty
          ? '（課表目前為空）'
          : ctx.currentCourses.map((c) => '「${c.name}」').join('、');
      return '\n❌ 找不到符合條件的課程。目前課表：$courseList';
    }
  }

  String _handleClear(SkillContext ctx) {
    final count = ctx.currentCourses.length;
    ctx.currentCourses.clear();
    return '\n✅ 已成功清空課表（共移除 $count 門課程）。';
  }
}
