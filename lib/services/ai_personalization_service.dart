import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/utils.dart';
import 'storage_service.dart';
import 'historical_score_service.dart';

class CourseSelectionRawData {
  final String dept;
  final String courseNo;
  CourseSelectionRawData({required this.dept, required this.courseNo});
}

class CourseHistoryResult {
  final String semester;
  final String department;
  final String courseNo;
  final String courseName;
  final String credits;
  final String score;
  final bool passed;

  CourseHistoryResult({
    required this.semester,
    required this.department,
    required this.courseNo,
    required this.courseName,
    required this.credits,
    required this.score,
    required this.passed,
  });

  Map<String, dynamic> toJson() => {
    'semester': semester,
    'department': department,
    'courseNo': courseNo,
    'courseName': courseName,
    'credits': credits,
    'score': score,
    'passed': passed,
  };

  factory CourseHistoryResult.fromJson(Map<String, dynamic> json) =>
      CourseHistoryResult(
        semester: json['semester'] ?? '',
        department: json['department'] ?? '',
        courseNo: json['courseNo'] ?? '',
        courseName: json['courseName'] ?? '',
        credits: json['credits'] ?? '',
        score: json['score'] ?? '',
        passed: json['passed'] ?? false,
      );
}

class AiPersonalizationService {
  static final AiPersonalizationService instance =
      AiPersonalizationService._internal();
  AiPersonalizationService._internal();

  static const String TOGGLE_KEY = 'is_ai_course_history_enabled';
  static const String DATA_KEY = 'ai_course_history_data';

  final String _baseUrl = "https://selcrs.nsysu.edu.tw";
  final http.Client _client = http.Client();

  final ValueNotifier<List<CourseHistoryResult>> resultsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier("");

