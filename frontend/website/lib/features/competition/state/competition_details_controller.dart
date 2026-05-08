import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/competition_models.dart';
import '../data/competition_repository.dart';

final competitionDetailsProvider = AsyncNotifierProviderFamily<
    CompetitionDetailsController, Competition, String>(
  CompetitionDetailsController.new,
);

class CompetitionDetailsController
    extends FamilyAsyncNotifier<Competition, String> {
  @override
  Future<Competition> build(String competitionId) async {
    return ref.watch(competitionRepositoryProvider).getCompetition(competitionId);
  }
}
