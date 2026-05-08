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
  bool _submitting = false;

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
            _labelOptions = ['Healthy', 'Blight', 'Rust', 'Weed'];
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
    if (_images.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    
    final imageId = _images[_currentIndex]['id'];
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/v1/images/$imageId/validations', data: {'label': label});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validated as "$label"'),
            duration: const Duration(milliseconds: 800),
            backgroundColor: const Color(0xFF00C49F),
          ),
        );
        _goToNext();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _skipImage() {
    if (_images.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Skipped'),
        duration: Duration(milliseconds: 600),
        backgroundColor: Color(0xFF555566),
      ),
    );
    _goToNext();
  }

  void _goToNext() {
    if (_currentIndex < _images.length - 1) {
      setState(() => _currentIndex++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch complete! Loading next...')),
      );
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      appBar: AppBar(
        title: const Text('Cross-Team Validation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF00C49F)),
                        const SizedBox(height: 24),
                        const Text(
                          'No pending validations',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All images have been validated, or no new images are available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildValidationCard(),
    );
  }

  Widget _buildValidationCard() {
    final image = _images[_currentIndex];
    final currentLabel = image['current_label'] as String? ?? 'Unknown';
    final baseUrl = ref.read(dioProvider).options.baseUrl;

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_currentIndex + 1} / ${_images.length}',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _images.length,
                    backgroundColor: const Color(0xFF2A2A3C),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5F75EE)),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Image preview
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3A3A50).withOpacity(0.5), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              '$baseUrl/${image['filepath']}',
              fit: BoxFit.contain,
              width: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.broken_image, size: 80, color: Colors.grey)),
            ),
          ),
        ),

        // Bottom panel
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C28),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current label badge
                Row(
                  children: [
                    const Icon(Icons.label, color: Color(0xFF00C49F), size: 20),
                    const SizedBox(width: 8),
                    const Text('Current Label:', style: TextStyle(color: Colors.white60, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C49F).withOpacity(0.15),
                        border: Border.all(color: const Color(0xFF00C49F), width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentLabel,
                        style: const TextStyle(
                          color: Color(0xFF00C49F),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Text(
                  'Confirm or change the label:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),

                // Label chips
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _labelOptions.map((label) {
                        final isCurrentLabel = label.toLowerCase() == currentLabel.toLowerCase();
                        return ActionChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrentLabel)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.check_circle, size: 16, color: Color(0xFF00C49F)),
                                ),
                              Text(
                                label,
                                style: TextStyle(
                                  fontWeight: isCurrentLabel ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrentLabel ? const Color(0xFF00C49F) : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: isCurrentLabel
                              ? const Color(0xFF00C49F).withOpacity(0.15)
                              : const Color(0xFF252536),
                          side: BorderSide(
                            color: isCurrentLabel ? const Color(0xFF00C49F) : const Color(0xFF3A3A50),
                            width: isCurrentLabel ? 1.5 : 1,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          onPressed: _submitting ? null : () => _submitVote(label),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _skipImage,
                    icon: const Icon(Icons.skip_next, size: 20),
                    label: const Text("Skip — I don't know"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF555566)),
                      foregroundColor: Colors.white60,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
