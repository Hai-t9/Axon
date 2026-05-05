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
      appBar: AppBar(title: const Text('Preview Photo')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(File(widget.imagePath)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Label (Required):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  children: _availableLabels.map((label) {
                    return ChoiceChip(
                      label: Text(label),
                      selected: _selectedLabel == label,
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedLabel = selected ? label : null;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _isUploading ? null : () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retake'),
            ),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadImage,
              icon: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: const Text('Upload & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
