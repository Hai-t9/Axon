import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'validation_models.dart';

final validationRepositoryProvider = Provider<ValidationRepository>((ref) {
  return ValidationRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class ValidationRepository {
  ValidationRepository({
    required ApiClient apiClient,
    required AuthSession? session,
  })  : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Future<ValidationBatch> getValidationList(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/validations/list',
      headers: _authHeaders(),
    );
    return ValidationBatch.fromJson(response);
  }

  Future<void> submitVote(String imageId, String label) async {
    await _apiClient.postJson(
      '/images/$imageId/validations',
      {'label': label},
      headers: _authHeaders(),
    );
  }

  Future<List<ValidationImage>> getPendingValidations(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/validations/pending',
      headers: _authHeaders(),
    );
    final raw = response['images'] as List<dynamic>? ?? [];
    return raw
        .map((e) => ValidationImage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to continue.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}
