import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/open_score_service.dart';
import '../theme/app_theme.dart';

class OpenScorePage extends StatelessWidget {

  const OpenScorePage({
    Key? key,
  }) : super(key: key);

  /// 建立右側狀態顯示區塊 (總分或查無資料)
  Widget _buildTrailingWidget(
    BuildContext context,
    List<Map<String, String>> scores,
  ) {
    if (scores.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.isDark
              ? Colors.orange[900]?.withOpacity(0.3)
              : Colors.orange[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.isDark
                ? Colors.orange[700]!
                : Colors.orange.shade200,
          ),
        ),
        child: Text(
          "無資料",
          style: TextStyle(
            color: Theme.of(context).colorScheme.isDark
                ? Colors.orange[200]
                : Colors.deepOrange[700],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    final totalScoreEntry = scores.firstWhere(
      (s) =>
          (s['item'] ?? "").contains("總成績") ||
          (s['item'] ?? "").contains("原始總成績"),
      orElse: () => {},
    );

    if (totalScoreEntry.isEmpty) {
      return const Icon(Icons.expand_more, size: 18);
    }

    final String scoreText = totalScoreEntry['raw_score'] ?? "-";
    final double? scoreValue = double.tryParse(scoreText);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          scoreText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: (scoreValue ?? 0) < 60
                ? Colors.red
                : (Theme.of(context).colorScheme.isDark
                      ? Colors.green[200]
                      : Colors.green[800]),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.expand_more,
          color: Theme.of(context).colorScheme.subtitleText,
          size: 18,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: null,
      body: Column(
        children: [
          // 1. 自定義桌面標題列 (更輕量化)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 10,
                  right: 20,
                  top: 25,
                  bottom: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                          ),
                          onPressed: () => context.go('/home'),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "開放成績查詢",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primaryText,
                          ),
                        ),
                      ],
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          OpenScoreService.instance.isLoadingNotifier,
                      builder: (context, isLoading, child) {
                        return _buildRefreshButton(context, isLoading);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. 頁面說明小提醒 (更精簡)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer
                        .withOpacity(
                          Theme.of(context).colorScheme.isDark ? 0.3 : 1.0,
                        ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        color: Theme.of(context).colorScheme.accentBlue,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "此頁面成績為系統即時抓取，尚未經過最終核算與排名，僅供本學期修課進度參考。",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "本功能僅在每年 5/15~6/15 及 12/15~1/15 自動更新，其餘期間若有需要請手動更新。",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.subtitleText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. 進度條區塊
          ValueListenableBuilder<bool>(
            valueListenable: OpenScoreService.instance.isLoadingNotifier,
            builder: (context, isLoading, child) {
              if (!isLoading) return const SizedBox.shrink();
              return ValueListenableBuilder<double>(
                valueListenable: OpenScoreService.instance.progressNotifier,
                builder: (ctx, progress, _) => LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryCardBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.accentBlue,
                  ),
                ),
              );
            },
          ),

          // 4. 資料列表區塊
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: OpenScoreService.instance.resultsNotifier,
                  builder: (context, results, child) {
                    bool isLoading =
                        OpenScoreService.instance.isLoadingNotifier.value;

                    if (results.isEmpty) {
                      return Center(
                        child: isLoading
                            ? const SizedBox.shrink()
                            : Text(
                                "目前沒有成績資料\n請嘗試點擊重新整理按鈕",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.subtitleText,
                                  fontSize: 14,
                                ),
                              ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final courseData = results[index];
                        final scores = (courseData['scores'] as List)
                            .map((item) => Map<String, String>.from(item))
                            .toList();

                        bool isHovered = false;
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return MouseRegion(
                              onEnter: (_) => setState(() => isHovered = true),
                              onExit: (_) => setState(() => isHovered = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: colorScheme.cardBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isHovered
                                        ? Colors.blue.withOpacity(0.6)
                                        : colorScheme.borderColor,
                                    width: isHovered ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isHovered
                                      ? [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(
                                              0.15,
                                            ),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ExpansionTile(
                                    initiallyExpanded: false,
                                    backgroundColor: colorScheme.cardBackground,
                                    collapsedBackgroundColor:
                                        colorScheme.cardBackground,
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.secondaryCardBackground,
                                      child: Icon(
                                        Icons.book_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.accentBlue,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      courseData['course_name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryText,
                                      ),
                                    ),
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ),
                                    trailing: _buildTrailingWidget(
                                      context,
                                      scores,
                                    ),
                                    children: [
                                      if (scores.isNotEmpty) ...[
                                        Container(
                                          color: colorScheme
                                              .secondaryCardBackground,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  "評分項目",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primaryText,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  "比例",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.subtitleText,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  "得分",
                                                  textAlign: TextAlign.end,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primaryText,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        ...scores.map((scoreItem) {
                                          bool isTotal =
                                              (scoreItem['item'] ?? "")
                                                  .contains("總成績");

                                          return Container(
                                            color: isTotal
                                                ? Theme.of(
                                                        context,
                                                      ).colorScheme.isDark
                                                      ? Colors.yellow[900]
                                                            ?.withOpacity(0.1)
                                                      : Colors.yellow
                                                            .withOpacity(0.04)
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.cardBackground,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 16.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        scoreItem['item'] ?? "",
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: isTotal
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primaryText,
                                                        ),
                                                      ),
                                                      if ((scoreItem['note'] ??
                                                              "")
                                                          .isNotEmpty)
                                                        Text(
                                                          scoreItem['note']!,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .subtitleText,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    scoreItem['percentage'] ??
                                                        "",
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .subtitleText,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    scoreItem['raw_score'] ??
                                                        "-",
                                                    textAlign: TextAlign.end,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          (double.tryParse(
                                                                    scoreItem['raw_score'] ??
                                                                        "0",
                                                                  ) ??
                                                                  0) <
                                                              60
                                                          ? Colors.red
                                                          : (Theme.of(context)
                                                                    .colorScheme
                                                                    .isDark
                                                                ? Colors
                                                                      .green[200]
                                                                : Colors
                                                                      .green[800]),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ] else
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            "此課程尚無詳細評分明細",
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.subtitleText,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ✅ 新增：更精簡的刷新按鈕
  Widget _buildRefreshButton(BuildContext context, bool isLoading) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isLoading
          ? null
          : () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              OpenScoreService.instance.fetchOpenScores();
            },
      mouseCursor: isLoading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.borderColor),
        ),
        child: Row(
          children: [
            isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: colorScheme.accentBlue,
                  ),
            const SizedBox(width: 6),
            Text(
              isLoading ? "同步中" : "重新整理",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
