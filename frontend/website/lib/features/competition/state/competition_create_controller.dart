import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/competition_models.dart';
import '../data/competition_repository.dart';

final competitionCreateProvider =
    AsyncNotifierProvider<CompetitionCreateController, Competition?>(
  CompetitionCreateController.new,
);

class CompetitionCreateController extends AsyncNotifier<Competition?> {
  @override
  Future<Competition?> build() async {
    return null;
  }

  Future<Competition?> createCompetition({
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
    Map<String, List<String>>? teamsData,
  }) async {
    state = const AsyncLoading();
    try {
      final competition =
          await ref.read(competitionRepositoryProvider).createCompetition(
                name: name,
                description: description,
                launchDate: launchDate,
                overview: overview,
                dataFormat: dataFormat,
                evaluation: evaluation,
                termsConditions: termsConditions,
                dataMarkdown: dataMarkdown,
                dataExample: dataExample,
                scoringExample: scoringExample,
                maxValidations: maxValidations,
                duplicateThreshold: duplicateThreshold,
                labels: labels,
                modelSpec: modelSpec,
              );

      if (teamsData != null && teamsData.isNotEmpty) {
        await ref.read(competitionRepositoryProvider).bulkCreateTeams(
              competitionId: competition.id,
              teamsData: teamsData,
            );
      }

      state = AsyncData(competition);
      return competition;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
