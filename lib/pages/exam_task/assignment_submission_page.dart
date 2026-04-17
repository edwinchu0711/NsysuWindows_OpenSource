import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/exam_task/elearn_task_HW_service.dart';
import '../../theme/app_theme.dart';

class AssignmentSubmissionPage extends StatefulWidget {
  final int homeworkId;
  final String courseName;
  final String title;

  const AssignmentSubmissionPage({
    Key? key,
    required this.homeworkId,
    required this.courseName,
    required this.title,
  }) : super(key: key);

  @override
  State<AssignmentSubmissionPage> createState() =>
      _AssignmentSubmissionPageState();
}

class _AssignmentSubmissionPageState extends State<AssignmentSubmissionPage> {
  bool _isLoading = true;
  List<dynamic> _resources = [];
  String _error = "";
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _fetchResources();
  }

  Future<void> _fetchResources() async {
    setState(() {
      _isLoading = true;
      _error = "";
    });
    try {
      final resources = await ElearnService.instance.fetchUserResources();
      if (mounted) {
        setState(() {
          _resources = resources;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        if (e.toString().contains("尚未設定帳號密碼") ||
            e.toString().contains("登入失敗")) {
          _showSessionExpiredDialog();
        }
      }
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("連線已過期"),
        content: const Text("您的登入狀態已失效，請回到首頁重新登入。"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      int fileSize = result.files.single.size;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.1;
      });

      try {
        final initData = await ElearnService.instance.initiateUpload(
          fileName,
          fileSize,
        );
        String uploadUrl = initData['upload_url'];

        setState(() {
          _uploadProgress = 0.4;
        });

        await ElearnService.instance.uploadFileBody(uploadUrl, file);

        setState(() {
          _uploadProgress = 1.0;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("檔案 $fileName 上傳成功！")));
        _fetchResources();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("上傳失敗: $e"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted)
          setState(() {
            _isUploading = false;
          });
      }
    }
  }

  String _formatSize(int size) {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) return "${(size / 1024).toStringAsFixed(1)} KB";
    return "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  String _formatDate(String isoString) {
    try {
      DateTime dt = DateTime.parse(isoString).toLocal();
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: AppBar(
        title: const Text("繳交作業"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.primaryText,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchResources,
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: colorScheme.borderColor),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader("網大雲端"),
                      if (_isUploading)
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          color: Colors.indigo,
                        ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _error.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "載入失敗: $_error",
                                      style: TextStyle(
                                        color: colorScheme.subtitleText,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _fetchResources,
                                      child: const Text("重試"),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _resources.length,
                                itemBuilder: (context, index) {
                                  final item = _resources[index];
                                  return _buildFileCard(item);
                                },
                              ),
                      ),
                      _buildUploadButton(),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildHeaderWithSubmit("提交內容"),
                    Expanded(
                      child: Container(
                        color: colorScheme.secondaryCardBackground.withOpacity(
                          0.3,
                        ),
                        child: Center(
                          child: Text(
                            "請從左側上傳或選擇檔案...",
                            style: TextStyle(
                              color: colorScheme.subtitleText,
                              fontSize: 16,
                            ),
                          ),
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
    );
  }

  Widget _buildHeaderWithSubmit(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: double.infinity,
      color: colorScheme.secondaryCardBackground,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primaryText,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("繳交功能已準備就緒")));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text(
              "繳交",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      color: colorScheme.secondaryCardBackground,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: colorScheme.primaryText,
        ),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.borderColor),
      ),
      color: colorScheme.cardBackground,
      child: ListTile(
        leading: Icon(
          Icons.insert_drive_file_outlined,
          color: Colors.indigo.shade300,
        ),
        title: Text(
          item['name'] ?? "未知檔案",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primaryText,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "${_formatSize(item['size'] ?? 0)} • ${_formatDate(item['updated_at'] ?? item['created_at'])}",
          style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
        ),
        trailing: const Icon(
          Icons.check_circle_outline,
          color: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cloud_upload_outlined),
        label: Text(_isUploading ? "正在上傳..." : "上傳新檔案至雲端"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
