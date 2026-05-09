import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'competition_models.dart';
import 'dashboard_models.dart';

final competitionRepositoryProvider = Provider<CompetitionRepository>((ref) {
  return CompetitionRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class CompetitionRepository {
  CompetitionRepository({required ApiClient apiClient, required AuthSession? session})
      : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Future<CompetitionList> listCompetitions({int page = 1, int limit = 20}) async {
    final response = await _apiClient.getJson(
      '/competitions?page=$page&limit=$limit',
      headers: _authHeaders(),
    );
    return CompetitionList.fromJson(response);
  }

  Future<Competition> getCompetition(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId',
      headers: _authHeaders(),
    );
    return Competition.fromJson(response);
  }

  Future<DashboardBase> getDashboard(String competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId/dashboard',
      headers: _authHeaders(),
    );
    return DashboardBase.fromJson(response);
  }

  Future<Competition> createCompetition({
    required String name,
    String? description,
    DateTime? launchDate,
    String? overview,
    String? dataFormat,
    String? evaluation,
    String? termsConditions,
    String? dataMarkdown,
    String? dataExample,
    String? scoringExample,
    int? maxValidations,
    double? duplicateThreshold,
    Map<String, dynamic>? labels,
    Map<String, dynamic>? modelSpec,
  }) async {
    final config = <String, dynamic>{};
    if (overview != null && overview.trim().isNotEmpty) config['overview'] = overview.trim();
    if (dataFormat != null && dataFormat.trim().isNotEmpty) config['data_format'] = dataFormat.trim();
    if (evaluation != null && evaluation.trim().isNotEmpty) config['evaluation'] = evaluation.trim();
    if (termsConditions != null && termsConditions.trim().isNotEmpty) config['terms_conditions'] = termsConditions.trim();
    if (dataMarkdown != null && dataMarkdown.trim().isNotEmpty) config['data_md'] = dataMarkdown.trim();
    if (dataExample != null && dataExample.trim().isNotEmpty) config['data_ex'] = dataExample.trim();
    if (scoringExample != null && scoringExample.trim().isNotEmpty) config['scoring_ex'] = scoringExample.trim();
    if (maxValidations != null) config['max_validations'] = maxValidations;
    if (duplicateThreshold != null) config['duplicate_threshhold'] = duplicateThreshold;
    if (labels != null && labels.isNotEmpty) config['labels'] = labels;
    if (modelSpec != null && modelSpec.isNotEmpty) config['model_spec'] = modelSpec;

    final payload = <String, dynamic>{
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (launchDate != null) 'launch_date': _formatDate(launchDate),
      if (config.isNotEmpty) 'config': config,
    };
    final response = await _apiClient.postJson(
      '/competitions',
      payload,
      headers: _authHeaders(),
    );
    return Competition.fromJson(response);
  }

  Future<Map<String, dynamic>> bulkCreateTeams({
    required String competitionId,
    required Map<String, List<String>> teamsData,
  }) async {
    final response = await _apiClient.postJson(
      '/competitions/$competitionId/teams/bulk',
      {'teams': teamsData},
      headers: _authHeaders(),
    );
    return response;
  }

  Future<Competition> updateCompetition({
    required String competitionId,
    String? name,
    String? description,
    DateTime? launchDate,
    String? invitationLink,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description.trim(),
      if (launchDate != null) 'launch_date': _formatDate(launchDate),
      if (invitationLink != null) 'invitation_link': invitationLink.trim(),
    };
    final response = await _apiClient.putJson(
      '/competitions/$competitionId',
      payload,
      headers: _authHeaders(),
    );
    return Competition.fromJson(response);
  }

  Future<void> updateConfig({
    required String competitionId,
    required Map<String, dynamic> configData,
  }) async {
    await _apiClient.putJson(
      '/competitions/$competitionId/config',
      configData,
      headers: _authHeaders(),
    );
  }

  Future<void> deleteCompetition(String competitionId) async {
    await _apiClient.delete(
      '/competitions/$competitionId',
      headers: _authHeaders(),
    );
  }

  Future<Competition?> findByInvitationLink(String link) async {
    final normalized = _normalizeLink(link);
    if (normalized.isEmpty) {
      return null;
    }

    final list = await listCompetitions(page: 1, limit: 100);
    for (final competition in list.items) {
      final invite = competition.invitationLink;
      if (invite == null) continue;
      if (_normalizeLink(invite) == normalized) {
        return competition;
      }
    }
    return null;
  }

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw const AuthRequiredException();
    }
    return {'Authorization': 'Bearer $token'};
  }

  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  String _normalizeLink(String value) {
    var trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

class AuthRequiredException implements Exception {
  const AuthRequiredException();

  @override
  String toString() => 'Please sign in to continue.';
}

class InvitationLinkNotFound implements Exception {
  const InvitationLinkNotFound();

  @override
  String toString() => 'Invitation link not found.';
}
