import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/upload_service.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  bool _isUploading = false;
  
  // Hardcoded for now until backend config endpoint is wired into mobile
  final List<String> _availableLabels = [
    'damage',
    'front-bumper',
    'rear-bumper',
    'left-door',
    'right-door',
    'scratch'
  ];
  String? _selectedLabel;

  Future<void> _uploadImage() async {
    if (_selectedLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a label first!')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final uploadService = ref.read(uploadServiceProvider);
      
      // Send the actual selected label instead of dummy labels
      final labelPayload = {
        'tags': [_selectedLabel],
      };

      await uploadService.uploadImage(widget.imagePath, '1', labelPayload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload successful!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121A), // Ultra dark background for contrast
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
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: const Color(0xFF3A3A50).withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5F75EE).withOpacity(0.03),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 48), // Generous padding
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C28),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Labeling',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select the correct label for this image.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white60,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5F75EE).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF5F75EE), size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  children: _availableLabels.map((label) {
                    final isSelected = _selectedLabel == label;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      showCheckmark: false, // Cleaner aesthetic without default check
                      avatar: isSelected ? const Icon(Icons.check_circle, size: 16, color: Colors.white) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedLabel = selected ? label : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 44),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading ? null : () {
                          Navigator.of(context).pop();
                        },
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
                        onPressed: _isUploading ? null : _uploadImage,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: _isUploading ? 0 : 8,
                          shadowColor: const Color(0xFF5F75EE).withOpacity(0.4), // Logo glow
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 22),
                                  SizedBox(width: 8),
                                  Text('Submit Asset', style: TextStyle(fontSize: 16)),
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
}
