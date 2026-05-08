import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'leaderboard_models.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class LeaderboardRepository {
  LeaderboardRepository({
    required ApiClient apiClient,
    required AuthSession? session,
  })  : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Future<LeaderboardData> getLeaderboard(String competitionId, {int? limit}) async {
    final query = limit != null ? '?limit=$limit' : '';
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/leaderboard$query',
      headers: _authHeaders(),
    );
    return LeaderboardData.fromJson(response);
  }

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to continue.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}
