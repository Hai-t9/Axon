import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/competition_service.dart';
import '../services/upload_service.dart';
import '../services/metadata_service.dart';
import '../services/offline_queue_service.dart';
import '../widgets/location_status_widget.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String teamId;
  final String competitionId;
  final ImageMetadata? capturedMetadata;
  final List<String>? availableLabels;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.teamId,
    required this.competitionId,
    this.capturedMetadata,
    this.availableLabels,
  });

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  bool _isUploading = false;
  String? _selectedLabel;
  late final List<String> _availableLabels;
  ImageMetadata? _metadata;
  bool _capturingGps = false;

  @override
  void initState() {
    super.initState();
    _availableLabels = widget.availableLabels ?? [
      'seedling', 'tillering', 'flowering', 'maturity', 'disease', 'pest'
    ];
    _metadata = widget.capturedMetadata;
  }

  Future<void> _captureGps() async {
    setState(() => _capturingGps = true);
    try {
      final position = await MetadataService().getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _metadata = ImageMetadata(
            latitude: position.latitude,
            longitude: position.longitude,
            deviceModel: _metadata?.deviceModel,
            deviceBrand: _metadata?.deviceBrand,
            timestamp: DateTime.now().toIso8601String(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('GPS location captured'),
            backgroundColor: const Color(0xFF33E1A6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not get GPS location. Make sure location is enabled.'),
              backgroundColor: const Color(0xFFE5A53C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturingGps = false);
    }
  }

  Future<void> _uploadImage({bool forceOnline = false}) async {
    if (_selectedLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a growth stage or issue.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF151A27),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final phase = await ref.read(competitionServiceProvider).getCurrentPhase(widget.competitionId);
      if ((phase['current_phase'] as String? ?? '') != '1') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Upload is only allowed during the Data Collection phase.'),
              backgroundColor: const Color(0xFFE5A53C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        setState(() => _isUploading = false);
        return;
      }
    } catch (_) {
      // Offline — will be enforced by backend on sync
    }

    try {
      final uploadService = ref.read(uploadServiceProvider);

      if (forceOnline) {
        await uploadService.uploadImage(
          filePath: widget.imagePath,
          teamId: widget.teamId,
          label: _selectedLabel!,
          metadata: _metadata,
        );
      } else {
        await uploadService.uploadOrQueue(
          filePath: widget.imagePath,
          teamId: widget.teamId,
          label: _selectedLabel!,
          metadata: _metadata,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Asset submitted successfully', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: const Color(0xFF33E1A6).withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: msg.contains('offline queue')
              ? const Color(0xFFE5A53C)
              : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      if (!msg.contains('offline queue')) {
        // Let them retry
      } else {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C28),
      appBar: AppBar(
        title: const Text('Review Asset'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          connectivity.when(
            data: (isOnline) {
              if (isOnline) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A53C).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFFE5A53C).withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 20, color: Color(0xFFE5A53C)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Offline Mode. Assets will be queued and uploaded automatically when connection returns.',
                        style: TextStyle(
                          color: Color(0xFFE5A53C),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF3A3A50), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'preview_image_${widget.imagePath}',
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_metadata != null) _buildMetadataChips(_metadata!),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(child: LocationStatusWidget()),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _capturingGps ? null : _captureGps,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5F75EE).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF5F75EE).withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _capturingGps
                                            ? const SizedBox(
                                                width: 14, height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5F75EE)),
                                              )
                                            : Icon(
                                                _metadata?.latitude != null
                                                    ? Icons.location_on
                                                    : Icons.location_searching,
                                                size: 14, color: const Color(0xFF5F75EE),
                                              ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _capturingGps
                                              ? 'Capturing...'
                                              : _metadata?.latitude != null
                                                  ? 'GPS Locked'
                                                  : 'Get GPS',
                                          style: const TextStyle(color: Color(0xFF5F75EE), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
              decoration: const BoxDecoration(
                color: Color(0xFF252536),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Classification',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select the primary growth stage or issue.',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _availableLabels.map((label) {
                        final isSelected = _selectedLabel == label;
                        return ChoiceChip(
                          label: Text(label.toUpperCase()),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() => _selectedLabel = selected ? label : null);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isUploading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : () => _uploadImage(),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_rounded, size: 22),
                                    SizedBox(width: 8),
                                    Text('Submit Asset'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChips(ImageMetadata metadata) {
    final chips = <Widget>[];
    if (metadata.latitude != null && metadata.longitude != null) {
      chips.add(_chip(Icons.location_on,
          '${metadata.latitude!.toStringAsFixed(4)}, ${metadata.longitude!.toStringAsFixed(4)}'));
    }
    if (metadata.deviceModel != null) {
      chips.add(_chip(Icons.phone_android, metadata.deviceModel!));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF252536),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5F75EE)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }
}
