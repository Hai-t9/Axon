import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import '../../competition/data/competition_repository.dart';
import 'gallery_models.dart';

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(
    apiClient: ref.watch(apiClientProvider),
    session: ref.watch(authSessionProvider),
  );
});

class GalleryRepository {
  GalleryRepository({required ApiClient apiClient, required AuthSession? session})
      : _apiClient = apiClient,
        _session = session;

  final ApiClient _apiClient;
  final AuthSession? _session;

  Future<String?> getMyTeamId(String competitionId) async {
    try {
      final response = await _apiClient.getJson(
        '/competitions/$competitionId/my-team',
        headers: _authHeaders(),
      );
      return response['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<TeamStats> getTeamStats(String teamId) async {
    final response = await _apiClient.getJson(
      '/teams/$teamId/statistics',
      headers: _authHeaders(),
    );
    return TeamStats.fromJson(response);
  }

  Future<GalleryImageList> getTeamImages({
    required String teamId,
    String? status,
    String? authorId,
    String? label,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (authorId != null && authorId.isNotEmpty) params['author_id'] = authorId;
    if (label != null && label.isNotEmpty) params['label'] = label;

    final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final response = await _apiClient.getJson(
      '/teams/$teamId/images?$queryString',
      headers: _authHeaders(),
    );
    final imagesList = (response['images'] as List<dynamic>?) ?? [];
    return GalleryImageList(
      images: imagesList
          .map((item) => GalleryImage.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (response['total'] as num?)?.toInt() ?? 0,
      page: (response['page'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> deleteImage(String imageId) async {
    await _apiClient.delete(
      '/images/$imageId',
      headers: _authHeaders(),
    );
  }

  Future<List<String>> getTeamLabels(String teamId) async {
    try {
      final stats = await getTeamStats(teamId);
      final labels = <String>{};
      for (final member in stats.members) {
        if (member.name.isNotEmpty) labels.add(member.name);
      }
      return labels.toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, String> _authHeaders() {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      throw AuthRequiredException();
    }
    return {'Authorization': 'Bearer $token'};
  }
}

class GalleryImageList {
  final List<GalleryImage> images;
  final int total;
  final int page;

  const GalleryImageList({
    required this.images,
    required this.total,
    required this.page,
  });
}
