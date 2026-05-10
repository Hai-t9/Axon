import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/competition_service.dart';

class DataValidationScreen extends ConsumerStatefulWidget {
  final String competitionId;
  final String competitionName;

  const DataValidationScreen({
    super.key,
    required this.competitionId,
    required this.competitionName,
  });

  @override
  ConsumerState<DataValidationScreen> createState() => _DataValidationScreenState();
}

class _DataValidationScreenState extends ConsumerState<DataValidationScreen> {
  List<Map<String, dynamic>> _images = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSkipping = false;
  bool _isComplete = false;
  String? _error;
  List<String> _labels = [];
  String? _selectedLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final service = ref.read(competitionServiceProvider);
      final labelResult = await service.getCompetitionLabels(widget.competitionId);
      final listResult = await service.getValidationList(widget.competitionId);
      if (!mounted) return;
      setState(() {
        _labels = labelResult ?? [];
        _images = List<Map<String, dynamic>>.from(listResult['images'] as List? ?? []);
        _currentIndex = 0;
        _isLoading = false;
        if (_images.isEmpty) {
          _isComplete = true;
        } else {
          _selectedLabel = _images[0]['current_label'] as String?;
        }
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Map<String, dynamic>? get _currentImage =>
      _images.isNotEmpty && _currentIndex < _images.length
          ? _images[_currentIndex]
          : null;

  Future<void> _submitVote() async {
    if (_currentImage == null || _isSubmitting) return;
    if (_selectedLabel == null || _selectedLabel!.isEmpty) {
      _showError('Please select a label before confirming.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(competitionServiceProvider);
      await service.submitVote(_currentImage!['image_id'].toString(), _selectedLabel!);
      if (!mounted) return;
      _showSuccess('Label confirmed!');
      _next();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _skipImage() async {
    if (_currentImage == null || _isSkipping) return;
    setState(() => _isSkipping = true);
    try {
      final service = ref.read(competitionServiceProvider);
      await service.skipImage(_currentImage!['image_id'].toString());
      if (!mounted) return;
      _showSuccess('Image skipped.');
      _next();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSkipping = false);
    }
  }

  void _next() {
    if (_currentIndex + 1 < _images.length) {
      setState(() {
        _currentIndex++;
        _selectedLabel = _images[_currentIndex]['current_label'] as String?;
      });
    } else {
      setState(() => _isComplete = true);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF33E1A6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _buildImageUrl(String filepath) {
    var base = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final normalized = filepath.replaceAll('\\', '/');
    if (normalized.startsWith('http')) return normalized;
    return '$base/$normalized';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C28),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252536),
        title: const Text('Validation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5F75EE)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5F75EE)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_isComplete) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF33E1A6), Color(0xFF2BC48E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.celebration_rounded, size: 40, color: Color(0xFF1C1C28)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Validation Complete!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _images.isEmpty
                  ? 'No images were assigned for validation.'
                  : 'You have validated all ${_images.length} images.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Dashboard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Color(0xFF3A3A50)),
              ),
            ),
          ],
        ),
      );
    }

    final image = _currentImage!;
    final total = _images.length;
    final current = _currentIndex + 1;
    final progress = total > 0 ? current / total : 0.0;
    final filepath = image['filepath'] as String? ?? '';
    final currentLabel = image['current_label'] as String? ?? '';
    final imageId = image['image_id'].toString();

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252536),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A3A50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Image $current of $total',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5F75EE).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFF5F75EE),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5F75EE)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Image and validation content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    _buildImageUrl(filepath),
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 280,
                      color: const Color(0xFF252536),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
                      ),
                    ),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 280,
                        color: const Color(0xFF252536),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: const Color(0xFF5F75EE),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Image info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C28),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'ID: $imageId',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (currentLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A53C).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.label_outline, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              currentLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Label selection
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Label',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose the correct label for this image',
                        style: TextStyle(fontSize: 13, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildLabelGrid(),
              ],
            ),
          ),
        ),
        // Bottom actions
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF252536),
            border: Border(top: BorderSide(color: Color(0xFF3A3A50))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isSubmitting || _isSkipping) ? null : _skipImage,
                  icon: _isSkipping
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.skip_next_rounded),
                  label: Text(_isSkipping ? 'Skipping...' : 'Skip'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0xFF3A3A50)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || _isSkipping) ? null : _submitVote,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1C1C28),
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Confirm Vote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedLabel != null
                        ? const Color(0xFF5F75EE)
                        : Colors.white24,
                    foregroundColor: const Color(0xFF1C1C28),
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: const Color(0xFF1C1C28).withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelGrid() {
    final labels = _labels.isNotEmpty
        ? _labels
        : (currentLabel != null && currentLabel!.isNotEmpty ? [currentLabel!] : <String>[]);

    if (labels.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF252536),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3A50)),
        ),
        child: const Text(
          'No labels configured for this competition.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: labels.map((label) {
        final isSelected = _selectedLabel == label;
        return GestureDetector(
          onTap: () => setState(() => _selectedLabel = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF5F75EE).withOpacity(0.12)
                  : const Color(0xFF252536),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF5F75EE) : const Color(0xFF3A3A50),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF5F75EE)),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    color: isSelected ? const Color(0xFF5F75EE) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String? get currentLabel => _currentImage?['current_label'] as String?;
}
