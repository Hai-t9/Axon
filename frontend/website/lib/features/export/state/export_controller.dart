import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/export_models.dart';
import '../data/export_repository.dart';

final exportTeamDataProvider =
    FutureProvider.family<ExportResponse?, String>((ref, competitionId) async {
  final repo = ref.read(exportRepositoryProvider);
  try {
    return await repo.exportTeamData(competitionId);
  } catch (_) {
    return null;
  }
});

final exportFullDataProvider =
    FutureProvider.family<ExportResponse?, String>((ref, competitionId) async {
  final repo = ref.read(exportRepositoryProvider);
  try {
    return await repo.exportFullData(competitionId);
  } catch (_) {
    return null;
  }
});
