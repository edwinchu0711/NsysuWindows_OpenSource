/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/pdf_rule_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'widgets/custom_title_bar.dart';
import 'services/storage_service.dart';
import 'services/historical_score_service.dart';
import 'services/course_service.dart';
import 'services/course_query_service.dart';
import 'services/local_course_service.dart';
import 'services/database_embedding_service.dart';
import 'router.dart';

import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';

final GlobalKey<State<CustomTitleBar>> titleBarKey = GlobalKey();

// 自定義動畫 Builder (保持原樣)
class BottomUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const BottomUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 1.0);
    const end = Offset.zero;
    const curve = Curves.ease;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 臨時加入：清除舊的選課須知快取
  await PdfRuleService.instance.fetchAndCache(); // 確保實例加載
  PdfRuleService.instance.clearCache();
  debugPrint("[DEBUG] 已清除選課須知舊快取文字");

  final sw = Stopwatch()..start();

  // 初始化安全存儲與遷移
  // debugPrint("[INIT] StorageService 開始");
  await StorageService.instance.init();
  // debugPrint("[INIT] StorageService 完成 (+${sw.elapsedMilliseconds}ms)");

  // 初始化主題設定
  // debugPrint("[INIT] ThemeNotifier 開始");
  await ThemeNotifier.instance.init();
  // debugPrint("[INIT] ThemeNotifier 完成 (+${sw.elapsedMilliseconds}ms)");

  // 顯式從快取載入資料 (StorageService 已就緒)
  // debugPrint("[INIT] loadFromCache 開始");
  await Future.wait([
    HistoricalScoreService.instance.loadFromCache(),
    CourseService.instance.loadFromCache(),
  ]);
  // debugPrint("[INIT] loadFromCache 完成 (+${sw.elapsedMilliseconds}ms)");

  // 初始化 Isar 並從本地載入課程資料
  // debugPrint("[INIT] CourseQueryService 開始");
  await CourseQueryService.instance.init();
  // debugPrint("[INIT] CourseQueryService 完成 (+${sw.elapsedMilliseconds}ms)");

  // 初始化本地課程資料庫 (安全處理 DB 不存在的情況)
  // debugPrint("[INIT] LocalCourseService 開始");
  await LocalCourseService.instance.init();
  // debugPrint("[INIT] LocalCourseService 完成 (+${sw.elapsedMilliseconds}ms)");

  // 初始化 embedding 資料庫，完成後背景檢查更新
  // debugPrint("[INIT] DatabaseEmbeddingService 開始");
  await DatabaseEmbeddingService.instance.init();
  // debugPrint("[INIT] DatabaseEmbeddingService 完成 (+${sw.elapsedMilliseconds}ms)",);
  DatabaseEmbeddingService.instance.checkForAutoUpdate();

  // ★★★ 新增：初始化 desktop 視窗大小設定 ★★★
  // debugPrint("[INIT] windowManager 開始");
  await windowManager.ensureInitialized();
  // debugPrint("[INIT] windowManager 完成 (+${sw.elapsedMilliseconds}ms)");

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(1100, 720), // x > y (長方形)
    center: true,
    titleBarStyle: TitleBarStyle.hidden, // 隱藏標題列
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // debugPrint("[INIT] waitUntilReadyToShow callback 觸發 (+${sw.elapsedMilliseconds}ms)");
    await windowManager.maximize(); // 打到最開
    await windowManager.show();
    await windowManager.focus();
  });
  // ★★★ 結束 ★★★

  // 這裡是你原本註解掉的快取清理，我保持原樣
  // try {
  //   await AppCacheManager.checkAndCleanCache();
  //   debugPrint("快取檢查完成");
  // } catch (e) {
  //   debugPrint("清理快取時發生錯誤: $e");
  // }

  // 桌面應用不需要設定螢幕方向，直接啟動
  runApp(
    ProviderScope(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeNotifier.instance,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,

            // 注入全局 UI 框架
            builder: (context, child) {
              return Material(
                color: Theme.of(context).colorScheme.pageBackground,
                child: Stack(
                  children: [
                    // 內容區域：向下偏移 32 像素
                    Positioned.fill(
                      top: 32,
                      child: child ?? const SizedBox.shrink(),
                    ),
                    // 靜態標題列
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 32,
                      child: CustomTitleBar(key: titleBarKey, title: "NSYSU"),
                    ),
                  ],
                ),
              );
            },

            // 語言環境
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],

            // ★★★ 雙主題 + 動態切換 ★★★
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
          );
        },
      ),
    ),
  );
}
