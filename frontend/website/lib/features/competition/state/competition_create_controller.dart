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

  Future<void> createCompetition({
    required String name,
    String? description,
    DateTime? launchDate,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<Competition?>(() async {
      return ref.read(competitionRepositoryProvider).createCompetition(
            name: name,
            description: description,
            launchDate: launchDate,
          );
    });
  }
}
