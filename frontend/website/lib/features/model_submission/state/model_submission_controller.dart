import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/model_submission_models.dart';
import '../data/model_submission_repository.dart';

final modelListProvider = FutureProvider.family<List<ModelSubmission>, String>(
    (ref, competitionId) {
  return ref.read(modelSubmissionRepositoryProvider).getModels(competitionId);
});

final modelSpecProvider = FutureProvider.family<ModelSpec, String>(
    (ref, competitionId) {
  return ref.read(modelSubmissionRepositoryProvider).getSubmissionSpec(competitionId);
});
