import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
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

class _ValidationPageState extends ConsumerState<ValidationPage>
    with SingleTickerProviderStateMixin {
  List<ValidationImage> _images = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSkipping = false;
  bool _isComplete = false;
  String? _errorMessage;

  String? _selectedLabel;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _loadValidationList();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadValidationList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(validationRepositoryProvider);
      final result = await repo.getValidationList(widget.competitionId);
      if (!mounted) return;
      setState(() {
        _images = result.images;
        _isLoading = false;
        if (_images.isEmpty) {
          _isComplete = true;
        } else {
          _loadCurrentImage();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _loadCurrentImage() {
    if (_currentIndex >= _images.length) {
      setState(() => _isComplete = true);
      return;
    }
    setState(() {
      _selectedLabel = _images[_currentIndex].currentLabel;
    });
    _animController.forward(from: 0);
  }

  Future<void> _submitVote() async {
    if (_selectedLabel == null || _selectedLabel!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a label before confirming.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(validationRepositoryProvider);
      final image = _images[_currentIndex];
      await repo.validateImage(image.imageId, _selectedLabel!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Label confirmed!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() {
        _isSubmitting = false;
        _currentIndex++;
      });
      if (_currentIndex >= _images.length) {
        setState(() => _isComplete = true);
      } else {
        _loadCurrentImage();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _skipImage() async {
    setState(() => _isSkipping = true);
    try {
      final repo = ref.read(validationRepositoryProvider);
      await repo.skipImage(_images[_currentIndex].imageId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image skipped.'),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() {
        _isSkipping = false;
        _currentIndex++;
      });
      if (_currentIndex >= _images.length) {
        setState(() => _isComplete = true);
      } else {
        _loadCurrentImage();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSkipping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _buildImageUrl(String filepath) {
    final base = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');
    final normalized = filepath.replaceAll('\\', '/');
    if (normalized.startsWith('http')) return normalized;
    return '$base/$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(competitionLabelsProvider(widget.competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Validation',
            subtitle: 'Review and confirm image labels',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading) _buildLoadingState(),
          if (_errorMessage != null && !_isLoading) _buildErrorState(_errorMessage!),
          if (!_isLoading && _errorMessage == null && _isComplete) _buildCompleteState(),
          if (!_isLoading && _errorMessage == null && !_isComplete) ...[
            _buildProgressBar(),
            const SizedBox(height: AppSpacing.lg),
            if (_currentIndex < _images.length) _buildImageCard(labels),
          ],
        ],
      ),
    );
  }

  // ── Progress Bar ──────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final total = _images.length;
    final current = _currentIndex + 1;
    final progress = total > 0 ? current / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Image $current of $total',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              color: AppColors.primaryDark,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Image Validation Card ─────────────────────────────────────────────
  Widget _buildImageCard(List<String> configLabels) {
    final image = _images[_currentIndex];

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image Display ──
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 320,
                  color: AppColors.surfaceAlt,
                  child: image.filepath != null && image.filepath!.isNotEmpty
                        ? Image.network(
                          image.imageUrl ?? _buildImageUrl(image.filepath!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined,
                                    size: 48, color: AppColors.textSecondary),
                                SizedBox(height: 8),
                                Text('Image not available',
                                    style: TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        )
                      : const Center(
                          child: Icon(Icons.image_outlined,
                              size: 64, color: AppColors.textSecondary),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Image Info ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ID: ${image.imageId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (image.currentLabel != null && image.currentLabel!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label_outline, size: 14, color: AppColors.textPrimary),
                          const SizedBox(width: 4),
                          Text(
                            image.currentLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Label Selection ──
              const Text(
                'Select Label',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the correct label for this image',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildLabelGrid(configLabels),
              const SizedBox(height: AppSpacing.xl),

              // ── Action Buttons ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_isSubmitting || _isSkipping) ? null : _skipImage,
                      icon: _isSkipping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryDark,
                              ),
                            )
                          : const Icon(Icons.skip_next_rounded, size: 20),
                      label: Text(_isSkipping ? 'Skipping...' : 'Skip'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: (_isSubmitting || _isSkipping) ? null : _submitVote,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Confirm Vote'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: _selectedLabel != null
                            ? AppColors.primaryDark
                            : AppColors.textSecondary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Label Grid ────────────────────────────────────────────────────────
  Widget _buildLabelGrid(List<String> configLabels) {
    final labels = configLabels.isNotEmpty
        ? configLabels
        : (_images[_currentIndex].currentLabel != null
            ? [_images[_currentIndex].currentLabel!]
            : <String>[]);

    if (labels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceAlt,
        ),
        child: const Text(
          'No labels configured for this competition.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: labels.map((label) {
        final isSelected = _selectedLabel == label;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedLabel = label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryDark.withValues(alpha: 0.12)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryDark : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle,
                          size: 16, color: AppColors.primaryDark),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primaryDark),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Loading your validation queue...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.success, AppColors.success.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.celebration_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Validation Complete!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _images.isEmpty
                ? 'No images were assigned for validation.'
                : 'You have validated all ${_images.length} images. Thank you!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => context.go('/competitions/${widget.competitionId}'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surface,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Unable to load validation queue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(error, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _loadValidationList,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
