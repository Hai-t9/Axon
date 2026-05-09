import 'dart:html' as html;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'export_models.dart';

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class ExportRepository {
  ExportRepository({required ApiClient apiClient, required AuthSession? session})
      : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw AuthRequiredException();
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<ExportResponse> exportTeamData(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/export/team-data',
      headers: _authHeaders(),
    );
    return ExportResponse.fromJson(response);
  }

  Future<ExportResponse> exportFullData(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/export/full-data',
      headers: _authHeaders(),
    );
    return ExportResponse.fromJson(response);
  }

  Future<void> downloadTeamDataset(String competitionId) async {
    final bytes = await _apiClient.getBytes(
      '/competitions/$competitionId/export/team-dataset',
      headers: _authHeaders(),
    );
    _triggerDownload(bytes, 'dataset.zip');
  }

  Future<void> downloadFullDataset(String competitionId) async {
    final bytes = await _apiClient.getBytes(
      '/competitions/$competitionId/export/full-dataset',
      headers: _authHeaders(),
    );
    _triggerDownload(bytes, 'full_dataset.zip');
  }

  void _triggerDownload(List<int> bytes, String filename) {
    final blob = html.Blob([bytes], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    (html.document.createElement('a') as html.AnchorElement)
      ..href = url
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

class AuthRequiredException implements Exception {
  const AuthRequiredException();

  @override
  String toString() => 'Please sign in to continue.';
}
