import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_models.dart';
import '../data/competition_repository.dart';

final dashboardProvider = AsyncNotifierProviderFamily<
    DashboardController, DashboardBase, String>(
  DashboardController.new,
);

class DashboardController extends FamilyAsyncNotifier<DashboardBase, String> {
  @override
  Future<DashboardBase> build(String competitionId) async {
    return ref.watch(competitionRepositoryProvider).getDashboard(competitionId);
  }
}
