import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

class ValidationScreen extends ConsumerStatefulWidget {
  final int compId;
  const ValidationScreen({super.key, required this.compId});

  @override
  ConsumerState<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends ConsumerState<ValidationScreen> {
  bool _isLoading = true;
  List<dynamic> _images = [];
  int _currentIndex = 0;
  List<String> _labelOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      
      // Fetch Config for dynamic labels
      final configRes = await dio.get('/api/v1/competitions/${widget.compId}/config');
      final labels = configRes.data['labels'] as List<dynamic>? ?? [];
      
      // Fetch batch of images
      final batchRes = await dio.get('/api/v1/competitions/${widget.compId}/validations/batch');
      
      if (mounted) {
        setState(() {
          _labelOptions = labels.map((e) => e.toString()).toList();
          if (_labelOptions.isEmpty) {
            _labelOptions = ['Healthy', 'Blight', 'Rust', 'Weed']; // Fallback
          }
          _images = batchRes.data['images'] ?? [];
          _currentIndex = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _submitVote(String label) async {
    if (_images.isEmpty) return;
    
    final imageId = _images[_currentIndex]['id'];
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/v1/images/$imageId/validations', data: {'label': label});
      
      if (mounted) {
        if (_currentIndex < _images.length - 1) {
          setState(() {
            _currentIndex++;
          });
        } else {
          // Batch complete, fetch another one
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch complete! Loading next...')),
          );
          _fetchData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cross-Team Validation')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No pending validations available.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchData,
                        child: const Text('Refresh'),
                      )
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Image ${_currentIndex + 1} of ${_images.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black26,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              '${ref.read(dioProvider).options.baseUrl}/${_images[_currentIndex]['filepath']}',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => 
                                const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text('Select the correct label:', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: _labelOptions.map((label) {
                          return ActionChip(
                            label: Text(label),
                            onPressed: () => _submitVote(label),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
    );
  }
}
