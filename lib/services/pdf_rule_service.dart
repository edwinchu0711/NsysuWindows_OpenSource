import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfRuleService {
  static final PdfRuleService instance = PdfRuleService._privateConstructor();
  PdfRuleService._privateConstructor();

  static const _cacheKeyText = 'pdf_rule_cached_text';
  static const _cacheKeyUrl = 'pdf_rule_cached_url';
  static const _cacheKeyAt = 'pdf_rule_cached_at';
  static const _cacheTtl = Duration(hours: 3);

  String? _cachedText;
  bool _isFetching = false;
  DateTime? _lastFetchAttempt;
  String? _lastErrorMessage;

  bool get isLoaded => _cachedText != null && _cachedText!.isNotEmpty;
  bool get isFetching => _isFetching;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get fullText => _cachedText;

  void clearCache() {
    _cachedText = null;
    _lastFetchAttempt = null;
    _lastErrorMessage = null;
    _clearPersistentCache();
  }

  Future<void> _clearPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyText);
      await prefs.remove(_cacheKeyUrl);
      await prefs.remove(_cacheKeyAt);
    } catch (e) {
      print('[PdfRuleService] Failed to clear persistent cache: $e');
    }
  }

  bool get _shouldRetryFetch {
    if (_lastFetchAttempt == null) return true;
    return DateTime.now().difference(_lastFetchAttempt!) >
        const Duration(seconds: 60);
  }

  /// 嘗試從本地快取載入，若未過期則回傳 true
  Future<bool> _loadFromPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAtStr = prefs.getString(_cacheKeyAt);
      final cachedText = prefs.getString(_cacheKeyText);
      if (cachedAtStr == null || cachedText == null || cachedText.isEmpty) {
        return false;
      }
      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt == null) return false;
      if (DateTime.now().difference(cachedAt) > _cacheTtl) {
        print('[PdfRuleService] Persistent cache expired');
        await _clearPersistentCache();
        return false;
      }
      _cachedText = cachedText;
      print(
        '[PdfRuleService] Loaded ${cachedText.length} chars from persistent cache',
      );
      return true;
    } catch (e) {
      print('[PdfRuleService] Failed to load persistent cache: $e');
      return false;
    }
  }

  Future<void> _saveToPersistentCache(String text, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyText, text);
      await prefs.setString(_cacheKeyUrl, url);
      await prefs.setString(_cacheKeyAt, DateTime.now().toIso8601String());
    } catch (e) {
      print('[PdfRuleService] Failed to save persistent cache: $e');
    }
  }

  Future<bool> fetchAndCache({String? pdfUrl}) async {
    // 1. 檢查記憶體快取
    if (isLoaded) return true;

    // 2. 檢查持久化快取
    if (!isLoaded) {
      final loaded = await _loadFromPersistentCache();
      if (loaded) return true;
    }

    if (_isFetching) {
      while (_isFetching) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return isLoaded;
    }
    if (!_shouldRetryFetch) {
      _lastErrorMessage ??= '最近一次下載失敗，請稍後再試';
      return false;
    }

    _isFetching = true;
    _lastFetchAttempt = DateTime.now();
    _lastErrorMessage = null;

    try {
      // 1. 取得 PDF URL
      String targetUrl;
      if (pdfUrl != null) {
        targetUrl = pdfUrl;
      } else {
        final scrapedUrl = await _scrapePdfUrl();
        if (scrapedUrl == null) {
          _lastErrorMessage =
              '目前無法在選課網站找到選課須知 PDF，可能是學校尚未公告。請稍後再試或直接前往 selcrs.nsysu.edu.tw 查看。';
          return false;
        }
        targetUrl = scrapedUrl;
      }

      // 2. 下載 PDF
      final pdfBytes = await _downloadPdf(targetUrl);

      // 3. 提取文字
      final text = _extractTextFromPdf(pdfBytes);

      _cachedText = text;
      _lastErrorMessage = null;

      // 4. 寫入持久化快取
      await _saveToPersistentCache(text, targetUrl);

      print('[PdfRuleService] Loaded ${text.length} chars from $targetUrl');
      return true;
    } on _PdfRuleException catch (e) {
      _lastErrorMessage = e.message;
      return false;
    } catch (e) {
      _lastErrorMessage = 'PDF 抓取失敗: $e';
      return false;
    } finally {
      _isFetching = false;
    }
  }

  Future<String?> _scrapePdfUrl() async {
    const baseUrl = 'https://selcrs.nsysu.edu.tw/';

    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw _PdfRuleException('無法連線至中山大學選課網站，請檢查網路連線後再試。');
      }

      final document = html_parser.parse(response.body);
      final pdfUrl = _findPdfLink(document, baseUrl);
      if (pdfUrl != null) return pdfUrl;

      // 跟進含有選課須知關鍵字的連結
      final subLinkUrl = _findSubLink(document, baseUrl);
      if (subLinkUrl != null) {
        try {
          final subResponse = await http
              .get(Uri.parse(subLinkUrl))
              .timeout(const Duration(seconds: 10));
          if (subResponse.statusCode == 200) {
            final subDoc = html_parser.parse(subResponse.body);
            final subPdfUrl = _findPdfLink(subDoc, subLinkUrl);
            if (subPdfUrl != null) return subPdfUrl;
          }
        } catch (_) {}
      }

      // Fallback: 頁面上所有 PDF 連結，優先含「選課」「須知」的
      final allPdfLinks = _findAllPdfLinks(document, baseUrl);
      for (final kw in ['選課', '須知', '課程', '注意']) {
        for (final link in allPdfLinks) {
          if (link.text.contains(kw) || link.url.contains(kw)) {
            return link.url;
          }
        }
      }
      if (allPdfLinks.isNotEmpty) return allPdfLinks.first.url;

      return null;
    } on _PdfRuleException {
      rethrow;
    } catch (e) {
      throw _PdfRuleException('無法連線至中山大學選課網站，請檢查網路連線後再試。');
    }
  }

  String? _findPdfLink(dynamic document, String baseUrl) {
    final keywords = ['選課須知', '選課須知及注意事項', '選課手冊'];

    final anchors = document.querySelectorAll('a');
    for (final a in anchors) {
      final href = a.attributes['href'] ?? '';
      final text = (a.text ?? '') + (a.attributes['title'] ?? '');

      final isPdf =
          href.toLowerCase().endsWith('.pdf') ||
          href.toLowerCase().contains('.pdf?');
      final hasKeyword = keywords.any(
        (kw) => text.contains(kw) || href.contains(kw),
      );

      if (isPdf && hasKeyword) {
        return _resolveUrl(baseUrl, href);
      }
    }

    // 找含關鍵字的 PDF
    for (final a in anchors) {
      final href = a.attributes['href'] ?? '';
      final text = (a.text ?? '') + (a.attributes['title'] ?? '');
      if (keywords.any((kw) => text.contains(kw))) {
        final resolved = _resolveUrl(baseUrl, href);
        if (resolved.toLowerCase().endsWith('.pdf') ||
            resolved.toLowerCase().contains('.pdf?')) {
          return resolved;
        }
      }
    }

    return null;
  }

  String? _findSubLink(dynamic document, String baseUrl) {
    final keywords = ['選課須知', '注意事項', '選課公告', '選課手冊'];
    final anchors = document.querySelectorAll('a');
    for (final a in anchors) {
      final href = a.attributes['href'] ?? '';
      final text = (a.text ?? '') + (a.attributes['title'] ?? '');
      if (keywords.any((kw) => text.contains(kw))) {
        return _resolveUrl(baseUrl, href);
      }
    }
    return null;
  }

  List<_PdfLink> _findAllPdfLinks(dynamic document, String baseUrl) {
    final links = <_PdfLink>[];
    final anchors = document.querySelectorAll('a');
    for (final a in anchors) {
      final href = a.attributes['href'] ?? '';
      if (href.toLowerCase().endsWith('.pdf') ||
          href.toLowerCase().contains('.pdf?')) {
        final text = (a.text ?? '') + (a.attributes['title'] ?? '');
        links.add(_PdfLink(_resolveUrl(baseUrl, href), text));
      }
    }
    return links;
  }

  String _resolveUrl(String baseUrl, String href) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$href';
    }
    return '$baseUrl$href';
  }

  Future<List<int>> _downloadPdf(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw _PdfRuleException('下載選課須知 PDF 失敗 (HTTP ${response.statusCode})');
      }
      return response.bodyBytes;
    } catch (e) {
      if (e is _PdfRuleException) rethrow;
      throw _PdfRuleException('無法連線至中山大學選課網站，請檢查網路連線後再試。');
    }
  }

  String _extractTextFromPdf(List<int> pdfBytes) {
    try {
      final doc = PdfDocument(inputBytes: pdfBytes);
      final extractor = PdfTextExtractor(doc);

      final textParts = <String>[];
      for (int i = 0; i < doc.pages.count; i++) {
        final pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        if (pageText.trim().isNotEmpty) {
          textParts.add(_cleanText(pageText));
        }
      }

      doc.dispose();
      return textParts.join('\n\n');
    } catch (e) {
      throw _PdfRuleException('選課須知 PDF 解析失敗，可能是格式問題。請稍後再試。');
    }
  }

  String _cleanText(String text) {
    // 移除過多連續空白
    text = text.replaceAll(RegExp(r' {3,}'), ' ');
    // 修復 CJK 斷行
    text = text.replaceAll(
      RegExp(r'(?<=[^\s。，！？；：、」）】》　])\n(?=[^\s。，！？；：、「（【《　])'),
      '',
    );
    // 移除頁碼行
    text = text.replaceAll(RegExp(r'\n\s*\d{1,3}\s*\n'), '\n');
    // 壓縮多個連續換行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  List<String> searchRelevantChunks(String query, {int maxChunks = 8}) {
    if (!isLoaded || _cachedText == null) return [];

    final chunks = _chunkText(_cachedText!);
    final queryTerms = _tokenize(query);

    if (queryTerms.isEmpty) return [];

    final scored = <_ScoredChunk>[];
    for (final chunk in chunks) {
      double score = 0;
      for (final term in queryTerms) {
        final count = _countOccurrences(chunk, term);
        score += count;
        if (count > 0) score += 1.0;
      }
      if (score > 0) scored.add(_ScoredChunk(chunk, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxChunks).map((s) => s.text).toList();
  }

  List<String> _chunkText(String text, {int chunkSize = 500}) {
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;

      if (buffer.length + trimmed.length > chunkSize && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(trimmed);
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks;
  }

  List<String> _tokenize(String text) {
    final tokens = <String>[];
    // CJK bigrams
    final cjkPattern = RegExp(r'[一-鿿]+');
    for (final match in cjkPattern.allMatches(text)) {
      final s = match.group(0)!;
      if (s.length == 1) {
        tokens.add(s);
      } else {
        for (int i = 0; i < s.length - 1; i++) {
          tokens.add(s.substring(i, i + 2));
        }
      }
    }
    // English words
    final engPattern = RegExp(r'[a-zA-Z]+');
    for (final match in engPattern.allMatches(text)) {
      final w = match.group(0)!;
      if (w.length >= 2) tokens.add(w.toLowerCase());
    }
    return tokens;
  }

  int _countOccurrences(String text, String term) {
    int count = 0;
    int index = 0;
    while ((index = text.indexOf(term, index)) != -1) {
      count++;
      index += term.length;
    }
    return count;
  }
}

class _PdfLink {
  final String url;
  final String text;
  _PdfLink(this.url, this.text);
}

class _ScoredChunk {
  final String text;
  final double score;
  _ScoredChunk(this.text, this.score);
}

class _PdfRuleException implements Exception {
  final String message;
  _PdfRuleException(this.message);
  @override
  String toString() => message;
}
