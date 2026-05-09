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
  List<Map<String, dynamic>> _queue = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<String> _labels = [];
  Map<String, dynamic>? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(competitionServiceProvider);
      final labelResult = await service.getCompetitionLabels(widget.competitionId);
      final queueResult = await service.getDataValidationQueue(widget.competitionId);
      final progressResult = await service.getDataValidationProgress(widget.competitionId);
      if (mounted) {
        setState(() {
          _labels = labelResult ?? [];
          _queue = List<Map<String, dynamic>>.from(queueResult['images'] as List? ?? []);
          _currentIndex = 0;
          _progress = progressResult;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, dynamic>? get _currentImage =>
      _queue.isNotEmpty && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  Future<void> _validate() async {
    if (_currentImage == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final service = ref.read(competitionServiceProvider);
      await service.validateImage(widget.competitionId, _currentImage!['image_id'] as int);
      _next();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skip() async {
    if (_currentImage == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final service = ref.read(competitionServiceProvider);
      await service.skipImage(widget.competitionId, _currentImage!['image_id'] as int);
      _next();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _next() {
    if (_currentIndex + 1 < _queue.length) {
      setState(() => _currentIndex++);
    } else {
      setState(() { _queue = []; _currentIndex = 0; });
      _load();
    }
  }

  void _showCorrectionDialog() async {
    if (_currentImage == null || _labels.isEmpty) return;
    final currentLabel = _currentImage!['current_label'] as String? ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _CorrectLabelDialog(
        labels: _labels,
        currentLabel: currentLabel,
      ),
    );
    if (result != null && result != currentLabel) {
      setState(() => _submitting = true);
      try {
        final service = ref.read(competitionServiceProvider);
        await service.correctLabel(
          widget.competitionId,
          _currentImage!['image_id'] as int,
          result,
        );
        _next();
      } catch (e) {
        if (mounted) _showError(e.toString());
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C28),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252536),
        title: const Text('Data Validation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
    if (_currentImage == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF33E1A6), size: 64),
            SizedBox(height: 16),
            Text(
              'All images validated!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final image = _currentImage!;
    final progress = _queue.isEmpty ? 1.0 : (_currentIndex / _queue.length);
    final filepath = image['filepath'] as String? ?? '';
    final currentLabel = image['current_label'] as String? ?? '';
    final imageUrl = '${ApiConfig.baseUrl}/$filepath';

    return Column(
      children: [
        if (_progress != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    Text(
                      '${_progress?['validated_images'] ?? 0}/${_progress?['total_images'] ?? 0}',
                      style: const TextStyle(color: Color(0xFF5F75EE), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ((_progress?['progress_percentage'] as num?)?.toDouble() ?? 0.0) / 100.0,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5F75EE)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
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
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252536),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3A3A50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Label',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F75EE).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentLabel,
                          style: const TextStyle(
                            color: Color(0xFF5F75EE),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
                  onPressed: _submitting ? null : _skip,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Skip'),
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
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _validate,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Validate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF33E1A6),
                    foregroundColor: const Color(0xFF1C1C28),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _showCorrectionDialog,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Correct'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A53C),
                    foregroundColor: const Color(0xFF1C1C28),
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
}

class _CorrectLabelDialog extends StatefulWidget {
  final List<String> labels;
  final String currentLabel;

  const _CorrectLabelDialog({required this.labels, required this.currentLabel});

  @override
  State<_CorrectLabelDialog> createState() => _CorrectLabelDialogState();
}

class _CorrectLabelDialogState extends State<_CorrectLabelDialog> {
  late String _selected;
  final _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentLabel;
    _filtered = widget.labels;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = widget.labels
          .where((l) => l.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF252536),
      title: const Text('Correct Label', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search labels...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: const Color(0xFF1C1C28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _filtered.map((label) {
                  final isCurrent = label == widget.currentLabel;
                  final isSelected = label == _selected;
                  return ListTile(
                    title: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF5F75EE) : Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    leading: isCurrent
                        ? const Icon(Icons.lock, color: Colors.white38, size: 18)
                        : isSelected
                            ? const Icon(Icons.radio_button_checked, color: Color(0xFF5F75EE), size: 20)
                            : const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 20),
                    onTap: isCurrent ? null : () => setState(() => _selected = label),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          onPressed: _selected == widget.currentLabel
              ? null
              : () => Navigator.of(context).pop(_selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE5A53C),
            foregroundColor: const Color(0xFF1C1C28),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
