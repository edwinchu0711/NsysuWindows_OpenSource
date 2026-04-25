import 'skill.dart';
import '../skill_context.dart';
import '../skill_result.dart';
import '../../course_query_service.dart';
import '../../local_course_service.dart';
import '../../database_embedding_service.dart';
import 'review_search_skill.dart';

class CourseFilterSkill implements Skill {
  final ReviewSearchSkill _reviewSkill;

  CourseFilterSkill(this._reviewSkill);

  @override
  String get name => 'course_filter';

  @override
  String get description =>
      '搜尋本學期開課的課程。適用於：特定向度/博雅/系所篩選（用 department 參數）、特定時段篩選（用 days/periods 參數）、特定課程名稱查詢（用 keyword 參數）、推薦特定條件的課程（用 isRecommendation）。當使用者提到博雅、向度、通識、特定星期/時段時，請使用此工具而非 review_search。';

  @override
  Map<String, dynamic> toToolJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          'keyword': {'type': 'string', 'description': '課程名稱或老師名稱關鍵字'},
          'keywords': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                '一組興趣關鍵字。若使用者需求模糊（如：想玩水、想運動），請根據你的知識庫，將其展開為具體的課程關鍵字（如：["游泳", "風帆", "潛水"]）填入此欄位，系統會根據這些詞進行綜合搜尋。',
          },
          'days': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': ['1', '2', '3', '4', '5', '6', '7'],
            },
            'description': '星期幾 (1-7)',
          },
          'periods': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '節次 (如: 1, 2, A, B, C)',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '課程分類標籤（僅限課程類型），例如 ["博雅", "體育", "向度1"]。注意：評價屬性標籤（如涼課、報告、期末等）不屬於此欄位，請改用 review_search 的 tags。',
          },
          'isRecommendation': {
            'type': 'boolean',
            'description': '是否為推薦模式，若為 true 則會加強課程評價權重',
          },
          'isComparison': {'type': 'boolean', 'description': '是否要比對現有課程評價'},
          'department': {
            'type': 'string',
            'description':
                '系所或向度篩選。科系名稱請填入完整名稱（如：資工系、資工碩、電機系、外文系）。碩士班系所名稱通常以「碩」結尾（如：資工碩、電機碩），博士班以「博」結尾（如：資工博）。博雅/向度請填入：博雅、博雅向度一~六。其他固定選項：中學學程、中文思辨與表達、英文初級/中級/中高級/高級、運動健康(必)、運動進階(選)、AI聯盟、跨院選修、跨院ESP、跨院EAP、管理學院。「博雅」會模糊匹配所有博雅向度課程。',
          },
          'grade': {
            'type': 'string',
            'description': '年級篩選。"1"=大一，"2"=大二，"3"=大三，"4"=大四，"0"=不限年級。注意：碩博班的年級也是用1-4，但系所名稱不同（如「資工碩」是碩士班，「資工系」是大學部）。',
          },
          'compulsory': {
            'type': 'string',
            'enum': ['必', '選'],
            'description': '必選修篩選。「必」=必修課（multiple_compulsory=0），「選」=選修課（multiple_compulsory=1）。當使用者問「某系必修」時請填「必」。',
          },
          'targetCourseName': {'type': 'string', 'description': '要比對的目標課程名稱'},
          'existingCourseCode': {'type': 'string', 'description': '現有課表中的課程代碼'},
          'filterConflict': {
            'type': 'boolean',
            'description': '是否過濾掉與目前課表衝突的課程',
          },
          'excludeKeywords': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '要排除的關鍵字（如：不想上"游泳"課）',
          },
        },
      },
    },
  };

  static const Map<String, List<String>> semanticExpansion = {
    '玩水': ['帆船', '潛水', '水球', '划船', '衝浪', '水上', '獨木舟'],
    '水上': ['帆船', '潛水', '水球', '划船', '衝浪', '獨木舟'],
    '水': ['游泳', '帆船', '潛水', '水球', '划船', '衝浪', '水上', '獨木舟'],
    '海': ['帆船', '潛水', '衝浪', '獨木舟', '海洋', '西子灣', '玩水'],
    '球': ['籃球', '排球', '羽球', '桌球', '網球', '足球', '棒球', '壘球'],
    '藝術': ['繪畫', '陶藝', '音樂', '舞蹈', '攝影', '書法', '人文'],
    '戶外': ['登山', '攀岩', '定向越野', '露營', '健行'],
    '體育': ['運動與健康', '體育', '瑜珈', '游泳', '球'],
    '運動與健康': ['體育', '瑜珈', '游泳', '球'],
    '涼': ['推薦', '甜', '涼', '博雅', '好處', '輕鬆'],
    '甜': ['推薦', '甜', '涼', '博雅', '高分'],
  };

  List<String> _expandKeywords(List<String> rawKeywords) {
    return rawKeywords
        .expand((kw) => semanticExpansion[kw] ?? [kw])
        .toSet() // 去除重複
        .toList();
  }

  @override
  Future<SkillResult> execute(
    Map<String, dynamic> params,
    SkillContext ctx,
  ) async {
    // Guard: check course database availability
    if (!LocalCourseService.instance.isInitialized) {
      return const SkillResult(
        contextInfo: '\n[課程資料庫尚未下載，請前往設定 > 資料庫下載，或登入後自動建立]\n',
        statusMessage: '課程資料庫未初始化',
      );
    }

    String contextInfo = '';
    Map<String, dynamic> outputData = {};

    final isRecommendationRaw = params['isRecommendation'];
    final isRecommendation = isRecommendationRaw == true || isRecommendationRaw?.toString().toLowerCase() == 'true';

    // ── 比較邏輯 ──
    final isComparisonRaw = params['isComparison'];
    if (isComparisonRaw == true || isComparisonRaw?.toString().toLowerCase() == 'true') {
      ctx.onStatusUpdate?.call('正在進行課程比對');
      contextInfo += await _handleComparison(params, ctx);
    }

    // ── 條件篩選 / 課程名稱查詢 ──
    if (params['days'] != null ||
        params['tags'] != null ||
        params['keyword'] != null ||
        params['keywords'] != null ||
        params['periods'] != null ||
        params['department'] != null) {
      ctx.onStatusUpdate?.call(
        isRecommendation ? '正在為您尋找評價最好的課程' : '正在篩選符合條件的課程',
      );
      final filterRes = await _handleFilter(
        params,
        ctx,
        isRecommendation: isRecommendation,
      );
      contextInfo += filterRes.$1;
      outputData['courseNames'] = filterRes.$2;
      if (filterRes.$2.isNotEmpty) {
        outputData['firstCourseName'] = filterRes.$2.first;
      }
    }

    return SkillResult(
      contextInfo: contextInfo,
      data: outputData,
      executionProof: ExecutionProof.defaultSuccess, // 進階查詢視為成功操作
    );
  }

  // ────────────────────────────────────────────
  // 比較邏輯
  // ────────────────────────────────────────────
  Future<String> _handleComparison(
    Map<String, dynamic> params,
    SkillContext ctx,
  ) async {
    String info = '';
    final target = params['targetCourseName'] as String? ?? '';

    if (target.isNotEmpty) {
      final summary = await _reviewSkill.fetchSummary(target, maxLength: 150);
      if (summary.isNotEmpty) {
        info += '\n[待選課程評價: $target]\n$summary...\n';
      }
    }

    final existingCode = params['existingCourseCode'];
    if (existingCode != null && existingCode != 'null') {
      try {
        final allCourses = await LocalCourseService.instance.searchCourses();
        final course = allCourses.firstWhere((c) => c.id == existingCode);
        final summary = await _reviewSkill.fetchSummary(
          '${course.name} ${course.teacher}',
          maxLength: 150,
        );
        if (summary.isNotEmpty) {
          info += '\n[現有課程評價: ${course.name}]\n$summary...\n';
        }
      } catch (e) {
        info += '\n[錯誤] 課程比對載入失敗：$e\n';
        return info;
      }
    }

    return info;
  }

  // ────────────────────────────────────────────
  // 條件篩選 + 課程名稱查詢
  // ────────────────────────────────────────────
  Future<(String, List<String>)> _handleFilter(
    Map<String, dynamic> params,
    SkillContext ctx, {
    bool isRecommendation = false,
  }) async {
    try {
      await LocalCourseService.instance.init();
    } catch (e) {
      return ('\n[錯誤] 本地課程庫載入失敗，請稍後再試。\n原因：$e\n', <String>[]);
    }

    final rawTags = params['tags'];
    final List<String> tags = [];
    if (rawTags is List) {
      tags.addAll(rawTags.map((e) => e.toString()));
    } else if (rawTags is String && rawTags.isNotEmpty) {
      tags.add(rawTags);
    }

    // Extract department from tags (博雅/向度 → department filter)
    String? department = params['department'] as String?;
    final departmentKeywords = [
      '中學學程',
      '中文思辨與表達',
      '英文初級',
      '英文中級',
      '英文中高級',
      '英文高級',
      '運動健康(必)',
      '運動進階(選)',
      '博雅',
      '博雅向度一',
      '博雅向度二',
      '博雅向度三',
      '博雅向度四',
      '博雅向度五',
      '博雅向度六',
      'AI聯盟',
      '跨院選修',
      '跨院ESP',
      '跨院EAP',
      '管理學院',
    ];
    final departmentAliases = {
      '向度一': '博雅向度一',
      '向度二': '博雅向度二',
      '向度三': '博雅向度三',
      '向度四': '博雅向度四',
      '向度五': '博雅向度五',
      '向度六': '博雅向度六',
      '博雅一': '博雅向度一',
      '博雅二': '博雅向度二',
      '博雅三': '博雅向度三',
      '博雅四': '博雅向度四',
      '博雅五': '博雅向度五',
      '博雅六': '博雅向度六',
    };
    final extractedDeptTags = <String>[];
    for (final tag in tags.toList()) {
      // Check aliases first (e.g., "向度四" → "博雅向度四")
      if (departmentAliases.containsKey(tag)) {
        if (department == null) {
          department = departmentAliases[tag];
        }
        extractedDeptTags.add(tag);
        continue;
      }
      // Then check exact department keyword matches
      for (final dk in departmentKeywords) {
        if (tag == dk || tag.contains(dk)) {
          if (department == null) {
            department = dk;
          }
          extractedDeptTags.add(tag);
          break;
        }
      }
    }
    tags.removeWhere((t) => extractedDeptTags.contains(t));

    // Extract grade and compulsory filters
    final gradeParam = params['grade'] as String?;
    String? grade;
    if (gradeParam != null && gradeParam.isNotEmpty) {
      // Map Chinese grade names to DB values
      final gradeMap = {
        '大一': '1', '1': '1',
        '大二': '2', '2': '2',
        '大三': '3', '3': '3',
        '大四': '4', '4': '4',
        '不限': null, '0': null,
      };
      grade = gradeMap[gradeParam];
    }

    final compulsoryParam = params['compulsory'] as String?;
    int? compulsory;
    if (compulsoryParam != null) {
      if (compulsoryParam == '必') {
        compulsory = 0; // multiple_compulsory = 0 means 必修
      } else if (compulsoryParam == '選') {
        compulsory = 1; // multiple_compulsory = 1 means 選修
      }
    }

    final keywordParam = params['keyword'];
    final rawKeywordsList = <String>[];
    if (params['keywords'] is List) {
      rawKeywordsList.addAll(List<String>.from(params['keywords']));
    }

    if (keywordParam is List) {
      rawKeywordsList.addAll(keywordParam.map((e) => e.toString()));
    } else if (keywordParam is String && keywordParam.isNotEmpty) {
      rawKeywordsList.add(keywordParam);
    }
    rawKeywordsList.addAll(tags);

    // 過濾無意義的通用詞
    const stopWords = ['課程', '一門課', '課', '推薦', '介紹', '想找', '有沒有', '請問', '隨便'];
    rawKeywordsList.removeWhere((kw) => stopWords.contains(kw));

    final expandedKeywords = _expandKeywords(rawKeywordsList);
    print('--- [CourseFilterSkill] Search Parameters: ---');
    print('  - Raw Keywords: $rawKeywordsList');
    print('  - Expanded Keywords: $expandedKeywords');
    print('  - Days: ${params['days']}');
    print('  - Tags: ${params['tags']}');
    print('  - Is Recommendation: $isRecommendation');

    final keywordLogic =
        params['keywordLogic'] as String? ?? (isRecommendation ? 'OR' : 'AND');

    final hasDays = params['days'] != null;
    final hasPeriods = params['periods'] != null;
    final hasTags = tags.isNotEmpty;

    final isNameLookup =
        expandedKeywords.isNotEmpty && !hasDays && !hasPeriods && !hasTags;

    Set<CourseJsonData> filteredSet = {};

    // 處理展開後的搜尋 (OR 邏輯對 keywords)
    if (expandedKeywords.isNotEmpty && keywordLogic == 'OR') {
      for (final kw in expandedKeywords) {
        final res = await LocalCourseService.instance.searchCourses(
          days: _normalizeDays(params['days']),
          periods: _normalizePeriods(params['periods']),
          keyword: kw,
          department: department,
          grade: grade,
          compulsory: compulsory,
        );
        filteredSet.addAll(res);
      }
    } else {
      final combinedQuery = expandedKeywords.join(' ');
      final res = await LocalCourseService.instance.searchCourses(
        days: _normalizeDays(params['days']),
        periods: _normalizePeriods(params['periods']),
        keyword: combinedQuery.isNotEmpty ? combinedQuery : null,
        department: department,
        grade: grade,
        compulsory: compulsory,
      );
      filteredSet.addAll(res);
    }

    // 處理 Filter Conflict 本地端邏輯
    final filterConflictRaw = params['filterConflict'];
    if (filterConflictRaw == true || filterConflictRaw?.toString().toLowerCase() == 'true') {
      final Set<String> occupiedSlots = {};

      for (var c in ctx.currentCourses) {
        final pTimes = c.toJson()['parsedTimes'] as List?;
        if (pTimes != null) {
          for (var t in pTimes) {
            occupiedSlots.add("${t['day']}-${t['period']}");
          }
        }
      }

      for (var e in ctx.currentEvents) {
        final eJson = e.toJson();
        final day = eJson['day'];
        final ps = eJson['periods'] as List?;
        if (day != null && ps != null) {
          for (var p in ps) {
            occupiedSlots.add("$day-$p");
          }
        }
      }

      filteredSet.removeWhere((course) {
        for (int i = 0; i < 7; i++) {
          if (course.classTime[i].isNotEmpty) {
            String day = (i + 1).toString();
            String cleaned = course.classTime[i]
                .replaceAll(',', '')
                .replaceAll(' ', '');
            for (int k = 0; k < cleaned.length; k++) {
              if (occupiedSlots.contains("$day-${cleaned[k]}"))
                return true; // Conflicting
            }
          }
        }
        return false;
      });
    }

    final filtered = filteredSet.toList();

    // 🔄 智慧回退機制 (Fallback)：如果是推薦任務但沒搜到課，放寬條件重新搜
    if (filtered.isEmpty && isRecommendation && (hasDays || hasPeriods)) {
      final res = await LocalCourseService.instance.searchCourses(
        days: _normalizeDays(params['days']),
        periods: _normalizePeriods(params['periods']),
        department: department,
        grade: grade,
        compulsory: compulsory,
      );
      filteredSet.addAll(res);
    }

    final finalFiltered = filteredSet.where((course) {
      if (params['excludeKeywords'] is List) {
        final excludes = List<String>.from(params['excludeKeywords']);
        for (final ex in excludes) {
          if (course.name.contains(ex) || course.teacher.contains(ex)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    // --- 課程名稱去重邏輯 ---
    // 解決「相同名字的課程（如游泳）出現太多次」的問題。
    final uniqueNameSet = <String>{};
    final deduplicatedList = <CourseJsonData>[];
    for (final course in finalFiltered) {
      if (!uniqueNameSet.contains(course.name)) {
        uniqueNameSet.add(course.name);
        deduplicatedList.add(course);
      }
    }

    // 隨機打亂順序，增加探索性
    deduplicatedList.shuffle();

    print(
      '--- [CourseFilterSkill] Deduplicated & Shuffled Count: ${deduplicatedList.length} ---',
    );

    // 🏆 為避免單一類別霸佔版面，若結果太多，這裡可以再限制總數
    final displayList = deduplicatedList.take(20).toList();

    if (displayList.isNotEmpty) {
      print(
        '--- [CourseFilterSkill] Top Results: ${displayList.take(3).map((c) => c.name).toList()} ---',
      );
    }

    final namesToReturn = displayList
        .map((c) => "${c.name} ${c.teacher}")
        .toList();

    if (displayList.isEmpty) {
      if (isNameLookup) {
        return (
          '\n[課程查詢結果]\n找不到與「\${expandedKeywords.join(",")}」相關的課程。\n',
          <String>[],
        );
      } else {
        final criteria = <String>[];
        if (expandedKeywords.isNotEmpty)
          criteria.add("關鍵字: ${expandedKeywords.join(',')}");
        if (hasDays) criteria.add("星期: ${params['days']}");
        if (hasPeriods) criteria.add("節次: ${params['periods']}");
        return ("\n[篩選結果]\n找不到符合以下條件的課程：\n${criteria.join('、')}\n", <String>[]);
      }
    }

    if (isNameLookup && !isRecommendation) {
      return (
        _buildNameLookupResult(expandedKeywords.join(','), filtered),
        namesToReturn,
      );
    }

    return (
      await _buildFilterResult(
        displayList,
        ctx,
        isRecommendation: isRecommendation,
      ),
      namesToReturn,
    );
  }

  // ────────────────────────────────────────────
  // 純名稱查詢結果格式化
  // ────────────────────────────────────────────
  String _buildNameLookupResult(String keyword, List<CourseJsonData> courses) {
    final buffer = StringBuffer();
    buffer.writeln('\n[✅ 本學期開課清單 - 只有出現在此清單中的課本學期才有開]');
    buffer.writeln('[課程查詢結果：「$keyword」]');

    for (final c in courses.take(30)) {
      buffer.writeln(_formatCourseDetail(c));
    }

    if (courses.length > 30) {
      buffer.writeln('（共找到 ${courses.length} 筆，僅顯示前 30 筆）');
    }

    return buffer.toString();
  }

  // ────────────────────────────────────────────
  // 條件篩選結果格式化（含課程評價 + cross-table 驗證）
  // ────────────────────────────────────────────
  Future<String> _buildFilterResult(
    List<CourseJsonData> courses,
    SkillContext ctx, {
    bool isRecommendation = false,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('\n[✅ 本學期開課清單 - 只有出現在此清單中的課本學期才有開]');

    // ── 推薦模式：cross-table 驗證 + 評價排名 ──
    if (isRecommendation) {
      buffer.writeln('[為您推薦的精選課程 (本學期確認有開，且有評價資料)]：');
      try {
        await DatabaseEmbeddingService.instance.init();
      } catch (e) {
        buffer.writeln('[錯誤] 評價資料庫載入失敗: $e');
        return buffer.toString();
      }

      // Step 1: 對每門課，用 findByName 取得精確匹配的評價
      final coursesWithReviews = <Map<String, dynamic>>[];
      final coursesWithoutReviews = <CourseJsonData>[];
      for (final c in courses) {
        final reviews = DatabaseEmbeddingService.instance.findByName(c.name);
        if (reviews.isNotEmpty) {
          // 合併所有評價為一個摘要
          final reviewContent = reviews
              .map((r) {
                final prof = r['professor']?.toString() ?? '';
                final content = r['content']?.toString() ?? '';
                final source = r['source']?.toString() ?? '';
                final preview = content.length > 300
                    ? content.substring(0, 300)
                    : content;
                return '[$source] ${prof.isNotEmpty ? "教授: $prof" : ""} $preview';
              })
              .join(' / ');
          coursesWithReviews.add({
            'course': c,
            'reviews': reviews,
            'reviewContent': reviewContent,
          });
        } else {
          coursesWithoutReviews.add(c);
        }
      }

      // Step 2: 根據評價關鍵字評分排序（涼/甜/推薦/好過 → 高分）
      coursesWithReviews.sort((a, b) {
        final contentA = a['reviewContent'] as String;
        final contentB = b['reviewContent'] as String;
        return _scoreReviewRelevance(
          contentB,
        ).compareTo(_scoreReviewRelevance(contentA));
      });

      // Step 3: 顯示有評價的課程
      final showCount = 20;
      final topCourses = coursesWithReviews.take(showCount).toList();

      for (final item in topCourses) {
        final c = item['course'] as CourseJsonData;
        final reviewContent = item['reviewContent'] as String;
        final preview = reviewContent.length > 200
            ? reviewContent.substring(0, 200)
            : reviewContent;

        buffer.writeln(_formatCourseDetail(c));
        buffer.writeln('  > 💡 評價: $preview...');
        buffer.writeln('-----------------------');
      }

      if (coursesWithReviews.length > showCount) {
        buffer.writeln(
          '（共 ${coursesWithReviews.length} 筆有評價的課程，僅顯示前 $showCount 筆）',
        );
      }

      // Step 4: 顯示沒有評價的課程（仍然列出，註明暫時找不到評價）
      if (coursesWithoutReviews.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('[以下課程本學期有開，但暫時找不到評價資料]：');
        for (final c in coursesWithoutReviews.take(15)) {
          buffer.writeln(_formatCourseDetail(c));
          buffer.writeln('  > ⚠️ 暫時找不到評價');
          buffer.writeln('-----------------------');
        }
        if (coursesWithoutReviews.length > 15) {
          buffer.writeln('（另有 ${coursesWithoutReviews.length - 15} 筆課程暫無評價）');
        }
      }

      if (coursesWithReviews.isEmpty && coursesWithoutReviews.isEmpty) {
        buffer.writeln('找不到符合條件的課程。');
      }

      return buffer.toString();
    }

    // ── 非推薦模式：原本的行為 ──
    buffer.writeln('[符合條件課程摘要 (本學期確認有開)]：');
    final showCount = 10;
    final topCourses = courses.take(showCount).toList();

    // 並行抓取課程評價，並加上逾時處理
    final List<Future<String>> dcardFutures = topCourses.map((c) {
      return _reviewSkill
          .fetchSummary('${c.name} ${c.teacher}', maxLength: 100)
          .timeout(const Duration(seconds: 8), onTimeout: () => '');
    }).toList();

    final List<String> summaries = await Future.wait(dcardFutures);

    for (int i = 0; i < topCourses.length; i++) {
      final c = topCourses[i];
      final summary = summaries[i];

      buffer.writeln(_formatCourseDetail(c));
      if (summary.isNotEmpty) {
        buffer.writeln('  > 評價: $summary...');
      }
      buffer.writeln('-----------------------');
    }

    if (courses.length > showCount) {
      buffer.writeln('（共找到 ${courses.length} 筆，僅顯示前 $showCount 筆）');
    }

    return buffer.toString();
  }

  /// 根據評價關鍵字對評論內容評分（用於排序推薦課程）
  static int _scoreReviewRelevance(String content) {
    int score = 0;
    const positiveKeywords = [
      '推薦',
      '涼',
      '甜',
      '好過',
      '輕鬆',
      '好評',
      '不錯',
      '好課',
      '高分',
      '開心',
      '有趣',
      '收穫',
    ];
    const negativeKeywords = [
      '雷',
      '硬',
      '當人',
      '難',
      '作業多',
      '痛苦',
      '後悔',
      '地獄',
      '惡搞',
    ];
    for (final kw in positiveKeywords) {
      if (content.contains(kw)) score += 2;
    }
    for (final kw in negativeKeywords) {
      if (content.contains(kw)) score -= 1;
    }
    return score;
  }

  List<String>? _normalizeDays(dynamic days) {
    if (days == null) return null;
    final list = days is List ? days : [days];
    final Map<String, String> dayMap = {
      '一': '1',
      '1': '1',
      'Mon': '1',
      '二': '2',
      '2': '2',
      'Tue': '2',
      '三': '3',
      '3': '3',
      'Wed': '3',
      '四': '4',
      '4': '4',
      'Thu': '4',
      '五': '5',
      '5': '5',
      'Fri': '5',
      '六': '6',
      '6': '6',
      'Sat': '6',
      '日': '7',
      '7': '7',
      'Sun': '7',
    };
    return list
        .map((e) => dayMap[e.toString().replaceAll('週', '')] ?? e.toString())
        .toList();
  }

  List<String>? _normalizePeriods(dynamic periods) {
    if (periods == null) return null;
    final list = periods is List ? periods : [periods];
    return list.map((e) {
      return e
          .toString()
          .replaceAll('第', '')
          .replaceAll('節', '')
          .replaceAll(',', '')
          .replaceAll(' ', '');
    }).toList();
  }

  String _formatCourseDetail(CourseJsonData c) {
    const dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final timeParts = <String>[];
    for (int i = 0; i < c.classTime.length && i < 7; i++) {
      if (c.classTime[i].isNotEmpty) {
        timeParts.add('週${dayLabels[i]} 第${c.classTime[i]}節');
      }
    }
    final timeStr = timeParts.isNotEmpty ? timeParts.join('、') : '時間未定';
    final compulsoryLabel = c.multipleCompulsory == 0 ? '必修' : '選修';

    return '''
📘 ${c.name}
 • 課程代碼：${c.id}
 • 授課教師：${c.teacher}
 • 學分：${c.credit}
 • 必/選修：$compulsoryLabel
 • 上課時間：$timeStr
 • 上課地點：${c.room.isNotEmpty ? c.room : '未提供'}
 • 開課系所：${c.department}
''';
  }
}
