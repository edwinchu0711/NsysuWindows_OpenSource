import 'dart:convert';

class AiConfig {
  final String id;
  final String name;
  final String type; // 'google' or 'openai'
  final String model;
  final String apiKey;
  final String? baseUrl;

  AiConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.model,
    required this.apiKey,
    this.baseUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'model': model,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
    };
  }

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      model: json['model'] as String,
      apiKey: json['apiKey'] as String,
      baseUrl: json['baseUrl'] as String?,
    );
  }

  // 生成實際呼叫的網址
  String get effectiveBaseUrl {
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      return baseUrl!;
    }
    if (type == 'google') {
      // Strip "models/" prefix to avoid doubling it in the URL path
      final bareModel = model.startsWith('models/')
          ? model.substring(7)
          : model;
      return 'https://generativelanguage.googleapis.com/v1beta/models/$bareModel:generateContent';
    }
    // OpenAI 預設
    return 'https://api.openai.com/v1/chat/completions';
  }

  String get effectiveEmbeddingUrl {
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      // 如果有自訂網址，通常 embedding 網址會跟 completions 不同，
      // 這裡暫時假設使用者會處理，或者預設 OpenAI 格式
      return baseUrl!;
    }
    if (type == 'google') {
      // Strip "models/" prefix to avoid doubling it in the URL path
      final bareModel = model.startsWith('models/')
          ? model.substring(7)
          : model;
      return 'https://generativelanguage.googleapis.com/v1beta/models/$bareModel:embedContent';
    }
    // OpenAI 預設
    return 'https://api.openai.com/v1/embeddings';
  }

  static List<AiConfig> decode(String listJson) {
    if (listJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(listJson);
    return decoded.map((item) => AiConfig.fromJson(item)).toList();
  }

  static String encode(List<AiConfig> configs) {
    return jsonEncode(configs.map((c) => c.toJson()).toList());
  }
}
