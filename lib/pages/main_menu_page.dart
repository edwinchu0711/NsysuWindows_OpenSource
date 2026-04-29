/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';

// Service Import
import '../services/open_score_service.dart';
import '../services/course_query_service.dart';

// ViewModel Import
import '../viewmodels/main_menu_viewmodel.dart';

import '../theme/app_theme.dart';

class MainMenuPage extends ConsumerStatefulWidget {
  const MainMenuPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends ConsumerState<MainMenuPage> {
  final ValueNotifier<double> _fakeProgressNotifier = ValueNotifier(0.0);

  // --- 滑動控制器 ---
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    // 初始化 ScrollController
    _scrollController = ScrollController();

    // 非同步執行，印出路徑供調試
    getApplicationSupportDirectory().then((supportDir) {
      print('我的設定檔就藏在: ${supportDir.path}');
    });

    OpenScoreService.instance.statusMessageNotifier.addListener(
      _handleSessionExpiry,
    );
    _checkAndStartTasks();
    _checkNewVersion();

    // SSO 登入後觸發課程資料更新 + courses.db 建立
    CourseQueryService.instance.checkForUpdate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    OpenScoreService.instance.statusMessageNotifier.removeListener(
      _handleSessionExpiry,
    );
    super.dispose();
  }

  Future<void> _checkAndStartTasks() async {
    final viewModel = ref.read(mainMenuViewModelProvider.notifier);
    await viewModel.checkAndStartTasks();
    // If first time loading, run progress animation
    if (ref.read(mainMenuViewModelProvider).isFirstTimeLoading) {
      await _runRealisticLoading();
    }
  }

  Future<void> _runRealisticLoading() async {
    _fakeProgressNotifier.value = 0.0;
    await Future.delayed(const Duration(milliseconds: 1700));

    double currentProgress = 0.0;
    Random rng = Random();

    while (currentProgress < 1.0) {
      if (!mounted) return;

      double increment = 0.0;
      if (rng.nextDouble() > 0.8) {
        increment = 0.05 + rng.nextDouble() * 0.06;
      } else {
        increment = 0.005 + rng.nextDouble() * 0.016;
      }

      currentProgress += increment;
      if (currentProgress >= 1.0) currentProgress = 1.0;

      _fakeProgressNotifier.value = currentProgress;

      int delayMs = 50 + rng.nextInt(150);
      if (currentProgress > 0.9 && currentProgress < 1.0) {
        delayMs += 130;
      }

      await Future.delayed(Duration(milliseconds: delayMs));
    }

    await Future.delayed(const Duration(milliseconds: 2200));

    if (mounted) {
      ref.read(mainMenuViewModelProvider.notifier).setLoadingComplete();
    }
  }

  Future<void> _checkNewVersion() async {
    // 依據要求捨去版本檢查顯示邏輯
  }

  void _handleSessionExpiry() {
    final msg = OpenScoreService.instance.statusMessageNotifier.value;
    if (msg == "Session失效" || msg == "Session Timeout") {
      _navigateToLogin(isRelogin: true);
    }
  }

  void _navigateToLogin({bool isRelogin = false}) {
    if (!mounted) return;
    context.go(isRelogin ? '/?relogin=true' : '/');
  }

