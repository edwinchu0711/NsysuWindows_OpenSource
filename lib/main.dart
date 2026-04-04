/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'package:flutter/material.dart';
import 'pages/captcha_auto_login_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 記得保留這個
import 'package:window_manager/window_manager.dart';
import 'widgets/custom_title_bar.dart';
import 'services/storage_service.dart';
import 'services/historical_score_service.dart';
import 'services/course_service.dart';

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

  // 初始化安全存儲與遷移
  await StorageService.instance.init();

  // 初始化主題設定
  await ThemeNotifier.instance.init();

  // 顯式從快取載入資料 (StorageService 已就緒)
  await Future.wait([
    HistoricalScoreService.instance.loadFromCache(),
    CourseService.instance.loadFromCache(),
  ]);

  // ★★★ 新增：初始化 desktop 視窗大小設定 ★★★
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(900, 600), // x > y (長方形)
    center: true,
    titleBarStyle: TitleBarStyle.hidden, // 隱藏標題列
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize(); // 打到最開
    await windowManager.show();
    await windowManager.focus();
  });
  // ★★★ 結束 ★★★

  // 這裡是你原本註解掉的快取清理，我保持原樣
  // try {
  //   await AppCacheManager.checkAndCleanCache();
  //   print("快取檢查完成");
  // } catch (e) {
  //   print("清理快取時發生錯誤: $e");
  // }

  // 設定限制方向
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeNotifier.instance,
        builder: (context, themeMode, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const CaptchaAutoLoginPage(),

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
                      child: CustomTitleBar(
                        key: titleBarKey,
                        title: "NSYSU",
                      ),
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
            supportedLocales: const [
              Locale('zh', 'TW'),
              Locale('en', 'US'),
            ],

            // ★★★ 雙主題 + 動態切換 ★★★
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
          );
        },
      ),
    );
  });
}
