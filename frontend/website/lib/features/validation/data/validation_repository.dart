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

  /// GET /competitions/:compId/validations/list
  Future<ValidationListResponse> getValidationList(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/validations/list',
      headers: _authHeaders(),
    );
    return ValidationListResponse.fromJson(response);
  }

  /// POST /images/:imageId/validations  body: {"label": label}
  Future<ValidationVoteResponse> validateImage(
      String imageId, String label) async {
    final response = await _apiClient.postJson(
      '/images/$imageId/validations',
      {'label': label},
      headers: _authHeaders(),
    );
    return ValidationVoteResponse.fromJson(response);
  }

  /// POST /images/:imageId/validations/skip
  Future<void> skipImage(String imageId) async {
    await _apiClient.postJson(
      '/images/$imageId/validations/skip',
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
