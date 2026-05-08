import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/data_validation_models.dart';
import '../data/data_validation_repository.dart';

final dataValidationQueueProvider = FutureProvider.family<List<DataValidationItem>, String>(
    (ref, competitionId) {
  return ref
      .read(dataValidationRepositoryProvider)
      .getValidationQueue(competitionId);
});

final dataValidationProgressProvider = FutureProvider.family<Map<String, dynamic>, String>(
    (ref, competitionId) {
  return ref
      .read(dataValidationRepositoryProvider)
      .getProgress(competitionId);
});
