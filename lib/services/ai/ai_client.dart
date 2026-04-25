import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/ai_config_model.dart';

class AiClientException implements Exception {
  final int statusCode;
  final String message;
  final String originalBody;

  AiClientException({
    required this.statusCode,
    required this.message,
    this.originalBody = '',
  });

  @override
  String toString() => "AI Client Error ($statusCode): $message";
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  ToolCall({required this.id, required this.name, required this.arguments});

  @override
  String toString() => 'ToolCall(id: $id, name: $name, args: $arguments)';
}

class AiClientResult {
  final String? text;
  final List<ToolCall> toolCalls;
  AiClientResult({this.text, this.toolCalls = const []});

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

class AiStreamChunk {
  final String text;
  AiStreamChunk({required this.text});
}

class AiClient {
  final AiConfig config;

  AiClient({required this.config});

  /// Gemma models don't support thinkingConfig and use thought:true parts instead
  bool get _isGemma => config.model.toLowerCase().contains('gemma');

  Future<AiClientResult> generateContent(
    List<Map<String, dynamic>> history,
    String enrichedPrompt, {
    String? systemInstruction,
    double temperature = 0.7,
    int maxOutputTokens = 32768,
    bool isJsonMode = false,
    List<Map<String, dynamic>>? tools,
  }) async {
    if (config.type == 'google') {
      return _generateGoogle(
        history,
        enrichedPrompt,
        systemInstruction,
        temperature,
        maxOutputTokens,
        isJsonMode,
        tools,
      );
    } else {
      return _generateOpenAi(
        history,
        enrichedPrompt,
        systemInstruction,
        temperature,
        maxOutputTokens,
        isJsonMode,
        tools,
      );
    }
  }

  Stream<AiStreamChunk> generateContentStream(
    List<Map<String, dynamic>> history,
    String enrichedPrompt, {
    String? systemInstruction,
    double temperature = 0.7,
    int maxOutputTokens = 32768,
  }) async* {
    if (config.type == 'google') {
      yield* _generateGoogleStream(
        history,
        enrichedPrompt,
        systemInstruction,
        temperature,
        maxOutputTokens,
      );
    } else {
      yield* _generateOpenAiStream(
        history,
        enrichedPrompt,
        systemInstruction,
        temperature,
        maxOutputTokens,
      );
    }
  }

  Stream<AiStreamChunk> _generateGoogleStream(
    List<Map<String, dynamic>> history,
    String enrichedPrompt,
    String? systemInstruction,
    double temperature,
    int maxOutputTokens,
  ) async* {
    final apiContents = <Map<String, dynamic>>[];

    for (int i = 0; i < history.length; i++) {
      apiContents.add({
        'role': history[i]['role'],
        'parts': [
          {'text': history[i]['parts'][0]['text']},
        ],
      });
    }

    if (history.isEmpty || history.last['parts'][0]['text'] != enrichedPrompt) {
      apiContents.add({
        'role': 'user',
        'parts': [
          {'text': enrichedPrompt},
        ],
      });
    }

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': maxOutputTokens,
    };
    // if (!_isGemma) {
    //   generationConfig['thinkingConfig'] = {'thinkingBudget': 0};
    // }

    final body = {
      'contents': apiContents,
      'generationConfig': generationConfig,
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    };

