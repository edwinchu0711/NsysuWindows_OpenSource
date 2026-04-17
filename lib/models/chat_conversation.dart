import 'dart:convert';

class ChatConversation {
  final String id;
  String title;
  List<Map<String, dynamic>> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  final String configId;

  ChatConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    required this.configId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'configId': configId,
  };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      messages: List<Map<String, dynamic>>.from(
        (json['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      configId: json['configId'] as String,
    );
  }

  static List<ChatConversation> decode(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((e) => ChatConversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String encode(List<ChatConversation> conversations) {
    return jsonEncode(conversations.map((c) => c.toJson()).toList());
  }

  /// Generate a title from the first user message
  static String generateTitle(List<Map<String, dynamic>> messages) {
    for (var msg in messages) {
      if (msg['role'] == 'user') {
        final text = (msg['parts'][0]['text'] as String).trim();
        if (text.isNotEmpty) {
          return text.length > 25 ? '${text.substring(0, 25)}...' : text;
        }
      }
    }
    return '新對話';
  }
}