  Future<void> _logout() async {
    await ref.read(mainMenuViewModelProvider.notifier).logout();

    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 900;

    int gridCount;
    double gridRatio;
    if (screenWidth > 1200) {
      gridCount = 4;
      gridRatio = 2.4;
    } else if (screenWidth > 900) {
      gridCount = 3;
      gridRatio = 2.4;
    } else if (screenWidth > 600) {
      gridCount = 2;
      gridRatio = 2.6;
    } else {
      gridCount = 1;
      gridRatio = 3.0;
    }

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      body: Stack(
        children: [
          Center(
            child: FractionallySizedBox(
              widthFactor: isWide ? 0.80 : 1.0,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // 1. 大標題區域 (取代 AppBar)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 20.0,
                          right: 20.0,
                          top: 40.0,
                          bottom: 10.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "NSYSU",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.accentBlue,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  "校務通功能選單",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. 歡迎區塊
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10.0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colorScheme.isDark
                                  ? [
                                      const Color(0xFF1A237E),
                                      const Color(0xFF0D47A1),
                                    ]
                                  : [Colors.blue[800]!, Colors.blue[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                spreadRadius: 0,
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "歡迎使用",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[100],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "中山大學學生服務系統",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. 各功能分類
                    ..._buildCategorizedSections(
                      context,
                      gridCount,
                      gridRatio,
                      isWide,
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 60)),
                    const SliverToBoxAdapter(child: SizedBox(height: 60)),
                  ],
                ),
              ),
            ),
          ),

          if (ref.watch(mainMenuViewModelProvider).isFirstTimeLoading)
            Positioned.fill(
              child: Container(
                color: (colorScheme.isDark ? Colors.black : Colors.black87)
                    .withOpacity(0.9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "系統初始化中",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ValueListenableBuilder<double>(
                        valueListenable: _fakeProgressNotifier,
                        builder: (context, progress, _) {
                          int percent = (progress * 100).toInt();
                          return Column(
                            children: [
                              Text(
                                "$percent%",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: 220,
                                height: 10,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white10,
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorizedSections(
    BuildContext context,
    int gridCount,
    double gridRatio,
    bool isWide,
  ) {
    return [
      _buildCategoryHeader("成績查詢", Icons.assessment_rounded, Colors.blue),
      _buildCategoryGrid(gridCount, gridRatio, [
        _buildListCard(
          context,
          icon: Icons.school_rounded,
          label: "學期成績查詢",
          subLabel: "查詢歷年學期成績與學分",
          color: Colors.blue,
          onTap: () => context.go('/scores'),
        ),
        _buildListCard(
          context,
          icon: Icons.assignment_turned_in_rounded,
          label: "開放成績查詢",
          subLabel: "即時查看本學期已登錄成績",
          color: Colors.teal,
          onTap: () => context.go('/open-scores'),
        ),
        _buildListCard(
          context,
          icon: Icons.trending_up_rounded,
          label: "分數試算",
          subLabel: "試算各課程與總平均成績",
          color: Colors.indigo,
          onTap: () => context.go('/score-tracking'),
        ),
      ]),
      _buildCategoryHeader(
        "課程相關功能",
        Icons.library_books_rounded,
        Colors.orange,
      ),
      _buildCategoryGrid(gridCount, gridRatio, [
        _buildListCard(
          context,
          icon: Icons.calendar_month_rounded,
          label: "課表查詢",
          subLabel: "查看完整學期課程時間表",
          color: Colors.orange,
          onTap: () => context.go('/schedule'),
        ),
        _buildListCard(
          context,
          icon: Icons.assistant_rounded,
          label: "選課助手",
          subLabel: "模擬排課與課程評價搜尋",
          color: Colors.lightBlue,
          onTap: () => context.go('/assistant'),
        ),
        _buildListCard(
          context,
          icon: Icons.date_range_rounded,
          label: "選課系統",
          subLabel: "快速進入選課排課流程",
          color: const Color.fromARGB(255, 255, 29, 13),
          onTap: () => context.go('/selection'),
        ),
      ]),
      _buildCategoryHeader("網路大學", Icons.web_rounded, Colors.redAccent),
      _buildCategoryGrid(gridCount, gridRatio, [
        _buildListCard(
          context,
          icon: Icons.campaign_rounded,
          label: "網大公告",
          subLabel: "追蹤最新公告資訊",
          color: Colors.redAccent,
          onTap: () => context.go('/announcements'),
        ),
        _buildListCard(
          context,
          icon: Icons.task_rounded,
          label: "作業與考試",
          subLabel: "查看作業與考試期限",
          color: Colors.indigo,
          onTap: () => context.go('/tasks'),
        ),
      ]),
      _buildCategoryHeader("其他資訊查詢", Icons.search_rounded, Colors.purple),
      _buildCategoryGrid(gridCount, gridRatio, [
        _buildListCard(
          context,
          icon: Icons.fact_check_rounded,
          label: "畢業檢核",
          subLabel: "追蹤畢業進度（限大三以上）",
          color: Colors.purple,
          onTap: () => context.go('/graduation'),
        ),
        _buildListCard(
          context,
          icon: Icons.event_note_rounded,
          label: "中山行事曆",
          subLabel: "掌握校內重要活動日期",
          color: const Color.fromARGB(255, 228, 55, 113),
          onTap: () => context.go('/calendar'),
        ),
      ]),
      _buildCategoryHeader("其他", Icons.more_horiz_rounded, Colors.blueGrey),
      _buildCategoryGrid(gridCount, gridRatio, [
        _buildListCard(
          context,
          icon: Icons.settings_rounded,
          label: "系統設定",
          subLabel: "名次預覽與介面設定",
          color: Colors.blueGrey,
          onTap: () => context.go('/settings'),
        ),
        _buildListCard(
          context,
          icon: Icons.info_outline,
          label: "使用說明",
          subLabel: "功能指引與開發者資訊",
          color: Colors.blue,
          onTap: () => context.go('/info'),
        ),
        _buildListCard(
          context,
          icon: Icons.logout_rounded,
          label: "登出系統",
          subLabel: "安全結束目前登入階段",
          color: Colors.redAccent,
          onTap: _showLogoutDialog,
        ),
      ]),
    ];
  }

  Widget _buildCategoryHeader(String title, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 30,
          bottom: 10,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: color.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primaryText,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
    int gridCount,
    double gridRatio,
    List<Widget> children,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      sliver: SliverGrid.count(
        crossAxisCount: gridCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 12,
        childAspectRatio: gridRatio,
        children: children,
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.cardBackground,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(colorScheme.isDark ? 0.3 : 0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: color.withOpacity(0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.subtitleText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.subtitleText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("確認登出"),
        content: const Text("確定要登出並清除所有個人紀錄嗎？下次登入將重新初始化。"),
        actions: [
          TextButton(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("登出", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
          ),
        ],
      ),
    );
  }
}
