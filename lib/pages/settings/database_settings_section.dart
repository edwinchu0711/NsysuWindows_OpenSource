import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/local_course_service.dart';
import '../../services/database_embedding_service.dart';
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
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.forum_rounded, color: colorScheme.accentBlue),
            const SizedBox(width: 8),
            Text("評價 (向量) 資料庫", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
          ],
        ),
        const SizedBox(height: 8),
        Text("提供過往學生的修課真實評價，依賴 Embedding 模型進行搜尋。下方所有設定皆與此資料庫相關。", style: TextStyle(fontSize: 13, color: colorScheme.subtitleText)),
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
                      _isDatabaseDbExists ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: _isDatabaseDbExists ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isDatabaseDbExists ? "已下載" : "尚未下載",
                      style: TextStyle(fontWeight: FontWeight.bold, color: _isDatabaseDbExists ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
                if (_isDatabaseDbExists) ...[
                  const SizedBox(height: 8),
                  _buildDbInfoRow(context, "Embedding 模型", _databaseDbEmbeddingModel),
                  _buildDbInfoRow(context, "檔案名稱", _databaseDbFilename),
                ] else ...[
                  const SizedBox(height: 8),
                  Text("請從下方下載評價資料庫，AI 聊天功能需要此資料庫才能運作。", style: TextStyle(fontSize: 13, color: colorScheme.subtitleText)),
                ],
                if (_isDatabaseDbExists)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteDatabaseDb(),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("刪除"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle(context, "自動更新"),
        _buildSettingCard(
          context,
          child: SwitchListTile.adaptive(
            title: Text("評價資料庫", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
            subtitle: Text("啟動時自動檢查並下載最新版本", style: TextStyle(color: colorScheme.subtitleText)),
            value: _isDatabaseDbAutoUpdate,
            onChanged: (val) async {
              setState(() => _isDatabaseDbAutoUpdate = val);
              _saveAutoUpdate(val);
              // Persist is handled by parent via onReload
            },
            activeColor: colorScheme.accentBlue,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(context, "可下載的資料庫"),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: _fetchAvailableDatabases,
                icon: _isLoadingDatabases
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_isLoadingDatabases ? "載入中..." : "重新整理", style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text("選擇 Embedding 模型後，將只顯示對應的資料庫版本。\n可以隨機選取一種資料庫下載，若是出現問題可以換下載其他類型的。",
            style: TextStyle(fontSize: 12, color: colorScheme.subtitleText)),
        const SizedBox(height: 8),
        if (_availableEmbeddingModels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableEmbeddingModels.map((model) {
                final isSelected = _selectedEmbeddingModel == model;
                return ChoiceChip(
                  label: Text(model, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : colorScheme.primaryText, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedEmbeddingModel = model);
                      _saveSelectedEmbeddingModel(model);
                    }
                  },
                  selectedColor: colorScheme.accentBlue,
                  backgroundColor: colorScheme.isDark ? Colors.white10 : Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                  elevation: isSelected ? 2 : 0,
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        if (_availableDatabases.isEmpty && !_isLoadingDatabases)
          _buildSettingCard(
            context,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: Text("點擊「重新整理」以查看可下載的資料庫", style: TextStyle(color: Colors.grey))),
            ),
          ),
        ...filteredDatabases.take(_maxDisplayedDatabases).map((db) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAvailableDbCard(db, colorScheme),
            )),
        if (filteredDatabases.length > _maxDisplayedDatabases)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _maxDisplayedDatabases += 10),
                icon: const Icon(Icons.add_rounded),
                label: Text("顯示更多 (還有 ${filteredDatabases.length - _maxDisplayedDatabases} 個)"),
                style: TextButton.styleFrom(foregroundColor: colorScheme.accentBlue),
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

  Widget _buildAvailableDbCard(Map<String, dynamic> db, ColorScheme colorScheme) {
    final filename = db['db_filename'] as String? ?? '';
    final embeddingModel = db['embedding_model'] as String? ?? '';
    final lastUpdated = db['last_updated'] as String? ?? '';
    final isInstalled = filename == _databaseDbFilename;
    final isDownloading = filename == _downloadingFilename;

    return _buildSettingCard(
      context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(filename, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primaryText), overflow: TextOverflow.ellipsis)),
                      if (isInstalled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green, width: 0.5),
                          ),
                          child: const Text("已下載", style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(embeddingModel, style: TextStyle(fontSize: 12, color: colorScheme.subtitleText)),
                  if (lastUpdated.isNotEmpty)
                    Text(lastUpdated, style: TextStyle(fontSize: 11, color: colorScheme.subtitleText.withOpacity(0.7))),
                ],
              ),
            ),
            if (!isInstalled) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isDownloading ? null : () => _downloadDatabaseDb(db),
                icon: isDownloading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(isDownloading ? "下載中..." : "下載"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
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

  Future<void> _downloadDatabaseDb(Map<String, dynamic> db) async {
    final filename = db['db_filename'] as String?;
    if (filename == null || filename.isEmpty) return;

    setState(() => _downloadingFilename = filename);
    try {
      await DatabaseEmbeddingService.instance.downloadDatabase(
        filename,
        embeddingModel: db['embedding_model'] as String?,
        chunkCount: db['chunk_count'] as int?,
        createdDate: db['created_date'] as String?,
      );
      if (mounted) {
        setState(() {
          _isDatabaseDbExists = true;
          _databaseDbFilename = filename;
          _databaseDbEmbeddingModel = db['embedding_model'] as String? ?? '';
        });
        _showSnackBar("資料庫下載完成");
      }
    } catch (e) {
      _showSnackBar("下載失敗: $e", isError: true);
    } finally {
      if (mounted) setState(() => _downloadingFilename = null);
    }
  }

  void _deleteCoursesDb() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除課程資料庫"),
        content: const Text("確定要刪除 courses.db 嗎？刪除後 AI 聊天將無法使用課程搜尋功能，直到下次登入時自動重建。"),
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

  void _deleteDatabaseDb() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除評價資料庫"),
        content: const Text("確定要刪除 database.db 嗎？刪除後 AI 聊天功能將無法使用，直到重新下載。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseEmbeddingService.instance.deleteDatabase();
              if (mounted) {
                setState(() { _isDatabaseDbExists = false; _databaseDbFilename = ''; _databaseDbEmbeddingModel = ''; });
                _showSnackBar("評價資料庫已刪除");
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("刪除"),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAvailableDatabases() async {
    setState(() => _isLoadingDatabases = true);
    try {
      final client = http.Client();
      try {
        final res = await client.get(
          Uri.parse('https://edwinchu0711.github.io/CourseSelectionDateUpdate/database/version.json'),
        );
        if (res.statusCode == 200) {
          final List<dynamic> list = jsonDecode(res.body);
          final databases = list.cast<Map<String, dynamic>>();
          final models = <String>{};
          for (final db in databases) {
            final model = db['embedding_model'] as String? ?? '';
            if (model.isNotEmpty) models.add(model);
          }
          databases.sort((a, b) {
            final dateA = a['last_updated'] as String? ?? a['created_date'] as String? ?? '';
            final dateB = b['last_updated'] as String? ?? b['created_date'] as String? ?? '';
            return dateB.compareTo(dateA);
          });
          if (mounted) {
            setState(() {
              _availableDatabases = databases;
              _availableEmbeddingModels = models.toList()..sort();
              if (_selectedEmbeddingModel == null || !_availableEmbeddingModels.contains(_selectedEmbeddingModel)) {
                _selectedEmbeddingModel = _availableEmbeddingModels.isNotEmpty ? _availableEmbeddingModels.first : null;
              }
            });
          }
        } else {
          _showSnackBar("無法取得資料庫清單 (HTTP ${res.statusCode})", isError: true);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _showSnackBar("取得資料庫清單失敗: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingDatabases = false);
    }
  }

  Future<void> _saveSelectedEmbeddingModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_embedding_model', model);
  }

  Future<void> _saveAutoUpdate(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('database_db_auto_update', val);
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