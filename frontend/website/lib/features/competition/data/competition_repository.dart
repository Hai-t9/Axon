import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import 'competition_models.dart';

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

  Future<Competition> getCompetition(int competitionId) async {
    final response = await _apiClient.getJson(
      '/competitions/$competitionId',
      headers: _authHeaders(),
    );
    return Competition.fromJson(response);
  }

  Future<Competition> createCompetition({
    required String name,
    String? description,
    DateTime? launchDate,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (launchDate != null) 'launch_date': _formatDate(launchDate),
    };
    final response = await _apiClient.postJson(
      '/competitions',
      payload,
      headers: _authHeaders(),
    );
    return Competition.fromJson(response);
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
