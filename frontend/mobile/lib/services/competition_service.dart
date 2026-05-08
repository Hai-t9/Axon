import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/competition_model.dart';
import '../models/team_model.dart';
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
}

final competitionServiceProvider = Provider<CompetitionService>((ref) {
  return CompetitionService(ref.read(dioProvider));
});