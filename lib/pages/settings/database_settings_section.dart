import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/local_course_service.dart';
import '../../services/course_query_service.dart';
import '../../theme/app_theme.dart';

class DatabaseSettingsSection extends StatefulWidget {
  final bool isCoursesDbExists;
  final String courseDbSemester;
  final String courseDbTimestamp;
  final int courseDbCourseCount;
  final bool isDatabaseDbExists;
  final String databaseDbFilename;
  final String databaseDbEmbeddingModel;
  final bool isDatabaseDbAutoUpdate;
  final String? selectedEmbeddingModel;
  final List<String> availableEmbeddingModels;
  final List<Map<String, dynamic>> availableDatabases;
  final bool isLoadingDatabases;
  final String? downloadingFilename;
  final VoidCallback onReload;

  const DatabaseSettingsSection({
    super.key,
    required this.isCoursesDbExists,
    required this.courseDbSemester,
    required this.courseDbTimestamp,
    required this.courseDbCourseCount,
    required this.isDatabaseDbExists,
    required this.databaseDbFilename,
    required this.databaseDbEmbeddingModel,
    required this.isDatabaseDbAutoUpdate,
    required this.selectedEmbeddingModel,
    required this.availableEmbeddingModels,
    required this.availableDatabases,
    required this.isLoadingDatabases,
    required this.downloadingFilename,
    required this.onReload,
  });

  @override
  State<DatabaseSettingsSection> createState() => _DatabaseSettingsSectionState();
}

class _DatabaseSettingsSectionState extends State<DatabaseSettingsSection> {
  bool _isCoursesDbExists = false;
  String _courseDbSemester = '';
  String _courseDbTimestamp = '';
  int _courseDbCourseCount = 0;
  bool _isDatabaseDbExists = false;
  String _databaseDbFilename = '';
  String _databaseDbEmbeddingModel = '';
  bool _isDatabaseDbAutoUpdate = true;
  String? _selectedEmbeddingModel;
  List<String> _availableEmbeddingModels = [];
  List<Map<String, dynamic>> _availableDatabases = [];
  bool _isLoadingDatabases = false;
  String? _downloadingFilename;
  bool _isCoursesDownloading = false;
  int _maxDisplayedDatabases = 5;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant DatabaseSettingsSection old) {
    super.didUpdateWidget(old);
    _syncFromWidget();
  }

  void _syncFromWidget() {
    _isCoursesDbExists = widget.isCoursesDbExists;
    _courseDbSemester = widget.courseDbSemester;
    _courseDbTimestamp = widget.courseDbTimestamp;
    _courseDbCourseCount = widget.courseDbCourseCount;
    _isDatabaseDbExists = widget.isDatabaseDbExists;
    _databaseDbFilename = widget.databaseDbFilename;
    _databaseDbEmbeddingModel = widget.databaseDbEmbeddingModel;
    _isDatabaseDbAutoUpdate = widget.isDatabaseDbAutoUpdate;
    _selectedEmbeddingModel = widget.selectedEmbeddingModel;
    _availableEmbeddingModels = widget.availableEmbeddingModels;
    _availableDatabases = widget.availableDatabases;
    _isLoadingDatabases = widget.isLoadingDatabases;
    _downloadingFilename = widget.downloadingFilename;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredDatabases = _availableDatabases.where((db) {
      if (_selectedEmbeddingModel == null) return true;
      return (db['embedding_model'] as String? ?? '') == _selectedEmbeddingModel;
    }).toList();

    return ListView(
      key: const ValueKey("database"),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.library_books_rounded, color: colorScheme.accentBlue),
            const SizedBox(width: 8),
            Text("課程資料庫", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
          ],
        ),
        const SizedBox(height: 8),
        Text("包含全校課程與教師資訊。選課指南的大多數功能與此資料庫相關。", style: TextStyle(fontSize: 13, color: colorScheme.subtitleText)),
        const SizedBox(height: 16),
        _buildSectionTitle(context, "目前狀態"),
        _buildSettingCard(
          context,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCoursesDbExists ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: _isCoursesDbExists ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCoursesDbExists ? "已下載" : "尚未下載",
                      style: TextStyle(fontWeight: FontWeight.bold, color: _isCoursesDbExists ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
                if (_isCoursesDbExists) ...[
                  const SizedBox(height: 8),
                  _buildDbInfoRow(context, "學期", _courseDbSemester),
                  _buildDbInfoRow(context, "更新時間", _courseDbTimestamp),
                  _buildDbInfoRow(context, "課程數量", _courseDbCourseCount.toString()),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteCoursesDb(),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("刪除"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text("課程資料庫將在登入後自動下載。若尚未下載，可點擊右側按鈕手動更新。", style: TextStyle(fontSize: 13, color: colorScheme.subtitleText)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isCoursesDownloading ? null : _downloadCoursesDb,
                        icon: _isCoursesDownloading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(_isCoursesDownloading ? "下載中..." : "手動下載"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.accentBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDbInfoRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    String displayValue = value.isEmpty ? "—" : value;
    if (label == "學期" && value.length == 4) {
      displayValue = "${value.substring(0, 3)}-${value.substring(3)}";
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: colorScheme.subtitleText, fontWeight: FontWeight.w500))),
          Expanded(child: Text(displayValue, style: TextStyle(fontSize: 13, color: colorScheme.primaryText))),
        ],
      ),
    );
  }

  Future<void> _downloadCoursesDb() async {
    setState(() => _isCoursesDownloading = true);
    try {
      await CourseQueryService.instance.getCourses(forceRefresh: true);
      widget.onReload();
      _showSnackBar("課程資料庫下載成功");
    } catch (e) {
      _showSnackBar("下載失敗: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isCoursesDownloading = false);
    }
  }

  void _deleteCoursesDb() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除課程資料庫"),
        content: const Text("確定要刪除 courses.db 嗎？刪除後選課助手將無法使用課程搜尋功能，直到下次登入時自動重建。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalCourseService.instance.deleteCoursesDb();
              if (mounted) {
                setState(() { _isCoursesDbExists = false; _courseDbSemester = ''; _courseDbTimestamp = ''; _courseDbCourseCount = 0; });
                _showSnackBar("課程資料庫已刪除");
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green, duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.accentBlue, letterSpacing: 1.2)),
    );
  }

  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.secondaryCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.borderColor, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: child),
      ),
    );
  }
}