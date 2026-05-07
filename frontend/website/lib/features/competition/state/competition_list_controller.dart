import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/competition_models.dart';
import '../data/competition_repository.dart';

final competitionListProvider =
    AsyncNotifierProvider<CompetitionListController, CompetitionList>(
  CompetitionListController.new,
);

class CompetitionListController extends AsyncNotifier<CompetitionList> {
  @override
  Future<CompetitionList> build() async {
    return ref.watch(competitionRepositoryProvider).listCompetitions();
  }

  Future<void> refreshList() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<CompetitionList>(
      () => ref.read(competitionRepositoryProvider).listCompetitions(),
    );
  }
}
