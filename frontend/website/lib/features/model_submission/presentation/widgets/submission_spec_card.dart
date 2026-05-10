import 'package:flutter/material.dart';
import 'package:website/theme/app_spacing.dart';
import 'package:website/features/model_submission/data/model_submission_models.dart';

class SubmissionSpecCard extends StatelessWidget {
  final ModelSpec spec;

  const SubmissionSpecCard({super.key, required this.spec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: theme.colorScheme.primary),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Submission Requirements',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(height: AppSpacing.xl),
            _buildSpecRow(context, 'Max Size:', '${spec.maxSizeMb} MB'),
            _buildSpecRow(context, 'Formats:', spec.allowedModelFormats.join(', ')),
            _buildSpecRow(context, 'Required Files:', spec.requiredFiles.join(', ')),
            _buildSpecRow(context, 'Inference Fn:', '${spec.inferenceFunction}()'),
            if (spec.pythonVersionMin != null)
              _buildSpecRow(context, 'Min Python:', spec.pythonVersionMin!),
            SizedBox(height: AppSpacing.md),
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected Directory Structure:',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'submission.zip\n'
                    '├── ${spec.modelDir}/       # Your model weights\n'
                    '├── ${spec.dataDir}/        # Required data files\n'
                    '├── inference.py     # Inference entry point\n'
                    '├── Dockerfile       # Container definition\n'
                    '└── requirements.txt # Python dependencies',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
