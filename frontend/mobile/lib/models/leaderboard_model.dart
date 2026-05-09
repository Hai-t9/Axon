class LeaderboardTeam {
  final String id;
  final String name;

  const LeaderboardTeam({required this.id, required this.name});

  factory LeaderboardTeam.fromJson(Map<String, dynamic> json) {
    return LeaderboardTeam(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final LeaderboardTeam team;
  final double score;
  final String? submittedAt;
  final int modelsSubmitted;
  final double? accuracy;
  final double? precision;
  final double? recall;
  final double? f1Score;
  final String? protocol;

  const LeaderboardEntry({
    required this.rank,
    required this.team,
    required this.score,
    this.submittedAt,
    this.modelsSubmitted = 0,
    this.accuracy,
    this.precision,
    this.recall,
    this.f1Score,
    this.protocol,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      team: LeaderboardTeam.fromJson(json['team'] as Map<String, dynamic>? ?? {}),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      submittedAt: json['submitted_at'] as String?,
      modelsSubmitted: json['models_submitted'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      precision: (json['precision'] as num?)?.toDouble(),
      recall: (json['recall'] as num?)?.toDouble(),
      f1Score: (json['f1_score'] as num?)?.toDouble(),
      protocol: json['protocol'] as String?,
    );
  }
}

class LeaderboardResponse {
  final List<LeaderboardEntry> entries;
  final int totalTeams;
  final String type;
  final String phase;
  final String phaseLabel;
  final String lastUpdated;

  const LeaderboardResponse({
    required this.entries,
    required this.totalTeams,
    required this.type,
    required this.phase,
    required this.phaseLabel,
    required this.lastUpdated,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    final entriesList = json['entries'] as List<dynamic>? ?? [];
    return LeaderboardResponse(
      entries: entriesList
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalTeams: json['total_teams'] as int? ?? 0,
      type: json['type'] as String? ?? 'public',
      phase: json['phase'] as String? ?? '0',
      phaseLabel: json['phase_label'] as String? ?? '',
      lastUpdated: json['last_updated'] as String? ?? '',
    );
  }

  bool get showLeaderboard => entries.isNotEmpty;
}
