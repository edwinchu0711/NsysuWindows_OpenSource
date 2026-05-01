import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_providers.dart';
import 'package:flutter/foundation.dart';

class MainMenuState {
  final bool isFirstTimeLoading;
  final double loadingProgress;

  const MainMenuState({
    this.isFirstTimeLoading = false,
    this.loadingProgress = 0.0,
  });

  MainMenuState copyWith({
    bool? isFirstTimeLoading,
    double? loadingProgress,
  }) {
    return MainMenuState(
      isFirstTimeLoading: isFirstTimeLoading ?? this.isFirstTimeLoading,
      loadingProgress: loadingProgress ?? this.loadingProgress,
    );
  }
}

final mainMenuViewModelProvider =
    StateNotifierProvider<MainMenuViewModel, MainMenuState>((ref) {
  return MainMenuViewModel(ref);
});

class MainMenuViewModel extends StateNotifier<MainMenuState> {
  final Ref _ref;

  MainMenuViewModel(this._ref) : super(const MainMenuState());

  Future<void> checkAndStartTasks() async {
    final sw = Stopwatch()..start();
    final prefs = await SharedPreferences.getInstance();
    bool hasCourseCache = prefs.containsKey('cached_courses_plain_v3');

    if (!hasCourseCache) {
      await prefs.setBool('is_preview_rank_enabled', true);
      state = state.copyWith(isFirstTimeLoading: true);
      _startBackgroundTask().catchError((e) {
        debugPrint("背景任務異常(忽略): $e");
      });
    } else {
      _startBackgroundTask();
    }
    debugPrint('[VM] checkAndStartTasks 完成 (+${sw.elapsedMilliseconds}ms)');
  }

  Future<void> _startBackgroundTask() async {
    final sw = Stopwatch()..start();
    try {
      debugPrint('[BG] refreshAndCache 開始');
      await _ref.read(courseServiceProvider).refreshAndCache();
      debugPrint('[BG] refreshAndCache 完成 (+${sw.elapsedMilliseconds}ms)');
      if (isScoreReleaseSeason()) {
        debugPrint('[BG] fetchOpenScores 開始');
        await _ref.read(openScoreServiceProvider).fetchOpenScores();
        debugPrint('[BG] fetchOpenScores 完成 (+${sw.elapsedMilliseconds}ms)');
      }
      debugPrint('[BG] fetchAllData 開始');
      await _ref.read(historicalScoreServiceProvider).fetchAllData();
      debugPrint('[BG] fetchAllData 完成 (+${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      debugPrint("❌ 背景抓取發生錯誤: $e");
    }
    debugPrint('[BG] _startBackgroundTask 總耗時 (+${sw.elapsedMilliseconds}ms)');
  }

  bool isScoreReleaseSeason() {
    DateTime now = DateTime.now();
    int month = now.month;
    int day = now.day;
    bool isWinter = (month == 12 && day >= 15) || (month == 1 && day <= 15);
    bool isSummer = (month == 5 && day >= 15) || (month == 6 && day <= 15);
    return isWinter || isSummer;
  }

  void setLoadingComplete() {
    state = state.copyWith(isFirstTimeLoading: false);
  }

  Future<void> logout() async {
    await Future.wait([
      _ref.read(courseServiceProvider).clearCache(),
      _ref.read(openScoreServiceProvider).clearCache(),
      _ref.read(historicalScoreServiceProvider).clearCache(),
      _ref.read(elearnServiceProvider).clearAllCache(),
      _ref.read(elearnBulletinServiceProvider).clearCache(),
      _ref.read(graduationServiceProvider).clearCache(),
    ]);

    await _ref.read(storageServiceProvider).clearAll();
  }
}