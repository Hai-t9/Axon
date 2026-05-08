import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'model_submission_models.dart';

final modelSubmissionRepositoryProvider = Provider<ModelSubmissionRepository>((ref) {
  return ModelSubmissionRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class ModelSubmissionRepository {
  ModelSubmissionRepository({
    required ApiClient apiClient,
    required AuthSession? session,
  })  : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Future<List<ModelSubmission>> getModels(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/models',
      headers: _authHeaders(),
    );
    final raw = response['models'] as List<dynamic>? ?? [];
    return raw
        .map((e) => ModelSubmission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ModelSubmission>> getTeamModels(String teamId) async {
    final response = await _apiClient.getJson(
      '/teams/$teamId/models',
      headers: _authHeaders(),
    );
    final raw = response['models'] as List<dynamic>? ?? [];
    return raw
        .map((e) => ModelSubmission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ModelSpec> getSubmissionSpec(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/models/spec',
      headers: _authHeaders(),
    );
    return ModelSpec.fromJson(response);
  }

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to continue.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}
