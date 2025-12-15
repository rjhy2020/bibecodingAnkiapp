class DailyDeckProgress {
  final int roundsCompleted;
  final int goalRounds;

  const DailyDeckProgress({
    required this.roundsCompleted,
    required this.goalRounds,
  });

  const DailyDeckProgress.empty()
      : roundsCompleted = 0,
        goalRounds = 0;

  DailyDeckProgress copyWith({
    int? roundsCompleted,
    int? goalRounds,
  }) {
    return DailyDeckProgress(
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      goalRounds: goalRounds ?? this.goalRounds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roundsCompleted': roundsCompleted,
      'goalRounds': goalRounds,
    };
  }

  factory DailyDeckProgress.fromJson(Map<String, dynamic> json) {
    return DailyDeckProgress(
      roundsCompleted: (json['roundsCompleted'] as num?)?.toInt() ?? 0,
      goalRounds: (json['goalRounds'] as num?)?.toInt() ?? 0,
    );
  }
}

