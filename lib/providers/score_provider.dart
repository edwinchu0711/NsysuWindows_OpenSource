import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/historical_score_service.dart';
import '../services/open_score_service.dart';

final historicalScoreServiceProvider = Provider<HistoricalScoreService>((ref) {
  return HistoricalScoreService.instance;
});

final openScoreServiceProvider = Provider<OpenScoreService>((ref) {
  return OpenScoreService.instance;
});