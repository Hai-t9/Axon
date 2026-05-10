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

  /// GET /competitions/:compId/data-validation/queue
  Future<ValidationListResponse> getValidationList(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/data-validation/queue',
      headers: _authHeaders(),
    );
    return ValidationListResponse.fromJson(response);
  }

  /// POST /competitions/:compId/data-validation/images/:imageId/validate
  Future<ValidationVoteResponse> validateImage(
      String competitionId, String imageId) async {
    final response = await _apiClient.postJson(
      '/competitions/$competitionId/data-validation/images/$imageId/validate',
      {},
      headers: _authHeaders(),
    );
    return ValidationVoteResponse.fromJson(response);
  }

  /// POST /competitions/:compId/data-validation/images/:imageId/correct
  Future<ValidationVoteResponse> correctLabel(
      String competitionId, String imageId, String label) async {
    final response = await _apiClient.postJson(
      '/competitions/$competitionId/data-validation/images/$imageId/correct',
      {'label': label},
      headers: _authHeaders(),
    );
    return ValidationVoteResponse.fromJson(response);
  }

  /// POST /competitions/:compId/data-validation/images/:imageId/skip
  Future<void> skipImage(String competitionId, String imageId) async {
    await _apiClient.postJson(
      '/competitions/$competitionId/data-validation/images/$imageId/skip',
      {},
      headers: _authHeaders(),
    );
  }

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to continue.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}
