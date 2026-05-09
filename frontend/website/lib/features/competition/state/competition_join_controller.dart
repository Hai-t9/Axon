import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/competition_models.dart';
import '../data/competition_repository.dart';

final competitionJoinProvider =
    AsyncNotifierProvider<CompetitionJoinController, Competition?>(
  CompetitionJoinController.new,
);

class CompetitionJoinController extends AsyncNotifier<Competition?> {
  @override
  Future<Competition?> build() async {
    return null;
  }

  Future<void> joinWithInvitationLink(String link) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<Competition?>(() async {
      return await ref.read(competitionRepositoryProvider).joinCompetition(link);
    });
  }
}
