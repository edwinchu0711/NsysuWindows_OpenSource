import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/ai/ai_service.dart';
import '../../../services/local_course_service.dart';
import '../../../services/database_embedding_service.dart';
import '../../../theme/app_theme.dart';
import '../../../models/ai_config_model.dart';
import '../../../models/chat_conversation.dart';
import '../../settings_page.dart';

enum _MissingItem { courseDb, databaseDb, llmApi, embeddingApi }

extension _MissingItemInfo on _MissingItem {
  String get title => switch (this) {
    _MissingItem.courseDb => '課程資料庫 (courses.db)',
    _MissingItem.databaseDb => '評價資料庫 (database.db)',
    _MissingItem.llmApi => 'LLM API 金鑰',
    _MissingItem.embeddingApi => 'Embedding API 金鑰',
  };

  String get description => switch (this) {
    _MissingItem.courseDb => '請至「設定 > 資料庫」下載課程資料庫',
    _MissingItem.databaseDb => '請至「設定 > 資料庫」下載評價資料庫',
    _MissingItem.llmApi => '請至「設定」配置 Google Gemini 或 OpenAI API Key',
    _MissingItem.embeddingApi => '請至「設定 > Embedding」配置 Embedding API Key',
  };
}

class AssistantAiPane extends StatefulWidget {
  final AiService? aiService;
  final List<AiConfig> aiConfigs;
  final String? selectedConfigId;
  final Function(AiConfig)? onConfigChanged;
  final VoidCallback? onRefreshRequested;
  final bool hasEmbeddingApiKey;

  const AssistantAiPane({
    Key? key,
    this.aiService,
    required this.aiConfigs,
    this.selectedConfigId,
    this.onConfigChanged,
    this.onRefreshRequested,
    this.hasEmbeddingApiKey = false,
  }) : super(key: key);

  @override
  State<AssistantAiPane> createState() => _AssistantAiPaneState();
}

