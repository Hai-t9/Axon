import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/upload_service.dart';
import '../services/metadata_service.dart';
import '../services/offline_queue_service.dart';
import '../widgets/location_status_widget.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String teamId;
  final String competitionId;
  final ImageMetadata? capturedMetadata;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.teamId,
    required this.competitionId,
    this.capturedMetadata,
  });

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  bool _isUploading = false;
  String? _selectedLabel;

  final List<String> _availableLabels = [
    'damage', 'front-bumper', 'rear-bumper',
    'left-door', 'right-door', 'scratch',
  ];

  Future<void> _uploadImage({bool forceOnline = false}) async {
    if (_selectedLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a label first!')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uploadService = ref.read(uploadServiceProvider);

      if (forceOnline) {
        await uploadService.uploadImage(
          filePath: widget.imagePath,
          teamId: widget.teamId,
          label: _selectedLabel!,
          metadata: widget.capturedMetadata,
        );
      } else {
        await uploadService.uploadOrQueue(
          filePath: widget.imagePath,
          teamId: widget.teamId,
          label: _selectedLabel!,
          metadata: widget.capturedMetadata,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload successful!'),
          backgroundColor: Color(0xFF37B287),
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
        ),
      );
      if (!msg.contains('offline queue')) {
        // Don't pop - let them retry or go back
      } else {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.capturedMetadata;
    final connectivity = ref.watch(connectivityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
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
                color: const Color(0xFFE5A53C),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Offline — image will be queued for upload',
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
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF3A3A50).withOpacity(0.5), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          if (metadata != null) _buildMetadataChips(metadata),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: LocationStatusWidget(),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C28),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Labeling',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select the correct label for this image.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _availableLabels.map((label) {
                    final isSelected = _selectedLabel == label;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      showCheckmark: false,
                      avatar: isSelected
                          ? const Icon(Icons.check_circle,
                              size: 16, color: Colors.white)
                          : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      onSelected: (selected) {
                        setState(
                            () => _selectedLabel = selected ? label : null);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
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
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 22),
                                  SizedBox(width: 8),
                                  Text('Submit Asset',
                                      style: TextStyle(fontSize: 16)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
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
