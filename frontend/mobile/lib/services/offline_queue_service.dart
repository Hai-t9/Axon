import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_client.dart';

class QueuedUpload {
  final String filePath;
  final String teamId;
  final String label;
  final Map<String, dynamic> metadata;
  final DateTime queuedAt;

  QueuedUpload({
    required this.filePath,
    required this.teamId,
    required this.label,
    required this.metadata,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'teamId': teamId,
        'label': label,
        'metadata': metadata,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory QueuedUpload.fromJson(Map<String, dynamic> json) => QueuedUpload(
        filePath: json['filePath'] as String,
        teamId: json['teamId'] as String,
        label: json['label'] as String,
        metadata: json['metadata'] as Map<String, dynamic>,
        queuedAt: DateTime.parse(json['queuedAt'] as String),
      );
}

class OfflineQueueNotifier extends Notifier<List<QueuedUpload>> {
  late Box _box;
  bool _isProcessing = false;

  @override
  List<QueuedUpload> build() {
    _initBox();
    return _loadFromHive();
  }

  void _initBox() {
    _box = Hive.box('uploadQueue');
  }

  List<QueuedUpload> _loadFromHive() {
    final raw = _box.get('queue', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw
        .map((e) => QueuedUpload.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _persist() {
    _box.put('queue', state.map((e) => e.toJson()).toList());
  }

  void addToQueue(QueuedUpload upload) {
    state = [...state, upload];
    _persist();
  }

  void removeFromQueue(int index) {
    final updated = [...state];
    updated.removeAt(index);
    state = updated;
    _persist();
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    final dio = ref.read(dioProvider);
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = !connectivity.contains(ConnectivityResult.none);

    if (!isOnline) {
      _isProcessing = false;
      return;
    }

    final queue = [...state];
    for (int i = queue.length - 1; i >= 0; i--) {
      try {
        final upload = queue[i];
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            upload.filePath,
            filename: upload.filePath.split('/').last,
          ),
          'label': upload.label,
          if (upload.metadata.isNotEmpty)
            'metadata': jsonEncode(upload.metadata),
        });
        await dio.post(
          '/api/v1/teams/${upload.teamId}/images',
          data: formData,
        );
        removeFromQueue(i);
      } catch (_) {
        // Will retry next time
      }
    }

    _isProcessing = false;
  }

  int get queueLength => state.length;
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, List<QueuedUpload>>(
        OfflineQueueNotifier.new);

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return !results.contains(ConnectivityResult.none);
  });
});

final isOnlineProvider = FutureProvider<bool>((ref) async {
  final results = await Connectivity().checkConnectivity();
  return !results.contains(ConnectivityResult.none);
});
