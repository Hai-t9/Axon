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
        backgroundColor: const Color(0xFF1C1C28),
        appBar: AppBar(title: const Text('Capture Asset')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF5F75EE))),
      );
    }

    if (_cameraPermissionDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C28),
        appBar: AppBar(title: const Text('Capture Asset')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.no_photography_rounded, size: 64, color: Colors.redAccent),
                ),
                const SizedBox(height: 32),
                Text(
                  'Camera Access Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Axon needs camera access to capture assets. Please grant camera permission in settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
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
        backgroundColor: const Color(0xFF1C1C28),
        appBar: AppBar(title: const Text('Capture Asset')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 64, color: Colors.white38),
              ),
              const SizedBox(height: 24),
              const Text('No camera found on this device',
                  style: TextStyle(color: Colors.white60, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: CameraPreview(_controller),
                      ),
                    );
                  },
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
              return const Center(child: CircularProgressIndicator(color: Color(0xFF5F75EE)));
            },
          ),
          
          // Custom transparent app bar over camera
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Offline Banner
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: connectivity.when(
              data: (isOnline) {
                if (isOnline) return const SizedBox.shrink();
                return Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A53C).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Offline Mode Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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

          // Camera Controls Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 48, top: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _takePicture,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.9, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.transparent,
                            ),
                            child: Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
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
            ),
          ),
        ],
      ),
    );
  }
}