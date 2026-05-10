import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:website/features/model_submission/data/model_submission_models.dart';
import 'package:website/features/model_submission/data/model_submission_repository.dart';
import 'package:website/features/competition/data/competition_repository.dart';
import 'package:website/features/model_submission/state/model_submission_form_state.dart';

final modelSubmissionListProvider = AsyncNotifierProviderFamily<
    ModelSubmissionListController, List<ModelSubmission>, String>(
  ModelSubmissionListController.new,
);

class ModelSubmissionListController
    extends FamilyAsyncNotifier<List<ModelSubmission>, String> {
  @override
  Future<List<ModelSubmission>> build(String arg) async {
    return ref.watch(modelSubmissionRepositoryProvider).getSubmissions(arg);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() =>
        ref.read(modelSubmissionRepositoryProvider).getSubmissions(arg));
  }
}

final modelSpecProvider =
    FutureProvider.family<ModelSpec, String>((ref, competitionId) async {
  return ref.watch(modelSubmissionRepositoryProvider).getModelSpec(competitionId);
});

final myTeamProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, competitionId) async {
  return ref.watch(competitionRepositoryProvider).getMyTeam(competitionId);
});

final modelSubmissionControllerProvider = StateNotifierProvider.family<
    ModelSubmissionController, ModelFormState, String>(
  (ref, competitionId) => ModelSubmissionController(
    ref: ref,
    competitionId: competitionId,
    repository: ref.watch(modelSubmissionRepositoryProvider),
  ),
);

class ModelSubmissionController extends StateNotifier<ModelFormState> {
  final Ref ref;
  final String competitionId;
  final ModelSubmissionRepository repository;

  ModelSubmissionController({
    required this.ref,
    required this.competitionId,
    required this.repository,
  }) : super(const ModelFormState());

  void updateModelName(String value) {
    state = state.copyWith(modelName: value, error: null);
  }

  void updateFramework(String value) {
    state = state.copyWith(framework: value, error: null);
  }

  void updatePythonVersion(String value) {
    state = state.copyWith(pythonVersion: value, error: null);
  }

  void updateFrameworkVersion(String? value) {
    state = state.copyWith(frameworkVersion: value, error: null);
  }

  void updateDescription(String? value) {
    state = state.copyWith(description: value, error: null);
  }

  void setFile(List<int> bytes, String name) {
    state = state.copyWith(fileBytes: bytes, fileName: name, error: null);
  }

  Future<void> submit() async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Please fill all required fields and select a file.');
      return;
    }

    state = state.copyWith(isSubmitting: true, error: null, uploadProgress: 0.1);

    try {
      final teamData = await ref.read(myTeamProvider(competitionId).future);
      final teamId = teamData['id'].toString();

      final request = SubmitModelRequest(
        teamId: teamId,
        modelName: state.modelName,
        framework: state.framework,
        pythonVersion: state.pythonVersion,
        frameworkVersion: state.frameworkVersion,
        description: state.description,
      );

      await repository.submitModel(
        competitionId: competitionId,
        request: request,
        fileBytes: state.fileBytes!,
        fileName: state.fileName!,
        onProgress: (progress) {
          state = state.copyWith(uploadProgress: 0.3 + (progress * 0.6));
        },
      );

      state = state.copyWith(uploadProgress: 1.0, isSubmitting: false);
      
      // Refresh the list
      ref.read(modelSubmissionListProvider(competitionId).notifier).refresh();
      
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
    }
  }
}
