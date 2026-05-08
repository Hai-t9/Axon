import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'preview_screen.dart';
import '../services/metadata_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  final String teamId;
  final String competitionId;

  const CameraScreen({
    super.key,
    required this.cameras,
    required this.teamId,
    required this.competitionId,
  });

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller.initialize();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      if (!mounted) return;

      final metadata = await MetadataService().captureMetadata();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            imagePath: image.path,
            teamId: widget.teamId,
            competitionId: widget.competitionId,
            capturedMetadata: metadata,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);

    if (widget.cameras.isEmpty) {
      return const Scaffold(body: Center(child: Text('No camera found')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Capture Asset')),
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: connectivity.when(
              data: (isOnline) {
                if (isOnline) return const SizedBox.shrink();
                return Container(
                  color: const Color(0xFFE5A53C),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Offline — uploads queued',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _takePicture,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.camera_alt, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}