import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/evaluation_models.dart';
import '../data/evaluation_repository.dart';

final evaluationListProvider = FutureProvider.family<List<EvaluationResult>, String>(
    (ref, competitionId) {
  return ref.read(evaluationRepositoryProvider).getEvaluations(competitionId);
});

final evaluationDetailProvider = FutureProvider.family<EvaluationResult, String>(
    (ref, evaluationId) {
  return ref.read(evaluationRepositoryProvider).getEvaluation(evaluationId);
});

final evaluationResultsProvider = FutureProvider.family<Map<String, dynamic>, String>(
    (ref, evaluationId) {
  return ref.read(evaluationRepositoryProvider).getEvaluationResults(evaluationId);
});

final competitionResultsProvider = FutureProvider.family<Map<String, dynamic>, String>(
    (ref, competitionId) {
  return ref.read(evaluationRepositoryProvider).getCompetitionResults(competitionId);
});
