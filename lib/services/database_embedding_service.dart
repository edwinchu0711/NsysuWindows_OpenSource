import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ai_config_model.dart';
import 'ai/ai_client.dart';

class DatabaseEmbeddingService {
  static final DatabaseEmbeddingService instance =
      DatabaseEmbeddingService._privateConstructor();
  DatabaseEmbeddingService._privateConstructor();

  Database? _db;
  List<Map<String, dynamic>> _cache = [];
  List<Map<String, dynamic>> _rulesCache = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await Utils.getAppDbDirectory();
    final path = join(dbPath, "database.db");

    final file = File(path);
    if (!await file.exists()) {
      // DB doesn't exist yet — not initialized, but don't crash
      _initialized = false;
      return;
    }

    _db = await openDatabase(path);

    // Cache the entire embeddings table in memory since it's only 1.5MB
    final rows = await _db!.query('embeddings');
    _cache = rows.map((r) {
      return {
        'id': r['id'],
        'course_name': r['course_name'],
        'professor': r['professor'],
        'content': r['content'],
        'source': r['source'],
        'vector': _blobToFloatList(r['vector'] as Uint8List),
      };
    }).toList();

    // Cache the rules table (contains course selection rules for current semester)
    try {
      final rulesRows = await _db!.query('rules');
      _rulesCache = rulesRows.map((r) {
        return {
          'id': r['id'],
          'title': r['title'],
          'content': r['content'],
          'source': r['source'],
          'chunk_index': r['chunk_index'],
          'vector': r['vector'] != null
              ? _blobToFloatList(r['vector'] as Uint8List)
              : <double>[],
        };
      }).toList();
      print('[DatabaseEmbeddingService] Loaded ${_rulesCache.length} rule chunks');
    } catch (e) {
      print('[DatabaseEmbeddingService] No rules table found or error: $e');
      _rulesCache = [];
    }

