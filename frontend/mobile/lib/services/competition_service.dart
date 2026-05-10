import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/competition_model.dart';
import '../models/leaderboard_model.dart';
import '../models/team_model.dart';
import '../models/team_stats_model.dart';
import '../models/uploaded_image_model.dart';
import 'api_client.dart';

class CompetitionService {
  final Dio _dio;

  CompetitionService(this._dio);

  Future<List<CompetitionModel>> getCompetitions() async {
    final response = await _dio.get('/api/v1/competitions');
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items
        .map((item) => CompetitionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TeamModel>> getTeams(String competitionId) async {
    final response = await _dio.get('/api/v1/competitions/$competitionId/teams');
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items
        .map((item) => TeamModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TeamStatsModel?> getTeamStats(String teamId) async {
    try {
      final response = await _dio.get('/api/v1/teams/$teamId/statistics');
      return TeamStatsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<String>?> getCompetitionLabels(String competitionId) async {
    try {
      final response = await _dio.get('/api/v1/competitions/$competitionId/config');
      final data = response.data as Map<String, dynamic>;
      final labelsData = data['labels'];
      if (labelsData != null) {
        if (labelsData is List) {
          return labelsData.map((e) => e.toString()).toList();
        } else if (labelsData is Map) {
          return labelsData.keys.map((e) => e.toString()).toList();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<TeamModel?> getMyTeam(String competitionId) async {
    try {
      final response = await _dio.get('/api/v1/competitions/$competitionId/my-team');
      return TeamModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<void> joinWithInvitationLink(String link) async {
    final response = await _dio.post('/api/v1/competitions/join', data: {
      'invitation_link': link,
    });
    if (response.statusCode != 200) {
      throw Exception(response.data['detail'] ?? 'Failed to join competition');
    }
  }

  Future<List<UploadedImageModel>> getTeamImages(String teamId, {int page = 1}) async {
    try {
      final response = await _dio.get(
        '/api/v1/teams/$teamId/images',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      final images = data['images'] as List<dynamic>;
      return images
          .map((img) => UploadedImageModel.fromJson(img as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteImage(String imageId) async {
    await _dio.delete('/api/v1/images/$imageId');
  }

  Future<LeaderboardResponse> getLeaderboard(String competitionId,
      {String type = 'public'}) async {
    final response = await _dio.get(
      '/api/v1/competitions/$competitionId/leaderboard',
      queryParameters: {'type': type},
    );
    return LeaderboardResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getValidationList(String competitionId) async {
    final response = await _dio.get(
      '/api/v1/competitions/$competitionId/validations/list',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitVote(String imageId, String label) async {
    final response = await _dio.post(
      '/api/v1/images/$imageId/validations',
      data: {'label': label},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> skipImage(String imageId) async {
    await _dio.post(
      '/api/v1/images/$imageId/validations/skip',
    );
  }

  Future<Map<String, dynamic>> getCurrentPhase(String competitionId) async {
    final response = await _dio.get(
      '/api/v1/competitions/$competitionId/phase',
    );
    return response.data as Map<String, dynamic>;
  }
}
final competitionServiceProvider = Provider<CompetitionService>((ref) {
  return CompetitionService(ref.read(dioProvider));
});