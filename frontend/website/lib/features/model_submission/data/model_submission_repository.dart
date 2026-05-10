import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:website/core/network/api_client.dart';
import 'package:website/features/auth/data/auth_models.dart';
import 'package:website/features/auth/state/auth_session_provider.dart';
import 'package:website/features/model_submission/data/model_submission_models.dart';

final modelSubmissionRepositoryProvider = Provider<ModelSubmissionRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final session = ref.watch(authSessionProvider);
  return ModelSubmissionRepository(apiClient, session);
});

class ModelSubmissionRepository {
  final ApiClient _apiClient;
  final AuthSession? _session;

  ModelSubmissionRepository(this._apiClient, this._session);

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<ModelSpec> getModelSpec(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/config',
      headers: _authHeaders(),
    );
    // The spec is in config.model_spec
    if (response['model_spec'] != null) {
      return ModelSpec.fromJson(response['model_spec']);
    }
    return ModelSpec.defaultSpec();
  }

  Future<List<ModelSubmission>> getSubmissions(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/models',
      headers: _authHeaders(),
    );
    final List<dynamic> items = response['items'] ?? [];
    return items.map((item) => ModelSubmission.fromJson(item)).toList();
  }

  Future<SubmitModelResponse> submitModel({
    required String competitionId,
    required SubmitModelRequest request,
    required List<int> fileBytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    // The query parameters are passed in the URL for this specific endpoint as per backend contract
    final queryParams = request.toQueryParameters();
    final queryString = Uri(queryParameters: queryParams).query;
    final path = '/competitions/$competitionId/models/submit?$queryString';

    final response = await _apiClient.postMultipart(
      path,
      fileField: 'file',
      fileBytes: fileBytes,
      fileName: fileName,
      headers: _authHeaders(),
      onProgress: onProgress != null
          ? (sent, total) => onProgress(sent / total)
          : null,
    );

    return SubmitModelResponse.fromJson(response);
  }
}
