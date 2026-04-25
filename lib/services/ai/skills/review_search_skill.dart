import 'skill.dart';
import '../skill_context.dart';
import '../skill_result.dart';
import '../../database_embedding_service.dart';
import '../../local_course_service.dart';

class ReviewSearchSkill implements Skill {
  @override
  String get name => 'review_search';

  @override
  String get description =>
      '搜尋課程評價、歷史心得或課程內容基準（資料庫來自歷年評價）。適用於：查詢特定課程/教授的評價、模糊語義搜尋（如「涼課推薦」）。注意：此工具回傳的是「歷史評價」，不代表本學期有開課。若要篩選特定向度/系所/時段的課程，請使用 course_filter 工具的 department/days/periods 參數。';

  @override
  Map<String, dynamic> toToolJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          'keyword': {'type': 'string', 'description': '搜尋關鍵字（例如課程名、老師名）'},
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                '評價屬性標籤，例如：涼課, 報告, 期末, 分組, 出席, 英文, 向度三。當使用者提到「涼課」「報告課」等評價屬性時，請將其放入此欄位。',
          },
          'isRecommendation': {
            'type': 'boolean',
            'description':
                '是否為「推薦課程」的情境。如果是，系統會自動在結果附帶「本學期是否有開課」的驗證標記。若僅是查詢評價，設為 false。',
          },
          'query_count': {
            'type': 'integer',
            'description': '本次任務預計執行的總搜尋次數（系統自動計算）',
          },
        },
        'required': ['keyword'],
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
        contextInfo: '\n[評價資料庫尚未下載，請前往設定 > 資料庫下載]\n',
        statusMessage: '資料庫未初始化',
      );
    }

    final keyword = params['keyword']?.toString();
    final isRecommendationRaw = params['isRecommendation'];
    final isRecommendation = (isRecommendationRaw is bool)
        ? isRecommendationRaw
        : (isRecommendationRaw?.toString().toLowerCase() == 'true');
    final tagsRaw = params['tags'];
    final tagsParam = (tagsRaw is List)
        ? tagsRaw
        : (tagsRaw != null ? [tagsRaw] : null);
    final queryCountRaw = params['query_count'];
    final queryCount = (queryCountRaw is int)
        ? queryCountRaw
        : (int.tryParse(queryCountRaw?.toString() ?? '') ?? 1);

    if (keyword == null || keyword.toLowerCase() == 'null') {
      return SkillResult.empty;
    }

    // 動態決定 K 值
    int k = 8;
    if (queryCount >= 7) {
      k = 3;
    } else if (queryCount >= 5) {
      k = 4;
    } else if (queryCount >= 3) {
      k = 5;
    }

    // 標籤處理
    List<String> tags = [];
    if (tagsParam != null) {
      tags = tagsParam.map((e) => e.toString()).toList();
    } else {
      // 如果 AI 沒給標籤，嘗試從 keyword 自動提取
      for (final option in TAG_OPTIONS) {
        if (keyword.contains(option)) {
          tags.add(option);
        }
      }
    }

    ctx.onStatusUpdate?.call(
      "正在搜尋 '$keyword' ${tags.isNotEmpty ? '(標籤: ${tags.join(', ')})' : ''} 的評價",
    );
    String contextInfo = '';

    final List<String> foundCourseNames = [];

    try {
      print('--- [ReviewSearchSkill] Executing search for: $keyword ---');
      final searchItems = await DatabaseEmbeddingService.instance
          .embedAndSearch(keyword, k: k);

      if (searchItems.isNotEmpty) {
        ctx.onStatusUpdate?.call('正在彙整評價內容');
        contextInfo += '\n[評價與本學期開課驗證結果 (綜合)]\n';
        for (final item in searchItems) {
          final content = item['content']?.toString() ?? '';
          final source = item['source']?.toString() ?? '未知來源';
          final courseName = item['course_name']?.toString() ?? '';
          final professor = item['professor']?.toString() ?? '';

          List<dynamic> matchedCourses = [];
          String statusTag = "";

          // 驗證開課狀態 (僅在推薦模式時執行)
          if (isRecommendation) {
            // Normalize: strip "服務學習：" / "服務學習:" prefix before matching
            final normalizedCourseName = courseName.replaceAll(
              RegExp(r'服務學習[：:]\s*'),
              '',
            );
            matchedCourses = await LocalCourseService.instance
                .findMatchingCourses(normalizedCourseName, professor);
            if (matchedCourses.isNotEmpty) {
              foundCourseNames.addAll(
                matchedCourses.map((c) => c.name.toString()),
              );
              final matchedNames = matchedCourses
                  .take(3)
                  .map((c) => '${c.name}(${c.teacher})')
                  .toSet()
                  .join(', ');
              statusTag = "(本學期確認有開: $matchedNames)";
            } else {
              statusTag =
                  "(⚠️ 評論的課程名稱「$courseName」可能與本學期實際課程名稱不同，因此無法確定是否有開課。但根據您的需求，以下評價資訊仍可能具有參考價值，建議您再確認實際開課清單)";
            }
          }

          final preview = content.length > 500
              ? content.substring(0, 500)
              : content;

          contextInfo += '\n--- 評價 ($source) $statusTag ---\n';
          contextInfo += '對應課程資料: $courseName / $professor\n';
          contextInfo += '內容: $preview...\n';
        }
      } else {
        contextInfo += '\n(歷史資料庫暫時沒有 "$keyword" 的相關資料)\n';
      }
    } catch (e) {
      print('ReviewSearchSkill error: $e');
      contextInfo += '\n(無法取得評價，錯誤: $e)\n';
    }

    final outputData = {
      'foundCourseNames': foundCourseNames.toSet().toList(),
      'topCourseName': foundCourseNames.isNotEmpty
          ? foundCourseNames.first
          : keyword,
    };

    return SkillResult(contextInfo: contextInfo, data: outputData);
  }

  /// 搜尋單一課程並回傳摘要字串（供其他 Skill 複用）
  Future<String> fetchSummary(String query, {int maxLength = 150}) async {
    try {
      final res = await DatabaseEmbeddingService.instance.embedAndSearch(
        query,
        k: 1,
      );
      if (res.isNotEmpty) {
        final content = res.first['content']?.toString() ?? '';
        return content.length > maxLength
            ? content.substring(0, maxLength)
            : content;
      }
    } catch (_) {}
    return '';
  }

  static const List<String> TAG_OPTIONS = [
    "英文",
    "高級",
    "中高級",
    "博雅",
    "向度一",
    "向度二",
    "向度三",
    "向度四",
    "向度五",
    "向度六",
    "服務學習",
    "服學",
    "中文",
    "軍訓",
    "涼課",
    "ESP",
    "EAP",
    "游泳",
    "體適能",
    "報告",
    "期中",
    "期末",
    "分組",
    "出席",
    "跨院",
    "畢業",
    "科學",
  ];
}
