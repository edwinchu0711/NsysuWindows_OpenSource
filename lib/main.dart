/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'package:flutter/material.dart';
import 'pages/captcha_auto_login_page.dart';
import 'package:flutter/services.dart';
import 'services/cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 記得保留這個
import 'package:window_manager/window_manager.dart'; // 新增這行：視窗管理
import 'services/storage_service.dart';
import 'services/historical_score_service.dart';
import 'services/course_service.dart';

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
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
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
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CaptchaAutoLoginPage(),

        // ★★★ 新增：設定語言環境 (這會讓日曆顯示中文) ★★★
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'TW'), // 繁體中文
          Locale('en', 'US'), // 英文
        ],

        // ★★★ 結束 ★★★
        theme: ThemeData(
          primarySwatch: Colors.blue,
          // ★★★ 新增：取消點擊水波紋效果，讓整體看起來更像網頁 ★★★
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,

          // ★★★ 新增：按鈕滑鼠游標全域設定 (Pointer) ★★★
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.basic,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.basic,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.basic,
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: ButtonStyle(
              mouseCursor: MaterialStateProperty.resolveWith<MouseCursor?>((
                Set<MaterialState> states,
              ) {
                if (states.contains(MaterialState.disabled)) {
                  return SystemMouseCursors.basic;
                }
                return SystemMouseCursors.click;
              }),
            ),
          ),

          // ★★★ 結束 ★★★
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
      ),
    );
  });
}
