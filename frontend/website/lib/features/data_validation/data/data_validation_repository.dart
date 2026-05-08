import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'data_validation_models.dart';

final dataValidationRepositoryProvider = Provider<DataValidationRepository>((ref) {
  return DataValidationRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class DataValidationRepository {
  DataValidationRepository({
    required ApiClient apiClient,
    required AuthSession? session,
  })  : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Future<List<DataValidationItem>> getValidationQueue(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/data-validation/queue',
      headers: _authHeaders(),
    );
    final raw = response['images'] as List<dynamic>? ?? [];
    return raw
        .map((e) => DataValidationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitCorrection(String imageId, String correctedLabel) async {
    await _apiClient.postJson(
      '/images/$imageId/data-validation/correct',
      {'label': correctedLabel},
      headers: _authHeaders(),
    );
  }

  Future<Map<String, dynamic>> getProgress(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/data-validation/progress',
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