  Future<void> loadFromCache() async {
    try {
      String? jsonStr = await StorageService.instance.read(DATA_KEY);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        resultsNotifier.value =
            decoded.map((e) => CourseHistoryResult.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("AiPersonalizationService: 讀取快取失敗: $e");
    }
  }

  Future<void> _saveToCache() async {
    try {
      String encoded =
          jsonEncode(resultsNotifier.value.map((e) => e.toJson()).toList());
      await StorageService.instance.save(DATA_KEY, encoded);
    } catch (e) {
      debugPrint("AiPersonalizationService: 儲存快取失敗: $e");
    }
  }

  Future<void> fetchCourseHistory() async {
    if (isLoadingNotifier.value) {
      print("DEBUG: AiPersonalizationService: 已經在載入中，忽略此次 fetchCourseHistory()");
      return;
    }
    isLoadingNotifier.value = true;
    statusMessageNotifier.value = "正在載入歷年成績資料...";
    print("DEBUG: AiPersonalizationService: 開始執行 fetchCourseHistory()");

    try {
      print("DEBUG: AiPersonalizationService: 正在嘗試讀取歷年成績快取...");
      String? jsonStr =
          await StorageService.instance.read(HistoricalScoreService.CACHE_KEY);
      print("DEBUG: AiPersonalizationService: 歷年成績快取讀取結果: ${jsonStr != null ? '有快取資料' : '無快取資料'}");
      if (jsonStr == null || jsonStr.isEmpty) {
        print("DEBUG: AiPersonalizationService: 無快取，開始觸發 HistoricalScoreService.instance.fetchAllData()...");
        await HistoricalScoreService.instance.fetchAllData();
        print("DEBUG: AiPersonalizationService: HistoricalScoreService 同步歷年成績已完成，重新讀取快取...");
        jsonStr =
            await StorageService.instance.read(HistoricalScoreService.CACHE_KEY);
        print("DEBUG: AiPersonalizationService: 再次讀取快取結果: ${jsonStr != null ? '有快取資料' : '無快取資料'}");
        if (jsonStr == null || jsonStr.isEmpty) {
          statusMessageNotifier.value = "找不到歷年成績資料，請先同步成績";
          print("DEBUG: AiPersonalizationService: 仍無歷年成績資料，返回中斷");
          return;
        }
      }

      Map<String, dynamic> decoded = jsonDecode(jsonStr);

      List<String> yrsmList = [];
      Map<String, String> yrsmToOriginalKey = {};
      for (var key in decoded.keys) {
        String yrsm = key.replaceAll('-', '');
        yrsmList.add(yrsm);
        yrsmToOriginalKey[yrsm] = key;
      }

      print("DEBUG: AiPersonalizationService: 解析出待查詢學期列表 yrsmList: $yrsmList");
      if (yrsmList.isEmpty) {
        statusMessageNotifier.value = "歷年成績資料為空";
        print("DEBUG: AiPersonalizationService: 待查詢學期列表為空，返回中斷");
        return;
      }

      final credentials = await StorageService.instance.getCredentials();
      String studentId = (credentials['username'] ?? '').trim();
      String password = (credentials['password'] ?? '').trim();
      if (studentId.isEmpty || password.isEmpty) {
        statusMessageNotifier.value = "找不到帳號密碼";
        print("DEBUG: AiPersonalizationService: 找不到帳號密碼，無法登入選課系統，返回中斷");
        return;
      }

      statusMessageNotifier.value = "正在登入...";
      print("DEBUG: AiPersonalizationService: 準備登入選課系統，Stuid: $studentId");
      String? cookie = await _loginViaSSO2(studentId, password);
      if (cookie == null) {
        statusMessageNotifier.value = "登入失敗，請檢查帳號密碼";
        print("DEBUG: AiPersonalizationService: 登入選課系統失敗，返回中斷");
        return;
      }
      print("DEBUG: AiPersonalizationService: 登入選課系統成功，Cookie 取得");

      String userAgent =
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
      String stuact = studentId.substring(0, 1);
      List<CourseHistoryResult> allResults = [];
      int total = yrsmList.length;

      for (int i = 0; i < yrsmList.length; i++) {
        String yrsm = yrsmList[i];
        String originalKey = yrsmToOriginalKey[yrsm] ?? yrsm;
        statusMessageNotifier.value = "正在查詢 $originalKey 選課資料 (${i + 1}/$total)...";
        print("DEBUG: AiPersonalizationService: [${i + 1}/$total] 正在查詢學期 $originalKey ($yrsm) 選課資料...");

        List<CourseSelectionRawData> selectedCourses =
            await _fetchSelectionData(cookie, userAgent, studentId, stuact, yrsm);
        print("DEBUG: AiPersonalizationService: [${i + 1}/$total] 學期 $originalKey 查詢完成，選上課程數: ${selectedCourses.length}");

        var semesterData = decoded[originalKey];
        if (semesterData is Map && semesterData['courses'] is List) {
          List<dynamic> historicalCourses = semesterData['courses'];
          for (var rawData in selectedCourses) {
            for (var courseJson in historicalCourses) {
              if (courseJson is Map && courseJson['id'] == rawData.courseNo) {
                String score = courseJson['score'] ?? '';
                String credits = courseJson['credits'] ?? '';
                allResults.add(CourseHistoryResult(
                  semester: originalKey,
                  department: rawData.dept,
                  courseNo: rawData.courseNo,
                  courseName: courseJson['name'] ?? '',
                  credits: credits,
                  score: score,
                  passed: _isPassed(score),
                ));
                break;
              }
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 150));
      }

      resultsNotifier.value = allResults;
      statusMessageNotifier.value = "同步完成，共 ${allResults.length} 筆課程";
      print("DEBUG: AiPersonalizationService: 同步全部完成，共 ${allResults.length} 筆課程，開始存入快取...");
      await _saveToCache();
      print("DEBUG: AiPersonalizationService: 快取寫入完畢");
    } catch (e) {
      statusMessageNotifier.value = "同步發生異常";
      print("DEBUG: AiPersonalizationService: 同步發生異常: $e");
      debugPrint("AiPersonalizationService Error: $e");
    } finally {
      isLoadingNotifier.value = false;
      print("DEBUG: AiPersonalizationService: 設置 isLoadingNotifier = false");
    }
  }

  Future<String?> _loginViaSSO2(String stuid, String password) async {
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password);
    try {
      print("DEBUG: AiPersonalizationService: [_loginViaSSO2] 正在對 $loginUri 發送 POST 登入請求...");
      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      ).timeout(const Duration(seconds: 10));
      
      print("DEBUG: AiPersonalizationService: [_loginViaSSO2] 回應代碼: ${response.statusCode}");
      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) {
        return rawCookie;
      }
      print("DEBUG: AiPersonalizationService: [_loginViaSSO2] 登入失敗或回應內容包含'不符'");
    } catch (e) {
      print("DEBUG: AiPersonalizationService: [_loginViaSSO2] 拋出異常: $e");
      debugPrint("AiPersonalizationService Login Error: $e");
    }
    return null;
  }

  Future<List<CourseSelectionRawData>> _fetchSelectionData(
    String cookies,
    String userAgent,
    String stuid,
    String stuact,
    String yrsm,
  ) async {
    final uri = Uri.parse("$_baseUrl/menu4/query/stu_slt_data.asp");
    String big5Submit = "%BD%54%A9%77%B0%65%A5%58";
    String body = "stuact=$stuact&YRSM=$yrsm&Stuid=$stuid&B1=$big5Submit";
    try {
      print("DEBUG: AiPersonalizationService: [_fetchSelectionData] 正在向 $uri 查詢 $yrsm 的選課資料...");
      final response = await _client
          .post(uri,
              headers: {
                "Cookie": cookies,
                "User-Agent": userAgent,
                "Content-Type": "application/x-www-form-urlencoded",
                "Referer": "$_baseUrl/menu4/query/stu_slt_up.asp",
              },
              body: body)
          .timeout(const Duration(seconds: 15));
      
      print("DEBUG: AiPersonalizationService: [_fetchSelectionData] $yrsm 回應代碼: ${response.statusCode}");
      if (response.statusCode == 200) {
        String htmlContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (htmlContent.contains("科目名稱")) {
          return _parseSelectionHtml(htmlContent);
        }
      }
    } catch (e) {
      print("DEBUG: AiPersonalizationService: [_fetchSelectionData] $yrsm 拋出異常: $e");
      debugPrint("AiPersonalizationService Fetch $yrsm Error: $e");
    }
    return [];
  }

  List<CourseSelectionRawData> _parseSelectionHtml(String html) {
    final rowRegex = RegExp(r'</tr>', caseSensitive: false);
    List<String> sections = html.split(rowRegex);
    final tdRegex =
        RegExp(r'<td[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true);
    final tagRegex = RegExp(r'<[^>]+>');

    String strip(String s) => s
        .replaceAll(tagRegex, ' ')
        .replaceAll('&nbsp;', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    List<CourseSelectionRawData> results = [];
    for (var section in sections) {
      if (!section.contains(">選上<") || section.contains("選上否")) continue;

      var matches = tdRegex.allMatches(section);
      var cells = matches.map((m) => m.group(1) ?? "").toList();
      if (cells.length < 10) continue;

      String cell0 = strip(cells[0]);
      if (cell0.contains("選上與否")) continue;

      results.add(CourseSelectionRawData(
        dept: strip(cells[1]),
        courseNo: strip(cells[2]),
      ));
    }
    return results;
  }

  bool _isPassed(String score) {
    String s = score.toUpperCase();
    return s.contains('A') || s.contains('B') || s.contains('C') || s.contains('P');
  }
}
