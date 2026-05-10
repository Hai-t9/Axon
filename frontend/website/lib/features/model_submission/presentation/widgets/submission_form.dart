import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:website/theme/app_spacing.dart';
import 'package:website/features/model_submission/state/model_submission_controller.dart';
import 'package:website/features/model_submission/state/model_submission_form_state.dart';

class SubmissionForm extends ConsumerWidget {
  final String competitionId;

  const SubmissionForm({super.key, required this.competitionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelSubmissionControllerProvider(competitionId));
    final controller = ref.read(modelSubmissionControllerProvider(competitionId).notifier);
    final myTeamAsync = ref.watch(myTeamProvider(competitionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        myTeamAsync.when(
          data: (team) => _buildReadOnlyField(context, 'Team', team['name'] ?? 'Your Team'),
          loading: () => const LinearProgressIndicator(),
          error: (err, stack) => Text('Error loading team: $err', style: const TextStyle(color: Colors.red)),
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Model Name',
            hintText: 'e.g. My Awesome Model v1',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.updateModelName,
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: state.framework,
                decoration: const InputDecoration(
                  labelText: 'Framework',
                  border: OutlineInputBorder(),
                ),
                items: ['pytorch', 'tensorflow', 'sklearn', 'keras', 'onnx']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => v != null ? controller.updateFramework(v) : null,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: state.pythonVersion,
                decoration: const InputDecoration(
                  labelText: 'Python Version',
                  border: OutlineInputBorder(),
                ),
                items: ['3.8', '3.9', '3.10', '3.11', '3.12']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => v != null ? controller.updatePythonVersion(v) : null,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Framework Version (Optional)',
            hintText: 'e.g. 2.1.0',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.updateFrameworkVersion,
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Description (Optional)',
            hintText: 'Briefly describe your approach...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: controller.updateDescription,
        ),
        SizedBox(height: AppSpacing.xl),
        _buildFilePicker(context, state, controller),
        if (state.error != null) ...[
          SizedBox(height: AppSpacing.md),
          Text(
            state.error!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyField(BuildContext context, String label, String value) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildFilePicker(BuildContext context, ModelFormState state, ModelSubmissionController controller) {
    return InkWell(
      onTap: state.isSubmitting ? null : () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
          withData: true,
        );
        if (result != null && result.files.single.bytes != null) {
          controller.setFile(result.files.single.bytes!, result.files.single.name);
        }
      },
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: state.fileName != null ? Colors.green : Colors.grey.shade400,
            style: BorderStyle.solid,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.md),
          color: state.fileName != null ? Colors.green.withOpacity(0.05) : Colors.grey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.fileName != null ? Icons.check_circle : Icons.cloud_upload_outlined,
              size: 48,
              color: state.fileName != null ? Colors.green : Colors.grey.shade400,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              state.fileName ?? 'Drag & drop your .zip or click to browse',
              style: TextStyle(
                color: state.fileName != null ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: state.fileName != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (state.fileName == null)
              Text(
                'Only .zip files are allowed',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
