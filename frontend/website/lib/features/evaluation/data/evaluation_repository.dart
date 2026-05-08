import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'evaluation_models.dart';

final evaluationRepositoryProvider = Provider<EvaluationRepository>((ref) {
  return EvaluationRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class EvaluationRepository {
  EvaluationRepository({
    required ApiClient apiClient,
    required AuthSession? session,
  })  : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Future<List<EvaluationResult>> getEvaluations(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/evaluations',
      headers: _authHeaders(),
    );
    final raw = response['evaluations'] as List<dynamic>? ?? [];
    return raw
        .map((e) => EvaluationResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EvaluationResult> getEvaluation(String evaluationId) async {
    final response = await _apiClient.getJson(
      '/evaluations/$evaluationId',
      headers: _authHeaders(),
    );
    return EvaluationResult.fromJson(response);
  }

  Future<Map<String, dynamic>> getEvaluationResults(String evaluationId) async {
    final response = await _apiClient.getJson(
      '/evaluations/$evaluationId/results',
      headers: _authHeaders(),
    );
    return response;
  }

  Future<Map<String, dynamic>> getCompetitionResults(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/results',
      headers: _authHeaders(),
    );
    return response;
  }

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to continue.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}
