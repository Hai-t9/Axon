import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'preview_screen.dart';
import '../services/metadata_service.dart';

class CameraScreen extends StatefulWidget {
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
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
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
    if (widget.cameras.isEmpty) {
      return const Scaffold(body: Center(child: Text('No camera found')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Asset')),
      body: FutureBuilder<void>(
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
      floatingActionButton: FloatingActionButton.large(
        onPressed: _takePicture,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.camera_alt, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
