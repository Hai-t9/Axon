import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _cameraPermissionDenied = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (mounted) setState(() { _cameraPermissionDenied = true; _checkingPermission = false; });
        return;
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) setState(() { _cameraPermissionDenied = true; _checkingPermission = false; });
      return;
    }

    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller.initialize();
    }
    if (mounted) setState(() => _checkingPermission = false);
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    if (!_checkingPermission && !_cameraPermissionDenied) {
      _controller.dispose();
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);

    if (_checkingPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture Asset')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cameraPermissionDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture Asset')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography, size: 64, color: Colors.white38),
                const SizedBox(height: 24),
                Text(
                  'Camera Access Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Axon needs camera access to capture assets. Please grant camera permission in settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.cameras.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture Asset')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 64, color: Colors.white38),
              SizedBox(height: 16),
              Text('No camera found on this device',
                  style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      );
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
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Camera error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
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