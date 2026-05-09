import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/uploaded_image_model.dart';
import '../services/competition_service.dart';
import '../services/api_client.dart';
import 'dart:ui';

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
    // Convert 'uploads\filename.jpg' or 'uploads/filename.jpg' to a valid URL path
    final normalizedPath = filepath.replaceAll('\\', '/');
    // Determine the base URL dynamically based on ApiConfig.baseUrl
    final base = ApiConfig.baseUrl;
    
    // If it's already an absolute URL, return it
    if (normalizedPath.startsWith('http')) {
      return normalizedPath;
    }
    
    // If the path doesn't start with 'uploads/', assume it's just the filename
    if (!normalizedPath.startsWith('uploads/')) {
       return '$base/uploads/$normalizedPath';
    }

    return '$base/$normalizedPath';
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
                                // Format time if needed, otherwise just display it
                                image.time.split('T').first,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                image: NetworkImage(_getImageUrl(image.filepath)),
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
