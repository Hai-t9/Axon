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

  /// Triggers generation of validation assignments for all teams.
  /// POST /competitions/:compId/validations/generate
  Future<void> generateValidation(String competitionId) async {
    await _apiClient.postJson(
      '/competitions/$competitionId/validations/generate',
      {},
      headers: _authHeaders(),
    );
  }

  /// Fetches the full list of image IDs assigned for validation.
  /// GET /competitions/:compId/validations/list
  Future<ValidationListResponse> getValidationList(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/validations/list',
      headers: _authHeaders(),
    );
    return ValidationListResponse.fromJson(response);
  }

  /// Fetches a single image's details (filepath, label, etc.)
  /// GET /images/:imageId
  Future<ValidationImage> getImageDetails(int imageId) async {
    final response = await _apiClient.getJson(
      '/images/$imageId',
      headers: _authHeaders(),
    );
    return ValidationImage.fromJson(response);
  }

  /// Submits a validation vote for a specific image.
  /// POST /images/:imageId/validations
  Future<ValidationVoteResponse> submitVote(int imageId, String label) async {
    final response = await _apiClient.postJson(
      '/images/$imageId/validations',
      {'label': label},
      headers: _authHeaders(),
    );
    return ValidationVoteResponse.fromJson(response);
  }

  /// Skips validation for a specific image.
  /// POST /images/:imageId/validations/skip
  Future<void> skipImage(int imageId) async {
    await _apiClient.postJson(
      '/images/$imageId/validations/skip',
      {},
      headers: _authHeaders(),
    );
  }

  /// Fetches images still pending validation.
  /// GET /competitions/:compId/validations/pending
  Future<List<ValidationPendingImage>> getPendingValidations(
      String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/validations/pending',
      headers: _authHeaders(),
    );
    final raw = response['images'] as List<dynamic>? ?? [];
    return raw
        .map((e) =>
            ValidationPendingImage.fromJson(e as Map<String, dynamic>))
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
