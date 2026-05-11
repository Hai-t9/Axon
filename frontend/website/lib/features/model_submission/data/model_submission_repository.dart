import 'dart:convert';

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
    final base64Content = base64Encode(fileBytes);
    final body = {
      'team_id': request.teamId,
      'model_name': request.modelName,
      'framework': request.framework,
      'python_version': request.pythonVersion,
      'framework_version': request.frameworkVersion,
      'description': request.description,
      'file_content': base64Content,
      'filename': fileName,
    };

    final response = await _apiClient.postJson(
      '/competitions/$competitionId/models/submit',
      body,
      headers: _authHeaders(),
    );

    return SubmitModelResponse.fromJson(response);
  }
}
