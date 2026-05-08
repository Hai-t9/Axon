import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/leaderboard_models.dart';
import '../data/leaderboard_repository.dart';

final leaderboardProvider = FutureProvider.family<LeaderboardData, String>((ref, competitionId) {
  return ref.read(leaderboardRepositoryProvider).getLeaderboard(competitionId);
});
