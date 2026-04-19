import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/historical_score_service.dart';

class ScoreResultState {
  final String? selectedYear;
  final String? selectedSem;
  final bool hasInitializedSelection;

  const ScoreResultState({
    this.selectedYear,
    this.selectedSem,
    this.hasInitializedSelection = false,
  });

  ScoreResultState copyWith({
    String? selectedYear,
    String? selectedSem,
    bool? hasInitializedSelection,
  }) {
    return ScoreResultState(
      selectedYear: selectedYear ?? this.selectedYear,
      selectedSem: selectedSem ?? this.selectedSem,
      hasInitializedSelection:
          hasInitializedSelection ?? this.hasInitializedSelection,
    );
  }
}

final scoreResultViewModelProvider =
    StateNotifierProvider<ScoreResultViewModel, ScoreResultState>((ref) {
  return ScoreResultViewModel();
});

class ScoreResultViewModel extends StateNotifier<ScoreResultState> {
  ScoreResultViewModel() : super(const ScoreResultState());

  void autoSelectSemester() {
    if (state.hasInitializedSelection) return;

    final coursesMap = HistoricalScoreService.instance.coursesNotifier.value;
    final yearsSet = HistoricalScoreService.instance.validYearsNotifier.value;
    if (yearsSet.isEmpty || coursesMap.isEmpty) return;

    List<String> years = yearsSet.toList()..sort((a, b) => b.compareTo(a));

    int currentMonth = DateTime.now().month;
    String targetSem = (currentMonth >= 5 && currentMonth <= 10) ? "2" : "1";

    for (var year in years) {
      String key = "$year-$targetSem";
      if (coursesMap.containsKey(key) && coursesMap[key]!.isNotEmpty) {
        state = state.copyWith(
          selectedYear: year,
          selectedSem: targetSem,
          hasInitializedSelection: true,
        );
        return;
      }
    }

    for (var year in years) {
      final sems =
          HistoricalScoreService.instance.validSemestersNotifier.value[year] ??
              []
            ..sort((a, b) => b.compareTo(a));

      for (var sem in sems) {
        String key = "$year-$sem";
        if (coursesMap[key]?.isNotEmpty ?? false) {
          state = state.copyWith(
            selectedYear: year,
            selectedSem: sem,
            hasInitializedSelection: true,
          );
          return;
        }
      }
    }
  }

  void selectYear(String year) {
    state = state.copyWith(selectedYear: year, selectedSem: null);
  }

  void selectSemester(String sem) {
    state = state.copyWith(selectedSem: sem);
  }

  bool isRankPreviewOffPeriod() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    bool inPeriod1 = (month == 3 && day >= 20) ||
        (month > 3 && month < 6) ||
        (month == 6 && day <= 5);
    bool inPeriod2 = (month == 10 && day >= 15) || (month > 10) || (month == 1 && day <= 5);

    return inPeriod1 || inPeriod2;
  }

  ScoreSummary calculateSemesterSummary(List<CourseScore> courses) {
    double totalWeightedPoints = 0;
    double gpaCredits = 0;
    double creditsTaken = 0;
    double creditsEarned = 0;

    final Map<String, double> gradePoints = {
      "A+": 4.3, "A": 4.0, "A-": 3.7,
      "B+": 3.3, "B": 3.0, "B-": 2.7,
      "C+": 2.3, "C": 2.0, "C-": 1.7,
      "D": 1.0, "E": 0.0, "F": 0.0, "X": 0.0,
    };

    for (var course in courses) {
      double credit = double.tryParse(course.credits) ?? 0;
      String score = course.score.trim();

      if (score.contains("抵免")) continue;
      creditsTaken += credit;

      if (score != "E" && score != "F" && score != "X" && score != "") {
        creditsEarned += credit;
      }

      if (score != "(P)" && gradePoints.containsKey(score)) {
        gpaCredits += credit;
        totalWeightedPoints += (credit * gradePoints[score]!);
      }
    }

    double avg = gpaCredits > 0 ? (totalWeightedPoints / gpaCredits) : 0.0;

    return ScoreSummary(
      creditsTaken: creditsTaken.toInt().toString(),
      creditsEarned: creditsEarned.toInt().toString(),
      average: avg == 0.0 ? "0" : avg.toStringAsFixed(2),
      rank: "--",
      classSize: "--",
    );
  }
}