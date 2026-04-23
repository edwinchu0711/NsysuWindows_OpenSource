import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'assignment_submission_page.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../services/exam_task/elearn_task_HW_service.dart';
import '../../theme/app_theme.dart';

// --- Helper Functions ---
Widget _buildInfoRow(BuildContext context, String label, String value) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.subtitleText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: colorScheme.primaryText, height: 1.3),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionTitle(BuildContext context, String title) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.accentBlue,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 40,
          height: 3,
          color: colorScheme.accentBlue.withOpacity(0.3),
        ),
      ],
    ),
  );
}

String _fmtDate(String? iso) {
  if (iso == null) return "-";
  try {
    return DateFormat('yyyy.MM.dd HH:mm').format(DateTime.parse(iso).toLocal());
  } catch (e) {
    return iso;
  }
}

Widget _cleanHtml(BuildContext context, String htmlString) {
  final colorScheme = Theme.of(context).colorScheme;
  var document = html_parser.parse(htmlString);
  List<InlineSpan> spans = [];

  void _parseNode(dom.Node node) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      if (node.text!.trim().isNotEmpty) {
        spans.add(TextSpan(text: node.text));
      }
    } else if (node.nodeType == dom.Node.ELEMENT_NODE) {
      dom.Element element = node as dom.Element;
      if (['p', 'br', 'div'].contains(element.localName)) {
        if (spans.isNotEmpty &&
            spans.last is TextSpan &&
            (spans.last as TextSpan).text != '\n') {
          spans.add(const TextSpan(text: "\n"));
        }
      }
      for (var child in element.nodes) {
        if (['b', 'strong'].contains(element.localName)) {
          if (child.nodeType == dom.Node.TEXT_NODE) {
            spans.add(
              TextSpan(
                text: child.text,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          } else {
            _parseNode(child);
          }
        } else {
          _parseNode(child);
        }
      }
      if (['p', 'div'].contains(element.localName)) {
        spans.add(const TextSpan(text: "\n"));
      }
    }
  }

  _parseNode(document.body!);
  return RichText(
    text: TextSpan(
      style: TextStyle(
        color: colorScheme.primaryText,
        fontSize: 15,
        height: 1.5,
      ),
      children: spans,
    ),
  );
}

// =======================
// 1. 測驗詳情頁
// =======================
class ExamDetailPage extends StatefulWidget {
  final int examId;
  final String title;
  final bool isIgnored;
  final bool isSubmitted; // 新增：是否已完成
  final bool isEmbedded;
  final VoidCallback? onStateChanged;

  const ExamDetailPage({
    Key? key,
    required this.examId,
    required this.title,
    this.isIgnored = false,
    required this.isSubmitted,
    this.isEmbedded = false,
    this.onStateChanged,
  }) : super(key: key);

  @override
  State<ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<ExamDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String _error = "";
  late bool _currentIgnored;

