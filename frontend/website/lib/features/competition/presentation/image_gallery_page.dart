import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../../gallery/data/gallery_models.dart';
import '../../gallery/data/gallery_repository.dart';

class ImageGalleryPage extends ConsumerStatefulWidget {
  final String teamId;
  final String teamName;

  const ImageGalleryPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  ConsumerState<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends ConsumerState<ImageGalleryPage> {
  List<GalleryImage> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(galleryRepositoryProvider);
      final result = await repo.getTeamImages(teamId: widget.teamId, page: 1);
      if (mounted) {
        setState(() {
          _images = result.images;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMsg(e.toString(), isError: true);
      }
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _confirmDelete(GalleryImage image) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Image'),
        content: Text('Are you sure you want to delete this image${image.label != null ? ' (${image.label})' : ''}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteImage(image);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteImage(GalleryImage image) async {
    try {
      await ref.read(galleryRepositoryProvider).deleteImage(image.id);
      if (!mounted) return;
      _showMsg('Image deleted');
      _loadImages();
    } catch (e) {
      if (!mounted) return;
      _showMsg('Failed to delete image: $e', isError: true);
    }
  }

  String _getImageUrl(String filepath) {
    final base = AppConfig.apiBaseUrl.replaceFirst('/api/v1', '');
    final normalizedPath = filepath.replaceAll('\\', '/');

    if (normalizedPath.startsWith('http')) {
      return normalizedPath;
    }

    if (!normalizedPath.startsWith('uploads/')) {
       return '$base/uploads/$normalizedPath';
    }

    return '$base/$normalizedPath';
  }

  void _showImageDetails(BuildContext context, GalleryImage image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 0.9 * 600),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Image Details', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _getImageUrl(image.filepath),
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: AppColors.background,
                        child: const Center(child: Icon(Icons.broken_image, size: 64, color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _detailRow('Status', image.status.toUpperCase(),
                    valueColor: image.status == 'approved' ? AppColors.success : AppColors.primary,
                    background: image.status == 'approved' ? AppColors.success.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _detailRow('Label', image.label ?? 'Unlabeled',
                    valueColor: image.label != null ? Colors.amber : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Text('Uploaded: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      Text(
                        image.time.split('T').first,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor, Color? background}) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        if (background != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        else
          Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal, fontSize: valueColor != null ? 18 : 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AxonScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PageHeader(
                  title: '${widget.teamName} Gallery',
                  subtitle: 'View uploaded images and labels.',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Teams'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _images.isEmpty
                    ? Center(
                        child: Text(
                          'No images found for this team.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: 1,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          final image = _images[index];
                          return InkWell(
                            onTap: () => _showImageDetails(context, image),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                                image: DecorationImage(
                                  image: NetworkImage(_getImageUrl(image.filepath)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            image.label != null ? Icons.label : Icons.label_off,
                                            size: 14,
                                            color: image.label != null ? Colors.amber : Colors.white54,
                                          ),
                                          if (image.label != null) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              image.label!,
                                              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: GestureDetector(
                                      onTap: () => _confirmDelete(image),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.delete_outline, size: 14, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
