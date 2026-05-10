import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_client.dart';

enum UploadStatus { queued, uploading, failed }

class QueuedUpload {
  final String filePath;
  final String teamId;
  final String label;
  final Map<String, dynamic> metadata;
  final DateTime queuedAt;
  final UploadStatus status;
  final String? errorMessage;

  QueuedUpload({
    required this.filePath,
    required this.teamId,
    required this.label,
    required this.metadata,
    DateTime? queuedAt,
    this.status = UploadStatus.queued,
    this.errorMessage,
  }) : queuedAt = queuedAt ?? DateTime.now();

  QueuedUpload copyWith({
    String? filePath,
    String? teamId,
    String? label,
    Map<String, dynamic>? metadata,
    DateTime? queuedAt,
    UploadStatus? status,
    String? errorMessage,
  }) {
    return QueuedUpload(
      filePath: filePath ?? this.filePath,
      teamId: teamId ?? this.teamId,
      label: label ?? this.label,
      metadata: metadata ?? this.metadata,
      queuedAt: queuedAt ?? this.queuedAt,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'teamId': teamId,
        'label': label,
        'metadata': metadata,
        'queuedAt': queuedAt.toIso8601String(),
        'status': status.name,
        'errorMessage': errorMessage,
      };

  factory QueuedUpload.fromJson(Map<String, dynamic> json) => QueuedUpload(
        filePath: json['filePath'] as String,
        teamId: json['teamId'] as String,
        label: json['label'] as String,
        metadata: Map<String, dynamic>.from(json['metadata'] as Map),
        queuedAt: DateTime.parse(json['queuedAt'] as String),
        status: json['status'] != null
            ? UploadStatus.values.firstWhere(
                (e) => e.name == json['status'],
                orElse: () => UploadStatus.queued,
              )
            : UploadStatus.queued,
        errorMessage: json['errorMessage'] as String?,
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
        .map((e) => QueuedUpload.fromJson(Map<String, dynamic>.from(e as Map)))
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

  void markFailed(int index, String error) {
    final updated = [...state];
    updated[index] = updated[index].copyWith(
      status: UploadStatus.failed,
      errorMessage: error,
    );
    state = updated;
    _persist();
  }

  void retryUpload(int index) {
    final updated = [...state];
    updated[index] = updated[index].copyWith(
      status: UploadStatus.queued,
      errorMessage: null,
    );
    state = updated;
    _persist();
    processQueue();
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
      final upload = queue[i];
      if (upload.status == UploadStatus.failed) continue;

      _updateStatus(i, UploadStatus.uploading);

      try {
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
      } catch (e) {
        String msg;
        if (e is DioException) {
          msg = e.response?.data?['detail'] ?? e.message ?? 'Upload failed';
        } else {
          msg = e.toString();
        }

        final lower = msg.toLowerCase();
        if (lower.contains('duplicate') || lower.contains('data collection phase')) {
          removeFromQueue(i);
        } else {
          markFailed(i, msg);
        }
      }
    }

    _isProcessing = false;
  }

  void _updateStatus(int index, UploadStatus status) {
    final updated = [...state];
    updated[index] = updated[index].copyWith(status: status);
    state = updated;
    _persist();
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