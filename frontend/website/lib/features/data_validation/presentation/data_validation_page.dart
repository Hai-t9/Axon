import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/data_validation_models.dart';
import '../data/data_validation_repository.dart';
import '../state/data_validation_controller.dart';

class DataValidationPage extends ConsumerStatefulWidget {
  const DataValidationPage({super.key, required this.competitionId});

  static const routeName = 'data-validation';
  static const routePath = '/competitions/:id/data-validation';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/data-validation';

  @override
  ConsumerState<DataValidationPage> createState() => _DataValidationPageState();
}

class _DataValidationPageState extends ConsumerState<DataValidationPage> {
  final Map<String, String> _corrections = {};
  final List<String> _availableLabels = [
    'damage', 'front-bumper', 'rear-bumper',
    'left-door', 'right-door', 'scratch',
  ];

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(dataValidationQueueProvider(widget.competitionId));
    final progressState = ref.watch(dataValidationProgressProvider(widget.competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Data Validation', subtitle: 'Review and correct image labels'),
          const SizedBox(height: AppSpacing.lg),
          progressState.whenOrNull(
            data: (progress) => _buildProgressCard(context, progress as Map<String, dynamic>),
          ) ?? const SizedBox.shrink(),
          const SizedBox(height: AppSpacing.lg),
          Text('Validation Queue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          queueState.when(
            data: (items) {
              final queue = items as List<DataValidationItem>;
              if (queue.isEmpty) {
                return _emptyState(context);
              }
              return Expanded(
                child: ListView.separated(
                  itemCount: queue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    return _buildItemCard(context, item);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _errorState(context, err.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, Map<String, dynamic> progress) {
    final total = (progress['total_images'] as num?)?.toInt() ?? 0;
    final validated = (progress['validated_images'] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? validated / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text('$validated / $total images validated'),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              color: AppColors.success,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, DataValidationItem item) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Image #${item.imageId}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (item.collectedBy != null)
                      Text('Collected by: ${item.collectedBy}',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (item.currentLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Current label: ${item.currentLabel}',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Correct to:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLabels.map((label) {
              final isSelected = _corrections[item.imageId] == label;
              return ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 13)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _corrections[item.imageId] = label;
                    } else {
                      _corrections.remove(item.imageId);
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (_corrections.containsKey(item.imageId)) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  final label = _corrections[item.imageId]!;
                  try {
                    await ref
                        .read(dataValidationRepositoryProvider)
                        .submitCorrection(item.imageId, label);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Correction submitted!'),
                          backgroundColor: AppColors.success),
                    );
                    setState(() => _corrections.remove(item.imageId));
                    ref.invalidate(dataValidationQueueProvider(widget.competitionId));
                    ref.invalidate(dataValidationProgressProvider(widget.competitionId));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('Submit Correction'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 64, color: AppColors.success),
          const SizedBox(height: AppSpacing.md),
          Text('All labels verified!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          const Text('No images pending data validation.'),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unable to load validation queue',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(error),
        ],
      ),
    );
  }
}
