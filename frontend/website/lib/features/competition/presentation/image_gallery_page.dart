import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../../auth/state/auth_session_provider.dart';

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
  List<Map<String, dynamic>> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  String? get _token => ref.read(authSessionProvider)?.accessToken;
  Map<String, String> get _authHeaders => {'Authorization': 'Bearer $_token'};

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.getJson(
        '/teams/${widget.teamId}/images?page=1',
        headers: _authHeaders,
      );
      final items = (resp['images'] as List<dynamic>?) ?? [];
      if (mounted) {
        setState(() {
          _images = items.cast<Map<String, dynamic>>();
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

  String _getImageUrl(String filepath) {
    // Determine the base URL dynamically based on apiClientProvider
    final base = 'http://192.168.167.205:8000'; // Or use api.baseUrl if exposed
    final normalizedPath = filepath.replaceAll('\\', '/');

    if (normalizedPath.startsWith('http')) {
      return normalizedPath;
    }
    
    if (!normalizedPath.startsWith('uploads/')) {
       return '$base/uploads/$normalizedPath';
    }

    return '$base/$normalizedPath';
  }

  void _showImageDetails(BuildContext context, Map<String, dynamic> image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(AppSpacing.lg),
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
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _getImageUrl(image['filepath'] ?? ''),
                    height: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 300,
                      width: 400,
                      color: AppColors.background,
                      child: const Center(child: Icon(Icons.broken_image, size: 64, color: AppColors.textSecondary)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: image['status'] == 'approved' ? AppColors.success.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (image['status'] ?? 'unknown').toUpperCase(),
                      style: TextStyle(
                        color: image['status'] == 'approved' ? AppColors.success : AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Text('Label: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  Text(
                    image['label'] ?? 'Unlabeled',
                    style: TextStyle(
                      color: image['label'] != null ? Colors.amber : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Text('Uploaded: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  Text(
                    (image['time'] ?? '').split('T').first,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
                                  image: NetworkImage(_getImageUrl(image['filepath'] ?? '')),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Align(
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
                                        image['label'] != null ? Icons.label : Icons.label_off,
                                        size: 14,
                                        color: image['label'] != null ? Colors.amber : Colors.white54,
                                      ),
                                      if (image['label'] != null) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          image['label'],
                                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
