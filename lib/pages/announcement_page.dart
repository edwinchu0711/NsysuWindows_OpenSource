import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/elearn_bulletin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_dropdown.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({Key? key}) : super(key: key);

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  bool _isLoading = true;
  List<ElearnBulletin> _allBulletins = [];
  List<ElearnBulletin> _filteredBulletins = [];
  Set<String> _readBulletinIds = {};

  // --- 篩選與設定變數 ---
  int _pageSize = 30; // 預設 30 筆
  final List<int> _pageSizeOptions = [30, 50, 100];
  
  String? _selectedCourse;
  List<String> _courseOptions = [];

  final Color _themeColor = Colors.redAccent;
  
  ElearnBulletin? _selectedBulletin;

  @override
  void initState() {
    super.initState();
    _loadReadStatus();
    _fetchData();
  }

  Future<void> _loadReadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readBulletinIds = (prefs.getStringList('read_bulletin_ids') ?? []).toSet();
    });
  }

  Future<void> _markAsRead(int id) async {
    String idStr = id.toString();
    if (!_readBulletinIds.contains(idStr)) {
      setState(() => _readBulletinIds.add(idStr));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_bulletin_ids', _readBulletinIds.toList());
    }
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // 根據 _pageSize 決定抓取數量
      var data = await ElearnBulletinService.instance.fetchBulletins(
        forceRefresh: forceRefresh,
        pageSize: _pageSize, 
      );

      // 依照 effectiveTime 排序 (新的在上面)
      data.sort((a, b) => b.effectiveTime.compareTo(a.effectiveTime));

      // 整理出所有課程名稱
      Set<String> courses = {};
      for (var b in data) {
        if (b.courseName.isNotEmpty) courses.add(b.courseName);
      }
      
      if (mounted) {
        setState(() {
          _allBulletins = data;
          _courseOptions = courses.toList()..sort();
          
          // 如果切換筆數後，原本選的課程不在新名單中，重置選擇
          if (_selectedCourse != null && !_courseOptions.contains(_selectedCourse)) {
            _selectedCourse = null;
          }
          
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("載入失敗: $e"), backgroundColor: _themeColor),
        );
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedCourse == null || _selectedCourse == "全部課程") {
        _filteredBulletins = List.from(_allBulletins);
      } else {
        _filteredBulletins = _allBulletins
            .where((b) => b.courseName == _selectedCourse)
            .toList();
      }
      
      // 如果選擇的公告被過濾掉了，就清空
      if (_selectedBulletin != null && !_filteredBulletins.any((b) => b.id == _selectedBulletin!.id)) {
        _selectedBulletin = null;
      }
    });
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Text("網大公告", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh, color: _themeColor),
            onPressed: () => _fetchData(forceRefresh: true),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 900;
    
    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      body: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: isWide ? 0.85 : 1.0,
            child: Column(
              children: [
                _buildHeader(context),
                // --- 頂部設定區 ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
              children: [
                // 左邊：顯示筆數
                Expanded(
                  flex: 2,
                  child: GlassSingleSelectDropdown(
                    label: "顯示筆數",
                    items: _pageSizeOptions.map((e) => e.toString()).toList(),
                    value: _pageSize.toString(),
                    onChanged: _isLoading ? null : (val) {
                      if (val != null) {
                        int newSize = int.parse(val);
                        if (newSize != _pageSize) {
                          setState(() => _pageSize = newSize);
                          _fetchData(forceRefresh: true);
                        }
                      }
                    },
                    displayMap: {
                      for (var opt in _pageSizeOptions) opt.toString(): "$opt 筆"
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: GlassSingleSelectDropdown(
                    label: "課程篩選",
                    items: ["全部課程", ..._courseOptions],
                    value: _selectedCourse ?? "全部課程",
                    onChanged: (val) {
                      setState(() {
                        _selectedCourse = (val == "全部課程") ? null : val;
                        _applyFilter();
                      });
                    },
                  ),
                ),
                
              ],
              
            ),
            
          ),
         

          // --- 列表區 ---
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _themeColor))
                : _filteredBulletins.isEmpty
                    ? const Center(child: Text("沒有公告資料"))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWide = constraints.maxWidth > 800;
                          
                          Widget listWidget = ListView.builder(
                            itemCount: _filteredBulletins.length,
                            padding: const EdgeInsets.all(12),
                            itemBuilder: (context, index) {
                              return _buildBulletinCard(_filteredBulletins[index], isWide);
                            },
                          );

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 4, 
                                  child: listWidget
                                ),
                                const VerticalDivider(width: 1, color: Colors.black12),
                                Expanded(
                                  flex: 6,
                                  child: _selectedBulletin == null
                                      ? Center(
                                          child: Text(
                                            "請從左側選擇公告以檢視詳細內容", 
                                            style: TextStyle(color: colorScheme.subtitleText, fontSize: 16)
                                          )
                                        )
                                      : AnnouncementDetailPage(
                                          key: ValueKey(_selectedBulletin!.id),
                                          bulletin: _selectedBulletin!, 
                                          themeColor: _themeColor,
                                          isEmbedded: true,
                                        ),
                                ),
                              ],
                            );
                          } else {
                            return listWidget;
                          }
                        }
                      ),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletinCard(ElearnBulletin item, bool isWide) {
    final colorScheme = Theme.of(context).colorScheme;
    DateTime showTime = item.effectiveTime;
    String timeStr = DateFormat('yyyy/MM/dd HH:mm').format(showTime);
    bool isUnread = !_readBulletinIds.contains(item.id.toString());
    
    // Select state if it's the currently opened bulletin
    bool isSelected = isWide && _selectedBulletin != null && _selectedBulletin!.id == item.id;
    
    Color accentColor = isSelected ? _themeColor : (isUnread ? Colors.redAccent.shade100 : Colors.transparent);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? _themeColor.withOpacity(0.05) : colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? _themeColor.withOpacity(0.5) : colorScheme.borderColor),
        boxShadow: isSelected ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 4))
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await _markAsRead(item.id);
                if (isWide) {
                  setState(() {
                    _selectedBulletin = item;
                  });
                } else {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnnouncementDetailPage(bulletin: item, themeColor: _themeColor),
                      ),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                       children: [
                          Expanded(
                            child: Text(item.courseName, style: TextStyle(fontSize: 12, color: colorScheme.subtitleText, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(timeStr, style: TextStyle(fontSize: 12, color: colorScheme.subtitleText)),
                       ]
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title, 
                      style: TextStyle(fontSize: 15, fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500, color: colorScheme.primaryText),
                    ),
                    if (item.uploads.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.attach_file, size: 14, color: _themeColor),
                        ],
                      )
                    ]
                  ]
                )
              )
            )
          )
        )
      )
    );
  }
}

