import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/validation_models.dart';
import '../data/validation_repository.dart';

final validationListProvider = FutureProvider.family<ValidationBatch, String>(
    (ref, competitionId) {
  return ref.read(validationRepositoryProvider).getValidationList(competitionId);
});

final pendingValidationsProvider = FutureProvider.family<List<ValidationImage>, String>(
    (ref, competitionId) {
  return ref.read(validationRepositoryProvider).getPendingValidations(competitionId);
});