    if (systemInstruction != null) {
      body['system_instruction'] = {
        'parts': [
          {'text': systemInstruction},
        ],
      };
    }

    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          '${config.effectiveBaseUrl.replaceAll('generateContent', 'streamGenerateContent')}?key=${config.apiKey}',
        ),
      );

      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final response = await client.send(request);

      if (response.statusCode == 200) {
        String buffer = "";
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          buffer += chunk;

          while (buffer.contains('{')) {
            int start = buffer.indexOf('{');
            int braceCount = 0;
            int? end;
            bool insideString = false;
            bool escaped = false;

            for (int i = start; i < buffer.length; i++) {
              String char = buffer[i];
              if (escaped) {
                escaped = false;
                continue;
              }
              if (char == '\\') {
                escaped = true;
              } else if (char == '"') {
                insideString = !insideString;
              } else if (!insideString) {
                if (char == '{') braceCount++;
                if (char == '}') {
                  braceCount--;
                  if (braceCount == 0) {
                    end = i;
                    break;
                  }
                }
              }
            }

            if (end != null) {
              final jsonStr = buffer.substring(start, end + 1);
              buffer = buffer.substring(end + 1);

              try {
                final decoded = jsonDecode(jsonStr);

                final candidates = decoded['candidates'] as List?;
                if (candidates != null && candidates.isNotEmpty) {
                  final firstCandidate = candidates[0];
                  final finishReason = firstCandidate['finishReason'];
                  if (finishReason != null && finishReason != 'STOP') {
                    print("[GoogleStream] 串流提前結束，原因: $finishReason");
                  }

                  final content = firstCandidate['content'];
                  if (content != null && content['parts'] != null) {
                    final parts = content['parts'] as List;
                    for (var part in parts) {
                      // Skip thinking parts (Gemma 4 outputs thought as separate part)
                      if (part['thought'] == true) continue;
                      if (part['text'] != null) {
                        final rawText = part['text'] as String;
                        // 拋光回覆：移除思考標籤與校正斜體
                        final cleaned = _polishResponse(rawText);
                        if (cleaned.isNotEmpty) {
                          yield AiStreamChunk(text: cleaned);
                        }
                      }
                    }
                  }
                }
              } catch (e) {
                print("串流 JSON 解析失敗: $e");
              }
            } else {
              break;
            }
          }
        }
      } else {
        String errorMsg = "Google AI Stream Error (${response.statusCode})";
        try {
          final errorBody = await response.stream.bytesToString();
          final decoded = jsonDecode(errorBody);
          if (decoded['error'] != null && decoded['error']['message'] != null) {
            errorMsg = decoded['error']['message'];
          }
        } catch (_) {}
        throw AiClientException(
          statusCode: response.statusCode,
          message: errorMsg,
        );
      }
    } finally {
      client.close();
    }
  }

  Stream<AiStreamChunk> _generateOpenAiStream(
    List<Map<String, dynamic>> history,
    String enrichedPrompt,
    String? systemInstruction,
    double temperature,
    int maxOutputTokens,
  ) async* {
    final messages = <Map<String, String>>[];

    if (systemInstruction != null) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }

    for (var msg in history) {
      final role = msg['role'] == 'model' ? 'assistant' : 'user';
      messages.add({
        'role': role,
        'content': msg['parts'][0]['text'] as String,
      });
    }

    if (history.isEmpty || history.last['parts'][0]['text'] != enrichedPrompt) {
      messages.add({'role': 'user', 'content': enrichedPrompt});
    }

    final body = {
      'model': config.model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxOutputTokens,
      'stream': true,
    };

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(config.effectiveBaseUrl));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
      request.body = jsonEncode(body);

      final response = await client.send(request);

      if (response.statusCode == 200) {
        await for (final line
            in response.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') break;
            try {
              final decoded = jsonDecode(data);
              final delta = decoded['choices']?[0]?['delta'];
              if (delta != null) {
                final content = delta['content'] as String?;
                if (content != null) yield AiStreamChunk(text: content);
              }
            } catch (e) {
              // Ignore invalid JSON
            }
          }
        }
      } else {
        String errorMsg = "OpenAI Stream Error (${response.statusCode})";
        try {
          final errorBody = await response.stream.bytesToString();
          final decoded = jsonDecode(errorBody);
          if (decoded['error'] != null && decoded['error']['message'] != null) {
            errorMsg = decoded['error']['message'];
          }
        } catch (_) {}
        throw AiClientException(
          statusCode: response.statusCode,
          message: errorMsg,
        );
      }
    } finally {
      client.close();
    }
  }

  Future<AiClientResult> _generateGoogle(
    List<Map<String, dynamic>> history,
    String enrichedPrompt,
    String? systemInstruction,
    double temperature,
    int maxOutputTokens,
    bool isJsonMode,
    List<Map<String, dynamic>>? tools,
  ) async {
    final apiContents = <Map<String, dynamic>>[];

    for (int i = 0; i < history.length; i++) {
      apiContents.add({
        'role': history[i]['role'],
        'parts': [
          {'text': history[i]['parts'][0]['text']},
        ],
      });
    }

    if (history.isEmpty || history.last['parts'][0]['text'] != enrichedPrompt) {
      apiContents.add({
        'role': 'user',
        'parts': [
          {'text': enrichedPrompt},
        ],
      });
    }

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': maxOutputTokens,
      if (isJsonMode) 'responseMimeType': 'application/json',
    };
    // if (!_isGemma) {
    //   generationConfig['thinkingConfig'] = {'thinkingBudget': 0};
    // }

    final body = {
      'contents': apiContents,
      'generationConfig': generationConfig,
      if (tools != null)
        'tools': [
          {'function_declarations': tools.map((t) => t['function']).toList()},
        ],
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    };

    if (systemInstruction != null) {
      body['system_instruction'] = {
        'parts': [
          {'text': systemInstruction},
        ],
      };
    }

    final response = await http
        .post(
          Uri.parse('${config.effectiveBaseUrl}?key=${config.apiKey}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 40));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final firstCandidate = decoded['candidates'][0];
      final content = firstCandidate['content'];
      final parts = content['parts'] as List;

      String? text;
      List<ToolCall> toolCalls = [];

      for (var part in parts) {
        // Skip thinking parts (Gemma 4 outputs thought as separate part)
        if (part['thought'] == true) continue;
        if (part['text'] != null) {
          text = (text ?? '') + part['text'];
        }
        if (part['functionCall'] != null) {
          final fc = part['functionCall'];
          toolCalls.add(
            ToolCall(
              id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
              name: fc['name'],
              arguments: Map<String, dynamic>.from(fc['args'] ?? {}),
            ),
          );
        }
      }

      return AiClientResult(
        text: _polishResponse(text ?? ''),
        toolCalls: toolCalls,
      );
    }

    String errorMsg = "Google AI 服務請求失敗 (${response.statusCode})";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded['error'] != null && decoded['error']['message'] != null) {
        errorMsg = decoded['error']['message'];
      }
    } catch (_) {}

    throw AiClientException(
      statusCode: response.statusCode,
      message: errorMsg,
      originalBody: response.body,
    );
  }

  Future<AiClientResult> _generateOpenAi(
    List<Map<String, dynamic>> history,
    String enrichedPrompt,
    String? systemInstruction,
    double temperature,
    int maxOutputTokens,
    bool isJsonMode,
    List<Map<String, dynamic>>? tools,
  ) async {
    final messages = <Map<String, dynamic>>[];

    if (systemInstruction != null) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }

    for (var msg in history) {
      final role = msg['role'] == 'model' ? 'assistant' : 'user';
      messages.add({
        'role': role,
        'content': msg['parts'][0]['text'] as String,
      });
    }

    if (history.isEmpty || history.last['parts'][0]['text'] != enrichedPrompt) {
      messages.add({'role': 'user', 'content': enrichedPrompt});
    }

    final body = {
      'model': config.model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxOutputTokens,
      if (isJsonMode) 'response_format': {'type': 'json_object'},
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
    };

    final response = await http
        .post(
          Uri.parse(config.effectiveBaseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 50));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final choice = decoded['choices'][0];
      final message = choice['message'];

      // Handle content: can be String, null, or List (some providers use content arrays)
      String? text;
      final content = message['content'];
      if (content is String) {
        text = content;
      } else if (content is List) {
        text = content
            .whereType<Map>()
            .where((p) => p['type'] == 'text')
            .map((p) => p['text']?.toString() ?? '')
            .join();
      }
      List<ToolCall> toolCalls = [];

      if (message['tool_calls'] != null) {
        final calls = message['tool_calls'] as List;
        for (var c in calls) {
          final fn = c['function'];
          toolCalls.add(
            ToolCall(
              id: c['id'],
              name: fn['name'],
              arguments: jsonDecode(fn['arguments']),
            ),
          );
        }
      }

      return AiClientResult(
        text: _polishResponse(text ?? ''),
        toolCalls: toolCalls,
      );
    }

    String errorMsg = "OpenAI 服務請求失敗 (${response.statusCode})";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded['error'] != null && decoded['error']['message'] != null) {
        errorMsg = decoded['error']['message'];
      }
    } catch (_) {}

    throw AiClientException(
      statusCode: response.statusCode,
      message: errorMsg,
      originalBody: response.body,
    );
  }

  Future<List<double>> embedText(String text) async {
    if (config.type == 'google') {
      return _embedGoogle(text);
    } else {
      return _embedOpenAi(text);
    }
  }

  Future<List<double>> _embedGoogle(String text) async {
    final bareModel = config.model.startsWith('models/')
        ? config.model.substring(7)
        : config.model;
    final body = {
      'model': 'models/$bareModel',
      'content': {
        'parts': [
          {'text': text},
        ],
      },
      'taskType': 'RETRIEVAL_QUERY',
      'outputDimensionality': 512,
    };

    final response = await http.post(
      Uri.parse('${config.effectiveEmbeddingUrl}?key=${config.apiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final embedding = decoded['embedding']['values'] as List;
      return embedding.cast<double>();
    }

    throw AiClientException(
      statusCode: response.statusCode,
      message: "Google Embedding Error: ${response.body}",
    );
  }

  Future<List<double>> _embedOpenAi(String text) async {
    final body = {'model': config.model, 'input': text, 'dimensions': 512};

    final response = await http.post(
      Uri.parse(config.effectiveEmbeddingUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final embedding = decoded['data'][0]['embedding'] as List;
      return embedding.cast<double>();
    }

    throw AiClientException(
      statusCode: response.statusCode,
      message: "OpenAI Embedding Error: ${response.body}",
    );
  }

  String _polishResponse(String input) {
    if (input.isEmpty) return '';

    // 1. 移除 Gemma 4 思考格式: <|channel>thought\n...\n<channel>
    final gemmaThinkRegex = RegExp(
      r'<\|channel>thought.*?<channel\|>',
      dotAll: true,
    );
    // 2. 移除 <thought>...</thought> 標籤及其中間的內容
    final thoughtRegex = RegExp(
      r'<thought>.*?</thought>',
      dotAll: true,
      caseSensitive: false,
    );
    final reasoningRegex = RegExp(
      r'\[reasoning\].*?\[/reasoning\]',
      dotAll: true,
      caseSensitive: false,
    );

    String result = input
        .replaceAll(gemmaThinkRegex, '')
        .replaceAll(thoughtRegex, '')
        .replaceAll(reasoningRegex, '');

    // 3. 移除殘餘的標籤開頭
    result = result.replaceAll(
      RegExp(r'<thought.*?>', caseSensitive: false),
      '',
    );
    result = result.replaceAll(RegExp(r'</thought>', caseSensitive: false), '');

    // 3. 校正斜體 (Italics) -> 轉為純文字
    // 匹配 *text* 但排除 **text** (粗體)
    result = result.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'),
      (match) => match.group(1)!,
    );
    // 匹配 _text_ 但排除 __text__ (粗體)
    result = result.replaceAllMapped(
      RegExp(r'(?<!_)\_([^_]+)\_(?!\_)'),
      (match) => match.group(1)!,
    );

    return result.trim();
  }
}