// =======================
// 公告詳情頁 (修正超連結點擊)
// =======================
// =======================
// 公告詳情頁 (已修正連結與重複內容問題)
// =======================
class AnnouncementDetailPage extends StatefulWidget {
  final ElearnBulletin bulletin;
  final Color themeColor;
  final bool isEmbedded;

  const AnnouncementDetailPage({
    Key? key,
    required this.bulletin,
    required this.themeColor,
    this.isEmbedded = false,
  }) : super(key: key);

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  bool _downloading = false;

  // 用來記錄已經解析的純文字內容，防止連續換行
  final StringBuffer _parsedTextBuffer = StringBuffer();
  
  // 用來記錄所有出現過的內容指紋 (用來刪除重複)
  final Set<String> _seenContentSignature = {};

  // [新變數] 用來追蹤「上一段內容」是否因為重複而被跳過
  // 如果上一段文字被跳過，緊接著的重複連結也應該被跳過
  bool _isPreviousContentSkipped = false;

  Future<void> _downloadAndOpen(int refId, String fileName) async {
    if (_downloading) return;
    setState(() { _downloading = true; });
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("下載中: $fileName")));
      File file = await ElearnBulletinService.instance.downloadFile(refId, fileName);
      setState(() { _downloading = false; });
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        setState(() { _downloading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("錯誤: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    try {
      urlString = urlString.trim();
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("無法開啟連結: $urlString"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 每次畫面重繪時，重置所有狀態
    _seenContentSignature.clear();
    _parsedTextBuffer.clear();
    _isPreviousContentSkipped = false;

    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            widget.bulletin.title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.primaryText),
          ),
          const SizedBox(height: 10),
          Text(widget.bulletin.courseName,
              style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold)),
          const Divider(height: 30),

          // 內容區
          SelectableText.rich(
            TextSpan(
              style: TextStyle(fontSize: 16, height: 1.6, color: colorScheme.primaryText),
              children: _parseNode(parser.parse(widget.bulletin.contentRaw).body),
            ),
          ),

          if (widget.bulletin.uploads.isNotEmpty) ...[
            const Divider(height: 30),
            Text("附件", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
                        ...widget.bulletin.uploads.map((f) => ListTile(
                  leading: Icon(Icons.file_present, color: colorScheme.subtitleText),
                  title: Text(f.name, style: TextStyle(color: colorScheme.primaryText)),
                  trailing: IconButton(
                    icon: Icon(Icons.download, color: widget.themeColor),
                    onPressed: _downloading ? null : () => _downloadAndOpen(f.referenceId, f.name),
                  ),
                )).toList(),
          ]
        ],
      ),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: colorScheme.cardBackground,
        body: content,
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text("公告詳情", style: TextStyle(color: Colors.white)),
          backgroundColor: widget.themeColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        backgroundColor: colorScheme.cardBackground,
        body: content,
      );
    }
  }

  /// 遞迴解析 Node
  List<InlineSpan> _parseNode(dom.Node? node, {bool insideLink = false}) {
    if (node == null) return [];
    List<InlineSpan> spans = [];

    if (node.nodeType == dom.Node.TEXT_NODE) {
      String text = node.text ?? "";
      text = text.replaceAll('\u00A0', ' '); 
      
      String trimmedText = text.trim();
      if (trimmedText.isEmpty) return [];

      // 產生指紋
      String signature = text.replaceAll(RegExp(r'\s+'), '');

      // [核心修正] 智慧去重判斷
      bool shouldShow = true;

      // 檢查是否重複
      if (_seenContentSignature.contains(signature) && signature.length > 8) {
        // 如果內容重複，我們進一步判斷是否該隱藏
        if (!insideLink) {
          // 如果不是連結，重複的一律隱藏
          shouldShow = false;
        } else {
          // 如果是連結 (insideLink == true)，且內容重複
          // 只有當「上一段內容也被隱藏」時，才隱藏這個連結
          // 這能避免刪掉「標題」後面的那個連結，但會刪掉「重複區塊」裡的連結
          if (_isPreviousContentSkipped) {
            shouldShow = false;
          }
        }
      } else {
        // 內容未重複，記錄下來
        if (signature.length > 8) {
          _seenContentSignature.add(signature);
        }
      }

      if (!shouldShow) {
        // 標記：這段內容被跳過了
        _isPreviousContentSkipped = true;
        return [];
      } else {
        // 標記：這段內容顯示了
        _isPreviousContentSkipped = false;
        
        spans.add(TextSpan(text: text));
        _parsedTextBuffer.write(text);
      }

    } else if (node.nodeType == dom.Node.ELEMENT_NODE) {
      dom.Element element = node as dom.Element;
      
      // 過濾垃圾標籤
      if (['style', 'script', 'head', 'meta', 'link', 'title', 'xml', 'iframe'].contains(element.localName)) {
        return [];
      }
      String style = element.attributes['style']?.toLowerCase() ?? "";
      if (style.contains('display: none') || style.contains('visibility: hidden')) {
        return [];
      }

      bool isBold = (element.localName == 'b' || element.localName == 'strong' || style.contains("font-weight: 700"));
      bool isLinkElement = (element.localName == 'a');

      List<InlineSpan> childrenSpans = [];
      for (var child in element.nodes) {
        childrenSpans.addAll(_parseNode(child, insideLink: insideLink || isLinkElement));
      }

      // 處理換行
      if (element.localName == 'br') {
        if (!_parsedTextBuffer.toString().endsWith("\n")) {
           spans.add(const TextSpan(text: "\n"));
           _parsedTextBuffer.write("\n");
        }
      } 
      // 處理連結
      else if (isLinkElement) {
        String? href = element.attributes['href'];
        if (href != null && href.startsWith('/')) {
          href = "https://elearn.nsysu.edu.tw$href";
        }
        
        final recognizer = TapGestureRecognizer()
          ..onTap = () { if (href != null) _launchURL(href); };

        // 如果 childrenSpans 是空的 (代表裡面的文字被去重過濾掉了)，這個連結也會自然消失
        // 這正是我們想要的效果
        if (childrenSpans.isNotEmpty || (href != null && childrenSpans.isEmpty)) {
           // 只有當連結內有文字，或者我們想顯示裸連結時才加入
           // 但根據上面的邏輯，如果文字被過濾，childrenSpans 會是空的
           // 為了保險，如果 childrenSpans 有東西才顯示 span
           if (childrenSpans.isNotEmpty) {
             spans.add(TextSpan(
               style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
               children: childrenSpans,
               recognizer: recognizer,
             ));
           } else if (href != null && !_isPreviousContentSkipped) {
             // 只有當「不是因為重複而被過濾」的情況下，才補上 href 本身當作文字
             // (這處理 <a href="..."></a> 這種空標籤的情況)
              spans.add(TextSpan(
               text: href,
               style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
               recognizer: recognizer,
             ));
           }
        }
      } 
      else {
        spans.add(TextSpan(
          style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          children: childrenSpans
        ));

        if (['div', 'p', 'li', 'ul', 'h1', 'h2', 'h3', 'tr'].contains(element.localName)) {
           if (!_parsedTextBuffer.toString().endsWith("\n") && _parsedTextBuffer.isNotEmpty) {
             spans.add(const TextSpan(text: "\n"));
             _parsedTextBuffer.write("\n");
           }
        }
      }
    }
    return spans;
  }
}
extension on dom.Element {
  List<String> get styles => attributes['style']?.split(';') ?? [];
}



