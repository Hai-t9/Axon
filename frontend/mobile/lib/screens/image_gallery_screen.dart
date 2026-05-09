import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/uploaded_image_model.dart';
import '../services/competition_service.dart';
import '../services/api_client.dart';

class ImageGalleryScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String teamName;

  const ImageGalleryScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  ConsumerState<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends ConsumerState<ImageGalleryScreen> {
  List<UploadedImageModel> _images = [];
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    final service = ref.read(competitionServiceProvider);
    final images = await service.getTeamImages(widget.teamId);
    if (mounted) {
      setState(() {
        _images = images;
        _loading = false;
      });
    }
  }

  String _getImageUrl(String filepath) {
    final normalizedPath = filepath.replaceAll('\\', '/');
    final base = ApiConfig.baseUrl;

    if (normalizedPath.startsWith('http')) {
      return normalizedPath;
    }

    if (!normalizedPath.startsWith('uploads/')) {
      return '$base/uploads/$normalizedPath';
    }

    return '$base/$normalizedPath';
  }

  Future<bool> _shouldShowDeleteWarning() async {
    final box = await Hive.openBox('settings');
    return box.get('show_delete_warning', defaultValue: true);
  }

  Future<void> _setShowDeleteWarning(bool show) async {
    final box = await Hive.openBox('settings');
    await box.put('show_delete_warning', show);
  }

  Future<void> _deleteImage(UploadedImageModel image) async {
    setState(() => _deleting = true);
    try {
      final service = ref.read(competitionServiceProvider);
      await service.deleteImage(image.id);
      if (mounted) {
        setState(() {
          _images.removeWhere((img) => img.id == image.id);
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image deleted successfully'),
            backgroundColor: const Color(0xFF33E1A6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFCF6679),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmDelete(UploadedImageModel image) async {
    final showWarning = await _shouldShowDeleteWarning();
    if (!showWarning) {
      _deleteImage(image);
      return;
    }

    bool dontShowAgain = false;

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252536),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF3A3A50),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCF6679).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: Color(0xFFCF6679),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Delete Image',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        'This action cannot be undone. The image will be permanently deleted from the system along with all its labels and metadata.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Don't show again
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setDialogState(
                            () => dontShowAgain = !dontShowAgain),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: dontShowAgain
                                      ? const Color(0xFF5F75EE)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: dontShowAgain
                                        ? const Color(0xFF5F75EE)
                                        : const Color(0xFF3A3A50),
                                    width: 2,
                                  ),
                                ),
                                child: dontShowAgain
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Don't show again",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Color(0xFF3A3A50), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCF6679),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor:
                                    const Color(0xFFCF6679).withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
          },
        );
      },
    );

    if (result == true) {
      await _setShowDeleteWarning(!dontShowAgain);
      _deleteImage(image);
    }
  }

  void _showImageDetails(BuildContext context, UploadedImageModel image) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Image Details',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Blurred Background
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ),
              // Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'gallery_image_${image.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _getImageUrl(image.filepath),
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: MediaQuery.of(context).size.height * 0.5,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: MediaQuery.of(context).size.height * 0.5,
                            color: const Color(0xFF252536),
                            child: const Icon(Icons.broken_image,
                                color: Colors.white54, size: 64),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252536),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF3A3A50)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: image.status == 'approved'
                                      ? const Color(0xFF33E1A6).withOpacity(0.15)
                                      : const Color(0xFF5F75EE).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  image.status.toUpperCase(),
                                  style: TextStyle(
                                    color: image.status == 'approved'
                                        ? const Color(0xFF33E1A6)
                                        : const Color(0xFF5F75EE),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Assigned Label',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            image.label ?? 'Unlabeled',
                            style: TextStyle(
                              color: image.label != null
                                  ? const Color(0xFFFFD700)
                                  : Colors.white38,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFF3A3A50)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: Colors.white54, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                image.time.split('T').first,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _deleting ? null : () => _confirmDelete(image),
                              icon: _deleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.delete_rounded, size: 20),
                              label: Text(
                                  _deleting ? 'Deleting...' : 'Delete Image'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCF6679),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFCF6679).withOpacity(0.5),
                                elevation: 8,
                                shadowColor:
                                    const Color(0xFFCF6679).withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C28),
      appBar: AppBar(
        title: Text('${widget.teamName} Gallery'),
        backgroundColor: const Color(0xFF252536),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5F75EE)))
          : _images.isEmpty
              ? const Center(
                  child: Text(
                    'No images uploaded yet.',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF5F75EE),
                  backgroundColor: const Color(0xFF252536),
                  onRefresh: _loadImages,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final image = _images[index];
                      return GestureDetector(
                        onTap: () => _showImageDetails(context, image),
                        child: Hero(
                          tag: 'gallery_image_${image.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF252536),
                              image: DecorationImage(
                                image: NetworkImage(
                                    _getImageUrl(image.filepath)),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  image.label != null
                                      ? Icons.label_rounded
                                      : Icons.label_off_rounded,
                                  color: image.label != null
                                      ? const Color(0xFFFFD700)
                                      : Colors.white38,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
