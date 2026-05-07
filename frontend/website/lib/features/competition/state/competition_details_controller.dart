import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/competition_models.dart';
import '../data/competition_repository.dart';

final competitionDetailsProvider = AsyncNotifierProviderFamily<
    CompetitionDetailsController, Competition, int>(
  CompetitionDetailsController.new,
);

class CompetitionDetailsController
    extends FamilyAsyncNotifier<Competition, int> {
  @override
  Future<Competition> build(int competitionId) async {
    return ref.watch(competitionRepositoryProvider).getCompetition(competitionId);
  }
}
