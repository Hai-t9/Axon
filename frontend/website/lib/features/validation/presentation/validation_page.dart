import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/validation_models.dart';
import '../data/validation_repository.dart';
import '../state/validation_controller.dart';

class ValidationPage extends ConsumerStatefulWidget {
  const ValidationPage({super.key, required this.competitionId});

  static const routeName = 'validation';
  static const routePath = '/competitions/:id/validation';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/validation';

  @override
  ConsumerState<ValidationPage> createState() => _ValidationPageState();
}

class _ValidationPageState extends ConsumerState<ValidationPage> {
  final Map<String, String> _selectedLabels = {};
  final List<String> _availableLabels = [
    'damage', 'front-bumper', 'rear-bumper',
    'left-door', 'right-door', 'scratch',
  ];

  Future<void> _submitVote(ValidationImage image) async {
    final label = _selectedLabels[image.imageId];
    if (label == null || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a label first!')),
      );
      return;
    }
    try {
      await ref.read(validationRepositoryProvider).submitVote(image.imageId, label);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vote submitted!'), backgroundColor: AppColors.success),
      );
      ref.invalidate(validationListProvider(widget.competitionId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(validationListProvider(widget.competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Validation', subtitle: 'Vote on image labels'),
          const SizedBox(height: AppSpacing.lg),
          state.when(
            data: (raw) {
              final batch = raw as ValidationBatch;
              if (batch.images.isEmpty) {
                return _emptyState(context);
              }
              return Expanded(
                child: ListView.separated(
                  itemCount: batch.images.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final image = batch.images[index];
                    return _buildImageCard(context, image);
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

  Widget _buildImageCard(BuildContext context, ValidationImage image) {
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Image #${image.imageId}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (image.currentLabel != null)
                      Text('Current label: ${image.currentLabel}',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLabels.map((label) {
              final isSelected = _selectedLabels[image.imageId] == label;
              return ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 13)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedLabels[image.imageId] = label;
                    } else {
                      _selectedLabels.remove(image.imageId);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _submitVote(image),
              child: const Text('Submit Vote'),
            ),
          ),
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
          Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
          const SizedBox(height: AppSpacing.md),
          Text('All caught up!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          const Text('No images to validate at this time.'),
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