class _AssistantAiPaneState extends State<AssistantAiPane> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isStreaming = false; // true once AI starts sending content
  String _statusText = "AI 正在思考中";

  // Chat conversation persistence
  List<ChatConversation> _conversations = [];
  String? _currentConversationId;
  bool _showSidebar = false;
  String _conversationTitle = "AI 助手";

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  List<_MissingItem> _checkReadiness() {
    final missing = <_MissingItem>[];

    if (!LocalCourseService.instance.isInitialized) {
      missing.add(_MissingItem.courseDb);
    }
    if (!DatabaseEmbeddingService.instance.isInitialized) {
      missing.add(_MissingItem.databaseDb);
    }

    final hasLlmKey =
        widget.aiConfigs.isNotEmpty &&
        widget.aiConfigs
            .firstWhere(
              (c) => c.id == widget.selectedConfigId,
              orElse: () => widget.aiConfigs.first,
            )
            .apiKey
            .isNotEmpty;
    if (!hasLlmKey) {
      missing.add(_MissingItem.llmApi);
    }

    if (!widget.hasEmbeddingApiKey) {
      missing.add(_MissingItem.embeddingApi);
    }

    return missing;
  }

  Future<void> _loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('ai_chat_conversations') ?? '';
      setState(() {
        _conversations = ChatConversation.decode(json);
      });
    } catch (e) {
      print("Load conversations error: $e");
    }
  }

  Future<void> _saveConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only last 20 conversations
      if (_conversations.length > 20) {
        _conversations = _conversations.sublist(_conversations.length - 20);
      }
      await prefs.setString(
        'ai_chat_conversations',
        ChatConversation.encode(_conversations),
      );
    } catch (e) {
      print("Save conversations error: $e");
    }
  }

  void _saveCurrentConversation() {
    if (widget.aiService == null) return;
    final history = widget.aiService!.history;
    if (history.isEmpty) return;

    final now = DateTime.now();
    final configId = widget.selectedConfigId ?? '';

    if (_currentConversationId != null) {
      // Update existing conversation
      final idx = _conversations.indexWhere(
        (c) => c.id == _currentConversationId,
      );
      if (idx >= 0) {
        _conversations[idx].title = _conversationTitle;
        _conversations[idx].messages = List<Map<String, dynamic>>.from(history);
        _conversations[idx].updatedAt = now;
      } else {
        // ID not found, create new
        _currentConversationId = DateTime.now().millisecondsSinceEpoch
            .toString();
        _conversations.insert(
          0,
          ChatConversation(
            id: _currentConversationId!,
            title: _conversationTitle,
            messages: List<Map<String, dynamic>>.from(history),
            createdAt: now,
            updatedAt: now,
            configId: configId,
          ),
        );
      }
    } else {
      // New conversation
      _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
      _conversations.insert(
        0,
        ChatConversation(
          id: _currentConversationId!,
          title: _conversationTitle,
          messages: List<Map<String, dynamic>>.from(history),
          createdAt: now,
          updatedAt: now,
          configId: configId,
        ),
      );
    }

    _saveConversations();
  }

  void _loadConversation(ChatConversation conv) {
    if (widget.aiService == null) return;
    widget.aiService!.clearHistory();
    widget.aiService!.history.addAll(conv.messages);
    setState(() {
      _currentConversationId = conv.id;
      _conversationTitle = conv.title;
    });
    _scrollToBottom();
  }

  void _deleteConversation(String id) {
    setState(() {
      _conversations.removeWhere((c) => c.id == id);
      if (_currentConversationId == id) {
        _currentConversationId = null;
      }
    });
    _saveConversations();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;

    final isFirstMessage = widget.aiService?.history.isEmpty ?? true;

    setState(() {
      _isTyping = true;
      _isStreaming = false;
      _statusText = "AI 正在思考中...";
      _controller.clear();
    });
    _scrollToBottom();

    try {
      if (widget.aiService == null) return;

      final responseStream = widget.aiService!.sendMessageStream(
        text,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _statusText = status;
            });
          }
        },
      );

      await for (final response in responseStream) {
        if (mounted) {
          if (response.needsRefresh) {
            widget.onRefreshRequested?.call();
          }
          // Once AI starts streaming content, hide the typing indicator
          if (!_isStreaming) {
            _isStreaming = true;
          }
          setState(() {});
          _scrollToBottom();
        }
      }
    } catch (e) {
      print("Sending Error: $e");
    }

    if (mounted) {
      setState(() {
        _isTyping = false;
        _isStreaming = false;
      });
      _scrollToBottom();
      _saveCurrentConversation();

      // Generate LLM title after first exchange
      if (isFirstMessage && widget.aiService != null) {
        final history = widget.aiService!.history;
        if (history.length >= 2) {
          final userText = history[0]['parts'][0]['text'] as String;
          final assistantText = history[1]['parts'][0]['text'] as String;
          widget.aiService!.generateTitle(userText, assistantText).then((
            title,
          ) {
            if (mounted) {
              setState(() {
                _conversationTitle = title;
              });
              _saveCurrentConversation();
            }
          });
        }
      }
    }
  }

  void _handleClear() {
    // Save current conversation before starting new one
    _saveCurrentConversation();
    setState(() {
      widget.aiService?.clearHistory();
      _currentConversationId = null;
      _conversationTitle = "AI 助手";
    });
  }

  void _showAiAssistantInfo() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.accentBlue),
              const SizedBox(width: 12),
              const Text("AI 助手使用指南"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "這是什麼？",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "這是一個具備「工具使用能力」的 AI 助理。它不僅能聊天，還能實際操作您的課表、搜尋歷史評價並進行簡單的排課分析。",
                ),
                const SizedBox(height: 24),
                Text(
                  "💡 如何下指令",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.accentBlue,
                  ),
                ),
                const Divider(),
                const Text("建議將複雜指令拆分為多個簡單指令，以獲得更準確的結果。"),
                const SizedBox(height: 8),
                const Text(
                  "❌ 避免複雜指令：",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text(
                  "「幫我看星期二下午有沒有評價不錯的游泳課，若是有的話幫我加進課表，沒有的話推薦我那段期間的博雅向度五課。」",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  "✅ 建議拆分為：",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text(
                  "1.「星期二下午有游泳課嗎？評價如何？」\n2.「推薦我那段時間的博雅向度五課程」",
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 24),
                Text(
                  "⚡ 影響反應速度的因素",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.accentBlue,
                  ),
                ),
                const Divider(),
                const Text("回覆速度受以下兩個主要因素影響："),
                const SizedBox(height: 8),
                const Text(
                  "• 請求時段：",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text(
                  "尖峰時段，AI 回覆速度會變慢，甚至無法使用。\n離峰時段，AI 回覆速度會變快。\n建議離峰時段使用。",
                ),
                const SizedBox(height: 8),
                const Text(
                  "• 指令複雜度：",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text("指令越模糊或需要處理的數據量越大（如：分析全校跨領域課程），AI 思考的時間也會隨之增加。"),
                const SizedBox(height: 8),
                const Text(
                  "• 模型效能：",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text(
                  "高品質大型模型（如 Pro 等級）回答較精準但速度較慢；輕量化模型（如 Flash）則能提供幾乎即時的反應。",
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("知道了"),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inHours < 1) return '${diff.inMinutes}分鐘前';
    if (diff.inDays < 1) return '${diff.inHours}小時前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Unified readiness check
    final missingItems = _checkReadiness();
    if (missingItems.isNotEmpty) {
      return _buildNotReadyState(colorScheme, missingItems);
    }

    final history = widget.aiService?.history ?? [];

    return Container(
      color: Colors.transparent,
      child: ClipRect(
        child: Stack(
          children: [
            // Main chat area (always present)
            Column(
              children: [
                // 頂部標題與清空按鈕
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.headerBackground,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.borderColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 500;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.menu_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _showSidebar = !_showSidebar,
                                  ),
                                  tooltip: "對話歷史",
                                  color: colorScheme.subtitleText,
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.auto_awesome,
                                  size: 18,
                                  color: colorScheme.accentBlue,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _conversationTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primaryText,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                  ),
                                  onPressed: _showAiAssistantInfo,
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  color: colorScheme.subtitleText,
                                  tooltip: "使用說明",
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.aiConfigs.isNotEmpty)
                                _buildModelSelector(
                                  colorScheme,
                                  isNarrow: isNarrow,
                                ),
                              const SizedBox(width: 8),
                              if (isNarrow)
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_comment_rounded,
                                    size: 18,
                                  ),
                                  color: colorScheme.accentBlue,
                                  onPressed: _handleClear,
                                  tooltip: "新對話",
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                )
                              else
                                TextButton.icon(
                                  onPressed: _handleClear,
                                  icon: const Icon(
                                    Icons.add_comment_rounded,
                                    size: 18,
                                  ),
                                  label: const Text("新對話"),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colorScheme.accentBlue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 聊天內容區
                Expanded(
                  child: history.isEmpty
                      ? _buildEmptyState(colorScheme)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          // Show typing indicator only while waiting (not yet streaming)
                          itemCount:
                              history.length +
                              (_isTyping && !_isStreaming ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == history.length) {
                              return _buildTypingIndicator(colorScheme);
                            }
                            final msg = history[index];
                            final isUser = msg["role"] == "user";
                            final text = msg["parts"][0]["text"];

                            // Show trailing animation on the last AI bubble while streaming
                            final isLastAiBubble =
                                !isUser &&
                                index == history.length - 1 &&
                                _isTyping &&
                                _isStreaming;
                            return _buildMessageBubble(
                              text,
                              isUser,
                              colorScheme,
                              showStreamingCursor: isLastAiBubble,
                            );
                          },
                        ),
                ),

                // 輸入區
                _buildInputArea(colorScheme),
              ],
            ),

            // ── Overlay: dark backdrop + sliding sidebar ──
            // Semi-transparent black overlay — blocks interaction with chat
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showSidebar,
                child: GestureDetector(
                  onTap: () => setState(() => _showSidebar = false),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    opacity: _showSidebar ? 1.0 : 0.0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            // Sliding sidebar panel (slides in from left)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 280,
              child: AnimatedSlide(
                offset: _showSidebar ? Offset.zero : const Offset(-1, 0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.headerBackground,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.borderColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: _buildSidebarContent(colorScheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarContent(ColorScheme colorScheme) {
    return Column(
      children: [
        // Sidebar header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "對話歷史",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showSidebar = false),
                splashRadius: 18,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                color: colorScheme.subtitleText,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Conversation list
        Expanded(
          child: _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 40,
                        color: colorScheme.iconColor.withOpacity(0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "還沒有歷史對話",
                        style: TextStyle(
                          color: colorScheme.subtitleText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isCurrent = conv.id == _currentConversationId;
                    final timeStr = _formatDate(conv.updatedAt);
                    return _ConversationTile(
                      conversation: conv,
                      isCurrent: isCurrent,
                      timeStr: timeStr,
                      colorScheme: colorScheme,
                      onTap: () => _loadConversation(conv),
                      onDelete: () => _deleteConversation(conv.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    if (widget.aiService == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: colorScheme.iconColor.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              "請在上方選擇一個 AI 模型開始對話",
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.subtitleText),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing AI icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1.05),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              onEnd: () => setState(() {}), // repeat the pulse
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.accentBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.accentBlue.withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 36,
                  color: colorScheme.accentBlue,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title with fade-in
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: Text(
                "有什麼關於課程的問題嗎？",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: Text(
                "問問我吧！",
                style: TextStyle(fontSize: 15, color: colorScheme.subtitleText),
              ),
            ),
            const SizedBox(height: 32),
            // Quick action chips with staggered fade-in
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickActionChip(
                    "推薦博雅涼課",
                    Icons.thumb_up_outlined,
                    colorScheme,
                  ),
                  _buildQuickActionChip(
                    "查看目前課表",
                    Icons.table_chart_outlined,
                    colorScheme,
                  ),
                  _buildQuickActionChip(
                    "你可以做什麼？",
                    Icons.help_outline_rounded,
                    colorScheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "AI 可能產生不正確的資訊，請以學校官方資料為準",
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.subtitleText.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(
    String label,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return ActionChip(
      onPressed: () => _handleSend(label),
      avatar: Icon(icon, size: 16, color: colorScheme.accentBlue),
      label: Text(
        label,
        style: TextStyle(fontSize: 13, color: colorScheme.primaryText),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.borderColor, width: 0.8),
      ),
      backgroundColor: colorScheme.secondaryCardBackground,
    );
  }

  Widget _buildNotReadyState(
    ColorScheme colorScheme,
    List<_MissingItem> missingItems,
  ) {
    final allItems = _MissingItem.values;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: colorScheme.iconColor.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            Text(
              "AI 助手尚未就緒",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "請完成以下設定後再使用 AI 助手",
              style: TextStyle(fontSize: 14, color: colorScheme.subtitleText),
            ),
            const SizedBox(height: 24),
            // Checklist of all 4 items
            Container(
              decoration: BoxDecoration(
                color: colorScheme.secondaryCardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.borderColor, width: 0.8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: allItems.map((item) {
                  final isMissing = missingItems.contains(item);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMissing
                              ? Icons.cancel_outlined
                              : Icons.check_circle_rounded,
                          size: 20,
                          color: isMissing ? Colors.redAccent : Colors.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: colorScheme.primaryText,
                                ),
                              ),
                              if (isMissing) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.subtitleText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
                // Refresh parent state (reloads configs, DB status, etc.)
                widget.onRefreshRequested?.call();
              },
              icon: const Icon(Icons.settings_rounded),
              label: const Text("前往設定"),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector(ColorScheme colorScheme, {bool isNarrow = false}) {
    String selectedName = "選擇模型";
    String selectedType = "";
    if (widget.selectedConfigId != null && widget.aiConfigs.isNotEmpty) {
      try {
        final config = widget.aiConfigs.firstWhere(
          (c) => c.id == widget.selectedConfigId,
        );
        selectedName = config.name;
        selectedType = config.type;
      } catch (e) {
        // Not found, ignored
      }
    }

    return PopupMenuButton<String>(
      tooltip: "選擇 AI 模型",
      offset: const Offset(0, 40),
      color: colorScheme.headerBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      padding: EdgeInsets.zero,
      onSelected: (String id) {
        final config = widget.aiConfigs.firstWhere((c) => c.id == id);
        widget.onConfigChanged?.call(config);
      },
      child: Container(
        height: 32,
        width: isNarrow ? 32 : null,
        padding: isNarrow
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.borderColor, width: 0.5),
        ),
        alignment: isNarrow ? Alignment.center : null,
        child: isNarrow
            ? Icon(
                selectedType == 'google'
                    ? Icons.auto_awesome
                    : selectedType.isEmpty
                    ? Icons.model_training
                    : Icons.api_rounded,
                size: 16,
                color: colorScheme.accentBlue,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedType == 'google'
                        ? Icons.auto_awesome
                        : selectedType.isEmpty
                        ? Icons.model_training
                        : Icons.api_rounded,
                    size: 14,
                    color: colorScheme.accentBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedName,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colorScheme.subtitleText,
                  ),
                ],
              ),
      ),
      itemBuilder: (context) {
        return widget.aiConfigs.map((config) {
          final isSelected = config.id == widget.selectedConfigId;
          return PopupMenuItem<String>(
            value: config.id,
            padding: EdgeInsets.zero,
            height: 48,
            child: _ModelSelectorHoverItem(
              config: config,
              isSelected: isSelected,
              colorScheme: colorScheme,
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildMessageBubble(
    String text,
    bool isUser,
    ColorScheme colorScheme, {
    bool showStreamingCursor = false,
  }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final markdownStyleSheet = MarkdownStyleSheet(
      p: TextStyle(color: colorScheme.primaryText, fontSize: 14, height: 1.5),
      h1: TextStyle(
        color: colorScheme.primaryText,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2: TextStyle(
        color: colorScheme.primaryText,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h3: TextStyle(
        color: colorScheme.primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h4: TextStyle(
        color: colorScheme.primaryText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h5: TextStyle(
        color: colorScheme.primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h6: TextStyle(
        color: colorScheme.primaryText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      code: TextStyle(
        backgroundColor: colorScheme.pageBackground,
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      tableBody: TextStyle(color: colorScheme.primaryText, fontSize: 13),
      blockquoteDecoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4.0),
      ),
      listBullet: TextStyle(color: colorScheme.primaryText, fontSize: 14),
      listBulletPadding: const EdgeInsets.only(right: 8),
    );

    final Widget aiContent;
    if (showStreamingCursor) {
      // During streaming: render completed lines as markdown,
      // and the in-progress line as plain text to avoid broken markdown syntax
      if (text.contains('\n')) {
        final lastNewline = text.lastIndexOf('\n');
        final finishedText = text.substring(0, lastNewline + 1);
        final streamingLine = text.substring(lastNewline + 1);
        aiContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MarkdownBody(
              data: _preprocessMarkdown(finishedText),
              selectable: true,
              styleSheet: markdownStyleSheet,
            ),
            SelectableText(
              streamingLine,
              style: TextStyle(
                color: colorScheme.primaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        );
      } else {
        // Single line still streaming — show as plain text
        aiContent = SelectableText(
          text,
          style: TextStyle(
            color: colorScheme.primaryText,
            fontSize: 14,
            height: 1.5,
          ),
        );
      }
    } else {
      // Streaming complete — render full markdown
      aiContent = MarkdownBody(
        data: _preprocessMarkdown(text),
        selectable: true,
        styleSheet: markdownStyleSheet,
      );
    }

    final bubbleContent = isUser
        ? SelectableText(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              aiContent,
              if (showStreamingCursor)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildAnimatedDots(colorScheme),
                ),
            ],
          );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      decoration: BoxDecoration(
        color: isUser
            ? colorScheme.accentBlue
            : colorScheme.secondaryCardBackground,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: isUser
            ? null
            : Border.all(
                color: colorScheme.borderColor.withValues(
                  alpha: colorScheme.isDark ? 0.3 : 0.8,
                ),
                width: 0.8,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: colorScheme.isDark ? 0.15 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: bubbleContent,
    );

    // Reserve avatar column width (28 avatar + 8 spacing = 36) on BOTH sides
    // so bubbles never extend into the other person's avatar vertical range
    return Padding(
      padding: EdgeInsets.only(
        left: isUser
            ? 36.0
            : 0.0, // user bubbles: leave space for AI avatar column
        right: isUser
            ? 0.0
            : 36.0, // AI bubbles: leave space for user avatar column
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _buildAvatar(
                  Icons.auto_awesome,
                  colorScheme.accentBlue,
                  colorScheme,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: bubble),
              if (isUser) ...[
                const SizedBox(width: 8),
                _buildAvatar(Icons.person, colorScheme.accentBlue, colorScheme),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Preprocess markdown text to fix common LLM formatting issues:
  /// Single newlines between non-block lines → double newlines (paragraph breaks),
  /// because standard markdown treats single \n as a space.
  static String _preprocessMarkdown(String text) {
    final lines = text.split('\n');
    if (lines.length <= 1) return text;

    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      buffer.write(lines[i]);
      if (i < lines.length - 1) {
        final currentBlank = lines[i].trim().isEmpty;
        final nextBlank = lines[i + 1].trim().isEmpty;
        final currentIsBlock = !currentBlank && _isBlockLine(lines[i]);
        final nextIsBlock = !nextBlank && _isBlockLine(lines[i + 1]);

        if (currentBlank || nextBlank) {
          buffer.write('\n');
        } else if (currentIsBlock && nextIsBlock) {
          // Between two block elements, single newline is fine
          buffer.write('\n');
        } else {
          // block→non-block or non-block→block or non-block→non-block
          // all need paragraph break for clean separation
          buffer.write('\n\n');
        }
      }
    }
    return buffer.toString();
  }

  static bool _isBlockLine(String line) {
    final t = line.trimLeft();
    return t.startsWith('#') ||
        t.startsWith('- ') ||
        t.startsWith('-\t') ||
        t.startsWith('* ') ||
        t.startsWith('*\t') ||
        t.startsWith('> ') ||
        t.startsWith('```') ||
        RegExp(r'^\d+[.)] ').hasMatch(t);
  }

  Widget _buildAvatar(IconData icon, Color color, ColorScheme colorScheme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 36.0, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(Icons.auto_awesome, colorScheme.accentBlue, colorScheme),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.secondaryCardBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: colorScheme.borderColor.withOpacity(
                  colorScheme.isDark ? 0.3 : 0.8,
                ),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    colorScheme.isDark ? 0.15 : 0.06,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusText,
                  style: TextStyle(
                    color: colorScheme.subtitleText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 10),
                _buildAnimatedDots(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots(ColorScheme colorScheme) {
    return _AnimatedTypingDots(color: colorScheme.accentBlue);
  }

  Widget _buildInputArea(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.headerBackground,
        border: Border(
          top: BorderSide(color: colorScheme.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _handleSend(),
              style: TextStyle(color: colorScheme.primaryText),
              decoration: InputDecoration(
                hintText: "請輸入您的問題...",
                hintStyle: TextStyle(color: colorScheme.subtitleText),
                filled: true,
                fillColor: colorScheme.pageBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: colorScheme.accentBlue,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _handleSend,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conversation tile with hover animation for sidebar
class _ConversationTile extends StatefulWidget {
  final ChatConversation conversation;
  final bool isCurrent;
  final String timeStr;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.isCurrent,
    required this.timeStr,
    required this.colorScheme,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final conv = widget.conversation;
    final isCurrent = widget.isCurrent;

    final glowColor = isCurrent ? cs.accentBlue : cs.accentBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrent
                    ? cs.accentBlue.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isCurrent
                    ? Border.all(color: cs.accentBlue.withValues(alpha: 0.3))
                    : _isHovered
                    ? Border.all(color: glowColor.withValues(alpha: 0.35))
                    : null,
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isCurrent ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      key: ValueKey(isCurrent),
                      size: 18,
                      color: isCurrent ? cs.accentBlue : cs.subtitleText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isCurrent ? cs.accentBlue : cs.primaryText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${widget.timeStr} · ${conv.messages.length} 則",
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.subtitleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete button
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: (_isHovered || isCurrent) ? 1.0 : 0.0,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: cs.subtitleText,
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        onPressed: widget.onDelete,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated three-dot typing indicator
class _AnimatedTypingDots extends StatefulWidget {
  final Color color;
  const _AnimatedTypingDots({required this.color});

  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Stagger each dot's animation
              final double t = (_controller.value * 3 - i) % 1.0;
              final double scale = t < 0.5
                  ? 0.5 +
                        t *
                            1.0 // grow from 0.5 to 1.0
                  : 1.5 - t; // shrink from 1.0 to 0.5
              return Transform.scale(
                scale: scale.clamp(0.5, 1.2),
                child: child,
              );
            },
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Animated model selector hover item
class _ModelSelectorHoverItem extends StatefulWidget {
  final AiConfig config;
  final bool isSelected;
  final ColorScheme colorScheme;

  const _ModelSelectorHoverItem({
    required this.config,
    required this.isSelected,
    required this.colorScheme,
  });

  @override
  State<_ModelSelectorHoverItem> createState() =>
      _ModelSelectorHoverItemState();
}

class _ModelSelectorHoverItemState extends State<_ModelSelectorHoverItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.accentBlue.withValues(alpha: 0.1)
              : (_isHovered
                    ? cs.accentBlue.withValues(alpha: 0.05)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: _isHovered || isSelected
              ? Border.all(color: cs.accentBlue.withValues(alpha: 0.3))
              : Border.all(color: Colors.transparent),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: cs.accentBlue.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              widget.config.type == 'google'
                  ? Icons.auto_awesome
                  : Icons.api_rounded,
              size: 16,
              color: isSelected || _isHovered ? cs.accentBlue : cs.subtitleText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.config.name,
                style: TextStyle(
                  color: isSelected || _isHovered
                      ? cs.primaryText
                      : cs.subtitleText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: cs.accentBlue),
          ],
        ),
      ),
    );
  }
}