  @override
  void initState() {
    super.initState();
    _currentIgnored = widget.isIgnored;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ElearnService.instance.fetchExamDetails(widget.examId);
      if (mounted)
        setState(() {
          _data = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _toggleIgnore() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_currentIgnored ? "取消忽略" : "忽略此活動"),
        content: Text(
          _currentIgnored
              ? "確定要取消忽略狀態嗎？"
              : "該功能是提供可能團體作業只需要一個人繳交，或只是不想做。\n\n確定要將此活動設為「忽略」嗎？",
        ),
        actions: [
          TextButton(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("確定"),
            onPressed: () async {
              Navigator.pop(ctx);
              await ElearnService.instance.toggleIgnoreTask(
                widget.examId,
                !_currentIgnored,
              );
              setState(() => _currentIgnored = !_currentIgnored);
              if (widget.onStateChanged != null) {
                widget.onStateChanged!();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error.isNotEmpty
        ? Center(
            child: Text(
              _error,
              style: TextStyle(color: colorScheme.primaryText),
            ),
          )
        : _buildContent();

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: colorScheme.cardBackground,
        body: content,
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _currentIgnored != widget.isIgnored);
        return false;
      },
      child: Scaffold(
        backgroundColor: colorScheme.pageBackground,
        appBar: AppBar(
          title: const Text("測驗詳情"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            if (!widget.isSubmitted)
              IconButton(
                icon: Icon(
                  _currentIgnored ? Icons.visibility : Icons.visibility_off,
                ),
                tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                onPressed: _toggleIgnore,
              ),
          ],
        ),
        body: content,
      ),
    );
  }

  Widget _buildContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final info = _data!['info'];
    final subs = _data!['submissions']['submissions'] as List;
    final endTime = DateTime.parse(info['end_time']);
    final isClosed = DateTime.now().isAfter(endTime);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentIgnored)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              color: colorScheme.accentBlue.withOpacity(0.1),
              child: Text(
                "此活動已被標記為忽略",
                style: TextStyle(
                  color: colorScheme.accentBlue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
              ),
              if (widget.isEmbedded && !widget.isSubmitted)
                IconButton(
                  icon: Icon(
                    _currentIgnored ? Icons.visibility : Icons.visibility_off,
                    color: colorScheme.subtitleText,
                  ),
                  tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                  onPressed: _toggleIgnore,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isClosed
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: isClosed ? Colors.red : Colors.green),
            ),
            child: Text(
              isClosed ? "測驗已截止" : "測驗進行中",
              style: TextStyle(
                color: isClosed ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          _buildSectionTitle(context, "基本資訊"),
          Card(
            elevation: 0,
            color: colorScheme.secondaryCardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: colorScheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    "活動時間",
                    "${_fmtDate(info['start_time'])} - ${_fmtDate(info['end_time'])}",
                  ),
                  _buildInfoRow(
                    context,
                    "公布成績",
                    _fmtDate(info['announce_score_time']),
                  ),
                  _buildInfoRow(
                    context,
                    "公布答案",
                    _fmtDate(info['announce_answer_time']),
                  ),
                  _buildInfoRow(
                    context,
                    "成績比率",
                    "${info['score_percentage']}%",
                  ),
                  _buildInfoRow(context, "次數上限", "${info['submit_times']}"),
                  _buildInfoRow(
                    context,
                    "測驗形式",
                    info['type'] == 'exam' ? '個人測驗' : '團體測驗',
                  ),
                  _buildInfoRow(
                    context,
                    "計分規則",
                    info['score_rule'] == 'highest' ? '最高得分' : '平均得分',
                  ),
                  _buildInfoRow(context, "完成指標", info['completion_criterion']),
                ],
              ),
            ),
          ),

          _buildSectionTitle(context, "繳交紀錄"),
          Card(
            elevation: 2,
            color: colorScheme.cardBackground,
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: colorScheme.borderColor,
                textTheme: Theme.of(context).textTheme.copyWith(
                  bodyMedium: TextStyle(color: colorScheme.primaryText),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    colorScheme.secondaryCardBackground,
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        '最後交卷時間',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primaryText,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '成績',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primaryText,
                        ),
                      ),
                    ),
                  ],
                  rows: subs.map<DataRow>((s) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _fmtDate(s['submitted_at']),
                            style: TextStyle(color: colorScheme.primaryText),
                          ),
                        ),
                        DataCell(
                          Text(
                            s['score'] != null
                                ? s['score'].toString().replaceAll(
                                    RegExp(r'\.0$'),
                                    '',
                                  )
                                : "-",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.accentBlue,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// 2. 作業詳情頁
// =======================
class HomeworkDetailPage extends StatefulWidget {
  final int homeworkId;
  final String title;
  final bool isIgnored;
  final bool isSubmitted; // 新增
  final bool isEmbedded;
  final VoidCallback? onStateChanged;

  const HomeworkDetailPage({
    Key? key,
    required this.homeworkId,
    required this.title,
    this.isIgnored = false,
    required this.isSubmitted,
    this.isEmbedded = false,
    this.onStateChanged,
  }) : super(key: key);

  @override
  State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();
}

class _HomeworkDetailPageState extends State<HomeworkDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String _error = "";
  bool _downloading = false;
  late bool _currentIgnored;

  @override
  void initState() {
    super.initState();
    _currentIgnored = widget.isIgnored;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ElearnService.instance.fetchHomeworkDetails(
        widget.homeworkId,
      );
      if (mounted)
        setState(() {
          _data = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _toggleIgnore() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_currentIgnored ? "取消忽略" : "忽略此活動"),
        content: Text(_currentIgnored ? "確定要取消忽略狀態嗎？" : "確定要將此活動設為「忽略」嗎？"),
        actions: [
          TextButton(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("確定"),
            onPressed: () async {
              Navigator.pop(ctx);
              await ElearnService.instance.toggleIgnoreTask(
                widget.homeworkId,
                !_currentIgnored,
              );
              setState(() => _currentIgnored = !_currentIgnored);
              if (widget.onStateChanged != null) {
                widget.onStateChanged!();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpen(int refId, String fileName) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("正在下載 $fileName ...")));
      File file = await ElearnService.instance.downloadFile(refId, fileName);
      setState(() {
        _downloading = false;
      });
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception("無法開啟檔案: ${result.message}");
      }
    } catch (e) {
      setState(() {
        _downloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("錯誤: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error.isNotEmpty
        ? Center(
            child: Text(
              _error,
              style: TextStyle(color: colorScheme.primaryText),
            ),
          )
        : _buildContent();

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: colorScheme.cardBackground,
        body: content,
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _currentIgnored != widget.isIgnored);
        return false;
      },
      child: Scaffold(
        backgroundColor: colorScheme.pageBackground,
        appBar: AppBar(
          title: const Text("作業詳情"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            /*
            if (_data != null &&
                (_data!['is_in_progress'] == true ||
                    _data!['is_in_progress'] == 1 ||
                    _data!['is_in_progress'] == "true"))
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 10, bottom: 10),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignmentSubmissionPage(
                          homeworkId: widget.homeworkId,
                          courseName: _data!['course_name'] ?? "",
                          title: widget.title,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "繳交作業",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            */
            if (!widget.isSubmitted)
              IconButton(
                icon: Icon(
                  _currentIgnored ? Icons.visibility : Icons.visibility_off,
                ),
                tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                onPressed: _toggleIgnore,
              ),
          ],
        ),
        body: content,
      ),
    );
  }

  Widget _buildContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final d = _data!['data'];
    final info = _data!;

    final startTime = info['start_time'];
    final endTime = info['end_time'];
    final desc = d['description'] ?? "";
    final uploads = info['uploads'] as List;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentIgnored)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              color: colorScheme.accentBlue.withOpacity(0.1),
              child: Text(
                "此活動已被標記為忽略",
                style: TextStyle(
                  color: colorScheme.accentBlue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
              ),
              if (widget.isEmbedded && !widget.isSubmitted)
                IconButton(
                  icon: Icon(
                    _currentIgnored ? Icons.visibility : Icons.visibility_off,
                    color: colorScheme.subtitleText,
                  ),
                  tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                  onPressed: _toggleIgnore,
                ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionTitle(context, "基本資訊"),
          Card(
            elevation: 0,
            color: colorScheme.secondaryCardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: colorScheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    "活動時間",
                    "${_fmtDate(startTime)} - ${_fmtDate(endTime)}",
                  ),
                  _buildInfoRow(
                    context,
                    "公布成績",
                    d['announce_score_type'] == 2 ? "馬上公布" : "依設定",
                  ),
                  _buildInfoRow(context, "成績比率", "${d['score_percentage']}%"),
                  _buildInfoRow(
                    context,
                    "作業形式",
                    d['homework_type'] == 'file_upload' ? '個人作業(上傳)' : '一般作業',
                  ),
                  _buildInfoRow(
                    context,
                    "計分規則",
                    d['score_rule'] == 'highest' ? '最高得分' : '平均得分',
                  ),
                  _buildInfoRow(context, "完成指標", info['completion_criterion']),
                  if (info['score'] != null)
                    _buildInfoRow(
                      context,
                      "得分",
                      info['score'].toString().replaceAll(RegExp(r'\.0$'), ''),
                    ),
                ],
              ),
            ),
          ),

          if (desc.isNotEmpty) ...[
            _buildSectionTitle(context, "作業說明"),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.borderColor),
              ),
              child: _cleanHtml(context, desc),
            ),
          ],

          if (uploads.isNotEmpty) ...[
            _buildSectionTitle(context, "附件下載"),
            ...uploads.map((u) {
              return Card(
                elevation: 2,
                color: colorScheme.secondaryCardBackground,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    Icons.attach_file,
                    color: colorScheme.accentBlue,
                  ),
                  title: Text(
                    u['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    u['type'] ?? "file",
                    style: TextStyle(color: colorScheme.subtitleText),
                  ),
                  trailing: Icon(
                    Icons.download_rounded,
                    color: colorScheme.subtitleText,
                  ),
                  onTap: () => _downloadAndOpen(u['reference_id'], u['name']),
                ),
              );
            }).toList(),
          ],

          /*
          if (_data != null &&
              (_data!['is_in_progress'] == true ||
                  _data!['is_in_progress'] == 1)) ...[
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignmentSubmissionPage(
                        homeworkId: widget.homeworkId,
                        courseName: _data!['course_name'] ?? "",
                        title: widget.title,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text(
                  "繳交作業",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          */
        ],
      ),
    );
  }
}