    _initialized = true;
  }

  /// Normalize model name by stripping any "models/" prefix,
  /// since the API URL and request body add it themselves.
  static String _normalizeModelName(String model) {
    if (model.startsWith('models/')) {
      return model.substring(7);
    }
    return model;
  }

  /// Reset state so the service can be re-initialized after DB rebuild
  void reset() {
    _db?.close();
    _db = null;
    _cache = [];
    _rulesCache = [];
    _initialized = false;
  }

  /// Download a database file from the remote repository
  Future<void> downloadDatabase(String filename, {
    String? embeddingModel,
    int? chunkCount,
    String? createdDate,
  }) async {
    final client = http.Client();
    try {
      final url = 'https://edwinchu0711.github.io/CourseSelectionDateUpdate/database/$filename';
      final response = await client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('下載失敗: HTTP ${response.statusCode}');
      }

      final dbPath = await Utils.getAppDbDirectory();
      final path = join(dbPath, "database.db");

      // Close and delete old DB if exists
      _db?.close();
      _db = null;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      // Write new DB
      await file.writeAsBytes(response.bodyBytes, flush: true);

      // Save metadata to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('database_db_filename', filename);
      if (embeddingModel != null) await prefs.setString('database_db_embedding_model', _normalizeModelName(embeddingModel));
      if (chunkCount != null) await prefs.setInt('database_db_chunk_count', chunkCount);
      if (createdDate != null) await prefs.setString('database_db_created_date', createdDate);

      // Auto-detect embedding model: update embedding_config if model is provided
      if (embeddingModel != null && embeddingModel.isNotEmpty) {
        final normalizedModel = _normalizeModelName(embeddingModel);
        final embeddingJson = prefs.getString('embedding_config');
        AiConfig config;
        if (embeddingJson != null) {
          config = AiConfig.fromJson(jsonDecode(embeddingJson));
          config = AiConfig(
            id: config.id,
            name: config.name,
            type: config.type,
            model: normalizedModel,
            apiKey: config.apiKey,
            baseUrl: config.baseUrl,
          );
        } else {
          config = AiConfig(
            id: 'embedding_default',
            name: 'Embedding 模型',
            type: 'google',
            model: normalizedModel,
            apiKey: '',
          );
        }
        await prefs.setString('embedding_config', jsonEncode(config.toJson()));
        print('[DatabaseEmbeddingService] Auto-configured embedding model: $normalizedModel');
      }

      // Re-initialize
      reset();
      await init();
      print('[DatabaseEmbeddingService] Database downloaded and initialized: $filename');
    } finally {
      client.close();
    }
  }

  /// Delete the database.db file and reset state
  Future<void> deleteDatabase() async {
    _db?.close();
    _db = null;
    _cache = [];
    _rulesCache = [];
    _initialized = false;

    final dbPath = await Utils.getAppDbDirectory();
    final path = join(dbPath, "database.db");
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('database_db_filename');
    await prefs.remove('database_db_embedding_model');
    await prefs.remove('database_db_chunk_count');
    await prefs.remove('database_db_created_date');
  }

  /// Check for auto-update of database.db on startup
  Future<void> checkForAutoUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final autoUpdate = prefs.getBool('database_db_auto_update') ?? true;
    if (!autoUpdate) return;

    try {
      final client = http.Client();
      try {
        final res = await client.get(
          Uri.parse('https://edwinchu0711.github.io/CourseSelectionDateUpdate/database/version.json'),
        );
        if (res.statusCode != 200) return;

        final List<dynamic> versionList = jsonDecode(res.body);
        if (versionList.isEmpty) return;

        // Get selected embedding model filter
        final selectedModel = prefs.getString('selected_embedding_model');

        // Filter by model if selected, then sort by last_updated (newest first)
        List<Map<String, dynamic>> candidates;
        if (selectedModel != null && selectedModel.isNotEmpty) {
          candidates = versionList
              .where((v) => (v as Map<String, dynamic>)['embedding_model'] == selectedModel)
              .cast<Map<String, dynamic>>()
              .toList();
        } else {
          candidates = versionList.cast<Map<String, dynamic>>();
        }

        if (candidates.isEmpty) return;

        // Sort by last_updated descending (newest first)
        candidates.sort((a, b) {
          final dateA = a['last_updated'] as String? ?? a['created_date'] as String? ?? '';
          final dateB = b['last_updated'] as String? ?? b['created_date'] as String? ?? '';
          return dateB.compareTo(dateA);
        });

        final latest = candidates.first;
        final latestFilename = latest['db_filename'] as String? ?? '';
        final currentFilename = prefs.getString('database_db_filename') ?? '';

        if (latestFilename.isNotEmpty && latestFilename != currentFilename) {
          print('[DatabaseEmbeddingService] Auto-updating database: $currentFilename → $latestFilename');
          await downloadDatabase(
            latestFilename,
            embeddingModel: latest['embedding_model'] as String?,
            chunkCount: latest['chunk_count'] as int?,
            createdDate: latest['created_date'] as String?,
          );
        } else {
          print('[DatabaseEmbeddingService] Database is up to date: $currentFilename');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('[DatabaseEmbeddingService] Auto-update check failed: $e');
    }
  }

  List<double> _blobToFloatList(Uint8List blob) {
    // Assuming Float32
    return blob.buffer.asFloat32List(blob.offsetInBytes, blob.lengthInBytes ~/ 4).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
        dotProduct += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Check if any embedding row matches the given course name (after stripping brackets)
  bool hasCourseByName(String courseName) {
    if (!_initialized) {
      // Try to initialize if not already
      init();
      return false;
    }
    final strippedName = _stripBrackets(courseName);
    for (final row in _cache) {
      final embName = row['course_name']?.toString() ?? '';
      final strippedEmbName = _stripBrackets(embName);
      if (strippedEmbName.contains(strippedName) || strippedName.contains(strippedEmbName)) {
        return true;
      }
    }
    return false;
  }

  /// Find embedding rows matching the given course name (after stripping brackets)
  List<Map<String, dynamic>> findByName(String courseName) {
    if (!_initialized) {
      init();
      return [];
    }
    final strippedName = _stripBrackets(courseName);
    final results = <Map<String, dynamic>>[];
    for (final row in _cache) {
      final embName = row['course_name']?.toString() ?? '';
      final strippedEmbName = _stripBrackets(embName);
      if (strippedEmbName.contains(strippedName) || strippedName.contains(strippedEmbName)) {
        results.add({
          'course_name': embName,
          'professor': row['professor']?.toString() ?? '',
          'content': row['content']?.toString() ?? '',
          'source': row['source']?.toString() ?? '',
        });
      }
    }
    return results;
  }

  /// Removes parentheses (both full-width and half-width) and English suffix from course names.
  /// Also strips "服務學習：" / "服務學習:" prefix so that review names like
  /// "圖書館志工" can match formal course names like "服務學習：圖書館志工".
  /// name_zh_en format: "微積分\nCalculus" → strip to "微積分"
  String _stripBrackets(String s) {
    // Remove English suffix after \n first
    var withoutEnglish = s.split('\n').first;
    // Strip "服務學習：" / "服務學習:" prefix (full-width and half-width colon)
    withoutEnglish = withoutEnglish.replaceAll(RegExp(r'服務學習[：:]\s*'), '');
    return withoutEnglish.replaceAll(RegExp(r'（.*?）|\(.*?\)', unicode: true), '').trim();
  }

  Future<List<Map<String, dynamic>>> searchTopK(
    List<double> queryEmbedding, {
    int k = 3,
    double threshold = 0.55,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return [];

    final results = _cache.map((row) {
      final similarity = _cosineSimilarity(queryEmbedding, row['vector'] as List<double>);
      return {
        'content': row['content'].toString(),
        'source': row['source']?.toString(),
        'course_name': row['course_name']?.toString() ?? '',
        'professor': row['professor']?.toString() ?? '',
        'similarity': similarity,
      };
    }).toList();

    // 加上相似度門檻過濾不相干的結果
    final filteredResults = results.where((r) => (r['similarity'] as double) >= threshold).toList();

    filteredResults.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));

    return filteredResults.take(k).toList();
  }

  Future<List<Map<String, dynamic>>> embedAndSearch(
    String text, {
    int k = 3,
    double threshold = 0.55,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final embeddingJson = prefs.getString('embedding_config');
    AiConfig config;
    if (embeddingJson != null) {
      config = AiConfig.fromJson(jsonDecode(embeddingJson));
      // Normalize: strip "models/" prefix if present (version.json includes it)
      if (config.model.startsWith('models/')) {
        config = AiConfig(
          id: config.id,
          name: config.name,
          type: config.type,
          model: _normalizeModelName(config.model),
          apiKey: config.apiKey,
          baseUrl: config.baseUrl,
        );
      }
    } else {
      config = AiConfig(
        id: 'embedding_default',
        name: 'Embedding 模型',
        type: 'google',
        model: 'gemini-embedding-2-preview',
        apiKey: '',
      );
    }

    if (config.apiKey.isEmpty) {
      // 若無設定 Embedding API Key，嘗試使用系統的主要設定
      final mainConfigsStr = prefs.getString('ai_configs') ?? '[]';
      final List<AiConfig> mainConfigs = AiConfig.decode(mainConfigsStr);
      if (mainConfigs.isNotEmpty && mainConfigs.first.apiKey.isNotEmpty) {
        config = AiConfig(
          id: config.id,
          name: config.name,
          type: mainConfigs.first.type,
          model: config.model,
          apiKey: mainConfigs.first.apiKey,
        );
      }
    }

    if (config.apiKey.isEmpty) {
      throw Exception("請先設定 Embedding API Key");
    }

    final client = AiClient(config: config);
    final queryEmbedding = await client.embedText(text);

    return searchTopK(queryEmbedding, k: k, threshold: threshold);
  }

  /// Search the rules table for course selection rules relevant to the query
  Future<List<Map<String, dynamic>>> searchRules(
    String text, {
    int k = 5,
    double threshold = 0.45,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return [];

    if (_rulesCache.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final embeddingJson = prefs.getString('embedding_config');
    AiConfig config;
    if (embeddingJson != null) {
      config = AiConfig.fromJson(jsonDecode(embeddingJson));
      // Normalize: strip "models/" prefix if present (version.json includes it)
      if (config.model.startsWith('models/')) {
        config = AiConfig(
          id: config.id,
          name: config.name,
          type: config.type,
          model: _normalizeModelName(config.model),
          apiKey: config.apiKey,
          baseUrl: config.baseUrl,
        );
      }
    } else {
      config = AiConfig(
        id: 'embedding_default',
        name: 'Embedding 模型',
        type: 'google',
        model: 'gemini-embedding-2-preview',
        apiKey: '',
      );
    }

    if (config.apiKey.isEmpty) {
      final mainConfigsStr = prefs.getString('ai_configs') ?? '[]';
      final List<AiConfig> mainConfigs = AiConfig.decode(mainConfigsStr);
      if (mainConfigs.isNotEmpty && mainConfigs.first.apiKey.isNotEmpty) {
        config = AiConfig(
          id: config.id,
          name: config.name,
          type: mainConfigs.first.type,
          model: config.model,
          apiKey: mainConfigs.first.apiKey,
        );
      }
    }

    if (config.apiKey.isEmpty) return [];

    try {
      final client = AiClient(config: config);
      final queryEmbedding = await client.embedText(text);

      final results = _rulesCache.map((row) {
        final vector = row['vector'] as List<double>;
        if (vector.isEmpty) {
          return {
            'content': row['content'].toString(),
            'source': row['source']?.toString() ?? '',
            'chunk_index': row['chunk_index'],
            'similarity': 0.0,
          };
        }
        final similarity = _cosineSimilarity(queryEmbedding, vector);
        return {
          'content': row['content'].toString(),
          'source': row['source']?.toString() ?? '',
          'chunk_index': row['chunk_index'],
          'similarity': similarity,
        };
      }).toList();

      final filteredResults = results
          .where((r) => (r['similarity'] as double) >= threshold)
          .toList();
      filteredResults.sort(
          (a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));

      return filteredResults.take(k).toList();
    } catch (e) {
      print('[DatabaseEmbeddingService] searchRules error: $e');
      return [];
    }
  }
}
