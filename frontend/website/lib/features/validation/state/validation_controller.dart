import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../competition/state/competition_details_controller.dart';
import '../data/validation_models.dart';
import '../data/validation_repository.dart';

/// Fetches the full validation list (image IDs) for a competition.
final validationListProvider =
    FutureProvider.family<ValidationListResponse, String>(
        (ref, competitionId) {
  return ref
      .read(validationRepositoryProvider)
      .getValidationList(competitionId);
});

/// Extracts the label names from the competition config.
/// The config.labels field is a map where keys are label names.
final competitionLabelsProvider =
    Provider.family<List<String>, String>((ref, competitionId) {
  final compAsync = ref.watch(competitionDetailsProvider(competitionId));
  final comp = compAsync.valueOrNull;
  if (comp == null || comp.config == null || comp.config!.labels == null) {
    return [];
  }
  return comp.config!.labels!.keys.toList();
});
