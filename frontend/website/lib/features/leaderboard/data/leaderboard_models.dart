class LeaderboardEntry {
  final int rank;
  final String teamName;
  final String? teamId;
  final double score;
  final String? submittedAt;

  const LeaderboardEntry({
    required this.rank,
    required this.teamName,
    this.teamId,
    required this.score,
    this.submittedAt,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      teamName: (json['team'] ?? json['team_name'] ?? 'Unknown') as String,
      teamId: json['team_id']?.toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      submittedAt: json['submitted_at'] as String?,
    );
  }
}

class LeaderboardData {
  final List<LeaderboardEntry> entries;
  final int totalTeams;
  final String? lastUpdated;

  const LeaderboardData({
    required this.entries,
    this.totalTeams = 0,
    this.lastUpdated,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'] as List<dynamic>? ?? [];
    return LeaderboardData(
      entries: raw
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalTeams: (json['total_teams'] as num?)?.toInt() ?? raw.length,
      lastUpdated: json['last_updated'] as String?,
    );
  }
}
