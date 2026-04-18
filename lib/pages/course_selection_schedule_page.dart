// 檔案名稱：course_selection_schedule_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/utils.dart'; // 請確認路徑
import 'course_selection/course_selection_page.dart';
import 'course_exception/course_exception_handling_page.dart'; // 引入異常處理頁面
import '../services/storage_service.dart';
import '../../services/course_query_service.dart'; // 請確認路徑是否正確
import '../theme/app_theme.dart';

bool test = false;

enum SelectionState {
  open, // 正常開放選課
  closed, // 選課系統關閉 (唯讀模式)
  needConfirmation, // 需要確認 (例如：必修確認階段)
  error, // 發生錯誤
}

class CourseSelectionSchedulePage extends StatefulWidget {
  const CourseSelectionSchedulePage({Key? key}) : super(key: key);

  @override
  State<CourseSelectionSchedulePage> createState() =>
      _CourseSelectionSchedulePageState();
}

class _CourseSelectionSchedulePageState
    extends State<CourseSelectionSchedulePage> {
  // --- 原有的時程表資料變數 ---
  bool _isLoading = true;
  String _dataUpdateTime = "";
  List<MapEntry<String, dynamic>> _mainList = [];
  List<MapEntry<String, dynamic>> _bottomList = [];
  List<String> _activeItemKeys = [];

  final Set<String> _bottomItems = {'必修課程確認', '系所輔導學生選課', '超修學分申請'};

  // --- 【新增】系統即時狀態檢查變數 ---
  bool _isCheckingSystem = true; // 是否正在連線檢查
  bool _isSystemOpen = false; // 系統是否實際開放
  String _systemStatusMessage = "檢查系統狀態中...";

  // --- 連線設定 ---
  final http.Client _client = http.Client();
  final String _baseUrl = "https://selcrs.nsysu.edu.tw"; // 學校系統基底網址

  @override
  void initState() {
    super.initState();
    // 1. 載入 JSON 時程表 (顯示列表用)
    _checkAndLoadData();
    // 2. 直接連線學校檢查狀態 (顯示按鈕用)
    _checkRealTimeSystemStatus();
  }

  @override
  void dispose() {
    _client.close(); // 關閉連線
    super.dispose();
  }

  DateTime? _getConfirmationEndTime() {
    // 合併搜尋 mainList 和 bottomList
    final allItems = [..._mainList, ..._bottomList];

    // 尋找 Key 包含 "選課確認" 的項目 (ex: "選課確認", "必修課程確認" 等)
    // 根據你的需求，如果 JSON Key 明確叫做 "選課確認"，可以精確比對
    // 這裡使用模糊比對 "確認" 且包含 "選課" 或 "課程" 來涵蓋 "必修課程確認"
    try {
      final entry = allItems.firstWhere(
        (e) =>
            e.key.contains("選課確認") ||
            (e.key.contains("課程") && e.key.contains("確認")),
        orElse: () => const MapEntry("", {}),
      );

      if (entry.key.isEmpty) return null; // 找不到

      final content = entry.value as Map<String, dynamic>;
      final String endTimeStr = content['結束時間'] ?? "";

      return _parseTwDate(endTimeStr);
    } catch (e) {
      return null;
    }
  }

  // ==========================================================
  // 【核心修改】實作你要求的伺服器檢查邏輯
  // ==========================================================
  Future<void> _checkRealTimeSystemStatus() async {
    if (!mounted) return;

    // 初始化狀態
    setState(() {
      _isCheckingSystem = true;
      _systemStatusMessage = "正在連線學校系統確認...";
      _isSystemOpen = false;
    });

    print("🔍 [偵錯] 開始執行 _checkRealTimeSystemStatus...");

    try {
      final credentials = await StorageService.instance.getCredentials();
      String studentId = (credentials['username'] ?? "").trim();
      String password = (credentials['password'] ?? "").trim();

      // 如果沒有帳密，就不檢查了，直接視為未開放
      if (studentId.isEmpty || password.isEmpty) {
        throw "未登入 (請先至設定頁面設定帳號)";
      }

      // 1. 登入 (呼叫 SSO 登入邏輯)
      print("🔍 [偵錯] 正在登入...");
      // 【注意】請確保 _loginViaSSO2 函式存在於此檔案或已正確 Import
      String? cookie = await _loginViaSSO2(studentId, password);

      if (cookie == null) {
        throw "SSO 登入失敗 (Cookie 為空)";
      }
      print("✅ [偵錯] 登入成功，Cookie 取得");

      // 2. Request main_frame.asp 取得參數
      final mainFrameUrl = Uri.parse("$_baseUrl/menu4/main_frame.asp");
      print("🔍 [偵錯] 請求 MainFrame: $mainFrameUrl");

      final mainFrameResponse = await _client.get(
        mainFrameUrl,
        headers: {
          "Cookie": cookie,
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      );
      String mainFrameBody = utf8.decode(
        mainFrameResponse.bodyBytes,
        allowMalformed: true,
      );

      // 解析 frame src 中的參數 (Studfun.asp?DEG_COD=B&...)
      RegExp paramRegex = RegExp(
        r'src="Studfun\.asp\?([^"]+)"',
        caseSensitive: false,
      );
      Match? paramMatch = paramRegex.firstMatch(mainFrameBody);

      String studFunParams = "";
      if (paramMatch != null) {
        studFunParams = paramMatch.group(1) ?? "";
        print("✅ [偵錯] 成功抓取參數串: $studFunParams");
      } else {
        print("⚠️ [偵錯] 在 main_frame 無法抓取參數");
      }

      // 3. Request Studfun.asp (帶參數)
      String studFunUrlString = "$_baseUrl/menu4/Studfun.asp";
      if (studFunParams.isNotEmpty) {
        studFunUrlString += "?$studFunParams";
      }

      final studFunUrl = Uri.parse(studFunUrlString);
      print("🔍 [偵錯] 請求選單頁面: $studFunUrl");

      final response = await _client.get(
        studFunUrl,
        headers: {
          "Cookie": cookie,
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      );
      String body = utf8.decode(response.bodyBytes, allowMalformed: true);

      // 4. 尋找第一個 <a> 連結
      RegExp hrefReg = RegExp(r'<a\s+href="([^"]+)"', caseSensitive: false);
      Match? match = hrefReg.firstMatch(body);

      if (match == null) {
        // 如果找不到連結，可能是連線逾時或結構改變
        print("❌ [偵錯] 找不到選課入口連結");
        throw "無法讀取選課選單 (無連結)";
      }

      String firstLink = match.group(1) ?? "";
      print("🔗 [偵錯] 抓到的第一個連結為: [$firstLink]");

      // 5. 判斷選課是否開放
      // 如果連結包含 query/result.asp，代表是「查詢系統」(未開放)
      // 如果連結包含 select_bar.asp 或其他，代表是「選課系統」(開放中)
      bool isOpen = !firstLink.contains("query/result.asp") || test;

      if (mounted) {
        setState(() {
          _isSystemOpen = isOpen;
          _systemStatusMessage = isOpen ? "選課系統開放中" : "目前非選課時段";
          _isCheckingSystem = false;
        });
      }
    } catch (e) {
      print("❌ [偵錯] 檢查流程發生錯誤: $e");
      if (mounted) {
        setState(() {
          _isSystemOpen = false;
          // 錯誤訊息處理，把 Exception: 字樣拿掉比較好看
          String errorMsg = e.toString().replaceAll("Exception:", "").trim();
          // 如果是未登入，顯示比較友善的訊息
          if (errorMsg.contains("未登入")) {
            _systemStatusMessage = "未登入帳號";
          } else {
            _systemStatusMessage = "無法確認狀態 ($errorMsg)";
          }
          _isCheckingSystem = false;
        });
      }
    }
  }

  // --- 檢查快取與載入 (保持原樣) ---
  Future<void> _checkAndLoadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    try {
      if (!forceRefresh) {
        final String? cachedJson = prefs.getString('course_schedule_cache');
        final int? lastFetchMillis = prefs.getInt('course_schedule_last_fetch');

        if (cachedJson != null && lastFetchMillis != null) {
          final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(
            lastFetchMillis,
          );
          final Duration diff = DateTime.now().difference(lastFetchTime);

          if (diff.inDays < 1) {
            final decoded = jsonDecode(cachedJson);
            if (decoded is Map) {
              _processData(Map<String, dynamic>.from(decoded));
            }
            return;
          }
        }
      }

      // await _fetchFromGithub(prefs);
      final fetchedData = await fetchScheduleFromNsysu();

      // 將爬取到的新資料存入本機一般快取 (依用戶要求選課紀錄不加密)
      await prefs.setString('course_schedule_cache', jsonEncode(fetchedData));
      await prefs.setInt(
        'course_schedule_last_fetch',
        DateTime.now().millisecondsSinceEpoch,
      );

      // 呼叫資料處理，更新畫面
      _processData(fetchedData);
    } catch (e) {
      print("載入錯誤: $e");
      if (mounted) {
        final String? cachedJson = prefs.getString('course_schedule_cache');
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson);
          _processData(Map<String, dynamic>.from(decoded));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("網路更新失敗，顯示舊資料: $e"),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("載入失敗: $e"), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- 解析台灣格式日期字串 (保持原樣) ---
  DateTime? _parseTwDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final RegExp regex = RegExp(
        r'(?:(\d+)年)?\s*(\d+)\s*/\s*(\d+)(?:.*?)\s+(\d+):(\d+)',
      );

      final match = regex.firstMatch(dateStr);
      if (match != null) {
        int year;
        if (match.group(1) != null) {
          int rocYear = int.parse(match.group(1)!);
          year = rocYear + 1911;
        } else {
          year = DateTime.now().year;
        }

        int month = int.parse(match.group(2)!);
        int day = int.parse(match.group(3)!);
        int hour = int.parse(match.group(4)!);
        int minute = int.parse(match.group(5)!);

        return DateTime(year, month, day, hour, minute);
      }
    } catch (e) {
      print("日期解析失敗: $dateStr, error: $e");
    }
    return null;
  }

  // --- 資料處理核心邏輯 (保持原樣，僅移除 isSelectionPeriod 的判斷) ---
  void _processData(Map<String, dynamic> fullData) {
    if (!mounted) return;

    final Map<String, dynamic> rawData = fullData['data'] != null
        ? Map<String, dynamic>.from(fullData['data'])
        : {};
    final Map<String, dynamic> metadata = fullData['metadata'] != null
        ? Map<String, dynamic>.from(fullData['metadata'])
        : {};

    String timeStr = "未知";
    dynamic updateTime = metadata['update_time'];
    if (updateTime != null) {
      try {
        DateTime dt = DateTime.parse(updateTime.toString());
        timeStr = DateFormat('yyyy/MM/dd HH:mm').format(dt);
      } catch (e) {
        /* ignore */
      }
    } else {
      timeStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
    }

    List<MapEntry<String, dynamic>> main = [];
    List<MapEntry<String, dynamic>> bottom = [];

    rawData.forEach((key, value) {
      if (key == '更新時間') return;
      if (_bottomItems.contains(key)) {
        bottom.add(MapEntry(key, value));
      } else {
        main.add(MapEntry(key, value));
      }
    });

    MapEntry<String, dynamic>? dropEntry;
    List<MapEntry<String, dynamic>> sortedMain = [];

    for (var entry in main) {
      if (entry.key == '棄選時間') {
        dropEntry = entry;
      } else {
        sortedMain.add(entry);
      }
    }

    sortedMain.sort((a, b) => a.key.compareTo(b.key));

    if (dropEntry != null) {
      sortedMain.add(dropEntry);
    }

    main = sortedMain;
    bottom.sort((a, b) => a.key.compareTo(b.key));

    List<String> activeKeys = []; // ← 改這裡
    DateTime now = DateTime.now();

    for (int i = 0; i < main.length; i++) {
      final entry = main[i];
      final content = entry.value as Map<String, dynamic>;

      DateTime? start = _parseTwDate(content['開始時間']);
      DateTime? end = _parseTwDate(content['結束時間']);

      if (start == null) continue;

      bool isActive = false;

      if (end != null) {
        if (now.isAfter(start) && now.isBefore(end)) {
          isActive = true;
        }
      } else {
        DateTime? nextStart;
        if (i + 1 < main.length) {
          nextStart = _parseTwDate((main[i + 1].value as Map)['開始時間']);
        }

        if (nextStart != null) {
          if (now.isAfter(start) && now.isBefore(nextStart)) {
            isActive = true;
          }
        } else {
          if (now.isAfter(start)) {
            isActive = true;
          }
        }
      }

      if (isActive) {
        activeKeys.add(entry.key); // ← 改這裡
      }
    }

    setState(() {
      _dataUpdateTime = timeStr;
      _mainList = main;
      _bottomList = bottom;
      _activeItemKeys = activeKeys; // ← 改這裡
      _isLoading = false;
    });
  }

  String _removeYear(String text) {
    if (text.isEmpty) return "";
    return text.replaceAll(RegExp(r'\d+年'), '').trim();
  }

  // 跳轉函式
  void _navigateToCourseSelection({bool enableQuery = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseSelectionPage(enableQuery: enableQuery),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchScheduleFromNsysu() async {
    try {
      final url = Uri.parse('https://selcrs.nsysu.edu.tw/');
      final response = await http.get(url);

      final String htmlContent = response.body;

      final RegExp regExp = RegExp(
        r'<tr><td><div[^>]*>(.*?)<\/div><\/td><td><div[^>]*>：(.*?)<\/div><\/td><\/tr>',
      );

      final matches = regExp.allMatches(htmlContent);

      Map<String, dynamic> dataMap = {};

      for (var match in matches) {
        final title = match.group(1)?.trim() ?? '';
        final timeStr = match.group(2)?.replaceAll('&nbsp;', ' ').trim() ?? '';

        String startTimeStr = "";
        String endTimeStr = "";

        if (timeStr.contains('~')) {
          final timeParts = timeStr.split('~');
          startTimeStr = _formatNsysuTimeToOldStyle(timeParts[0].trim());
          endTimeStr = _formatNsysuTimeToOldStyle(timeParts[1].trim());
        } else {
          startTimeStr = _formatNsysuTimeToOldStyle(timeStr.trim());
        }

        // 轉換為 _processData 預期的格式
        dataMap[title] = {'開始時間': startTimeStr, '結束時間': endTimeStr};
      }

      if (dataMap.isEmpty) {
        throw Exception("正則表達式沒有抓到任何資料，請檢查網頁結構是否改變");
      }

      // 回傳符合 _processData 解析邏輯的 Map
      return {
        'data': dataMap,
        'metadata': {'update_time': DateTime.now().toIso8601String()},
      };
    } catch (e) {
      print("爬取選課時間失敗: $e");
      throw Exception("爬取選課時間失敗: $e");
    }
  }

  /// 將學校的「115.01.30(09:00)」轉成舊 JSON 格式「115年 01/30 09:00」
  /// 以相容原有的 _parseTwDate 與 _removeYear 邏輯
  String _formatNsysuTimeToOldStyle(String rawTime) {
    final regex = RegExp(r'(\d+)\.(\d+)\.(\d+)\((\d+):(\d+)\)');
    final match = regex.firstMatch(rawTime);

    if (match != null) {
      return "${match.group(1)}年 ${match.group(2)}/${match.group(3)} ${match.group(4)}:${match.group(5)}";
    }
    return rawTime;
  }

  /// 輔助函式：將「115.01.30(09:00)」格式轉為 DateTime

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semStr = CourseQueryService.instance.currentSemester;
    String semDisplay = "";
    if (semStr.length == 4) {
      final syear = semStr.substring(0, 3); // 前三碼 (114)
      final sem = semStr.substring(3, 4); // 最後一碼 (2)
      semDisplay = "$syear-$sem";
    }

    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: isWide ? 0.85 : 1.0,
            child: Column(
              children: [
                _buildDesktopHeader(semDisplay),
                if (_isLoading)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            "載入資料中...",
                            style: TextStyle(color: colorScheme.subtitleText),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              bool isWideLayout =
                                  isWide && constraints.maxWidth > 800;

                              if (isWideLayout) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: ListView(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        children: _mainList
                                            .map(
                                              (entry) => _buildCleanRow(entry),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                    VerticalDivider(
                                      width: 1,
                                      color: colorScheme.borderColor,
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight: constraints.maxHeight,
                                            ),
                                            child: Center(
                                              child: SingleChildScrollView(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 16,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "功能選項",
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colorScheme
                                                            .primaryText,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    _buildActiveStatusRow(
                                                      isWide: true,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return ListView(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  children: [
                                    _buildActiveStatusRow(isWide: false),
                                    ..._mainList.map(
                                      (entry) => _buildCleanRow(entry),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          color: Colors.transparent,
                          child: Text(
                            "資料更新時間：$_dataUpdateTime",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.subtitleText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(String semDisplay) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: Colors.transparent, // 改為透明，由 Scaffold 背景決定
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 20,
              top: 5,
              bottom: 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "返回主選單",
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$semDisplay 選課時程",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                  ],
                ),
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : InkWell(
                        onTap: () {
                          _checkAndLoadData(forceRefresh: true);
                          _checkRealTimeSystemStatus();
                        },
                        mouseCursor: _isLoading
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryCardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorScheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: colorScheme.accentBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "重新整理",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.accentBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildActiveStatusRow({bool isWide = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    // 1. 基礎狀態判斷 (藍/橘/灰)
    Color? primaryBgColor;
    Color primaryTextColor = colorScheme.bodyText;
    bool showOpenButton = false;
    bool showStatusButton = false;

    if (_isCheckingSystem) {
      primaryBgColor = colorScheme.secondaryCardBackground;
      primaryTextColor = colorScheme.bodyText;
    }
    if (_isSystemOpen) {
      primaryBgColor = colorScheme.isDark
          ? Colors.blue.withOpacity(0.15)
          : Colors.blue[50];
      primaryTextColor = colorScheme.isDark
          ? Colors.blue[200]!
          : Colors.blue[800]!;
      showOpenButton = true;
    } else {
      DateTime? confirmEndTime = _getConfirmationEndTime();
      DateTime now = DateTime.now();
      if (confirmEndTime != null && now.isBefore(confirmEndTime) || test) {
        primaryBgColor = colorScheme.warningContainer;
        primaryTextColor = Colors.orange[800]!;
        if (colorScheme.isDark) primaryTextColor = Colors.orange[200]!;
        _systemStatusMessage = "目前非選課時段";
        showStatusButton = true;
      } else {
        primaryBgColor = Colors.transparent;
        primaryTextColor = colorScheme.subtitleText;
      }
    }

    // 2. 異常處理狀態判斷 (綠/灰)
    bool isExceptionActive =
        _activeItemKeys.any((key) => key.contains('異常')) || test;

    return Padding(
      padding: isWide
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 第一部分：系統狀態卡片 (藍/橘/灰) ---
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 16.0,
            ),
            decoration: BoxDecoration(
              color: primaryBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_isCheckingSystem)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _systemStatusMessage,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    if (!_isCheckingSystem)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: _buildActionButton(
                          isWide ? "前往選課系統" : "前往選課",
                          Icons.login_rounded,
                          Colors.blue,
                          () => _navigateToCourseSelection(enableQuery: true),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // --- 第二部分：異常處理卡片 (綠/灰) ---
          const SizedBox(height: 16), // 兩個卡片間的間距
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 16.0,
            ),
            decoration: BoxDecoration(
              // 如果是進行中就給綠色背景，否則給淡淡的灰色背景
              color: isExceptionActive
                  ? colorScheme.successContainer
                  : colorScheme.secondaryCardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isExceptionActive ? "目前為異常處理階段" : "非異常處理時段",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isExceptionActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isExceptionActive
                              ? (colorScheme.isDark
                                    ? Colors.green[200]
                                    : Colors.green[800])
                              : colorScheme.subtitleText,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: _buildActionButton(
                        "前往異常處理",
                        Icons.build_circle_outlined,
                        isExceptionActive ? Colors.green : Colors.grey,
                        () {
                          if (isExceptionActive) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CourseExceptionHandlingPage(),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 統一的按鈕小工具
  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  Widget _buildCleanRow(
    MapEntry<String, dynamic> entry, {
    bool forceInactive = false,
  }) {
    final String title = entry.key;
    final Map<String, dynamic> content = entry.value is Map
        ? Map<String, dynamic>.from(entry.value)
        : {};

    String rawStart = content['開始時間'] ?? "";
    String rawEnd = content['結束時間'] ?? "";

    String start = _removeYear(rawStart);
    String end = _removeYear(rawEnd);

    bool hasEnd = end.trim().isNotEmpty;

    bool isActive = _activeItemKeys.contains(entry.key); // ← 只改這行

    final curColorScheme = Theme.of(context).colorScheme;
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: curColorScheme.borderColor),
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHovered
                      ? Colors.blue.withOpacity(0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.15),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isActive
                            ? curColorScheme.accentBlue
                            : curColorScheme.primaryText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTimeText(start, isActive),
                        if (hasEnd) ...[
                          const SizedBox(height: 6),
                          _buildTimeText("~ $end", isActive),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeText(String text, bool isActive) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 15,
        color: isActive ? colorScheme.accentBlue : colorScheme.subtitleText,
        fontWeight: FontWeight.w500,
        height: 1.1,
      ),
    );
  }

  // =============================================================
  // ⚠️【請注意】這裡必須填入你原本專案中的 SSO 登入邏輯
  // =============================================================
  Future<String?> _loginViaSSO2(String stuid, String password) async {
    final loginUri = Uri.parse("$_baseUrl/menu4/Studcheck_sso2.asp");
    String encryptedPass = Utils.base64md5(password);
    try {
      final response = await _client.post(
        loginUri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: {"stuid": stuid.toUpperCase(), "SPassword": encryptedPass},
      );
      String? rawCookie = response.headers['set-cookie'];
      if (rawCookie != null && !response.body.contains("不符")) return rawCookie;
    } catch (e) {
      print("❌ [偵錯] Login Error: $e");
    }
    return null;
  }
}
