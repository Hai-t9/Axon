import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_client.dart';
import 'offline_queue_service.dart';
import 'metadata_service.dart';

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(
    dio: ref.read(dioProvider),
    ref: ref,
  );
});

class UploadService {
  final Dio _dio;
  final Ref _ref;

  UploadService({required Dio dio, required Ref ref})
      : _dio = dio,
        _ref = ref;

  Future<void> uploadImage({
    required String filePath,
    required String teamId,
    required String label,
    ImageMetadata? metadata,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'label': label,
        if (metadata != null) 'metadata': jsonEncode(metadata.toJson()),
      });

      await _dio.post(
        '/api/v1/teams/$teamId/images',
        data: formData,
        onSendProgress: (int sent, int total) {},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final detail = e.response?.data?['detail'] ?? 'Request rejected.';
        throw Exception("Server Rejection: $detail");
      }
      throw Exception(e.message ?? "Upload failed.");
    }
  }

  Future<void> uploadOrQueue({
    required String filePath,
    required String teamId,
    required String label,
    ImageMetadata? metadata,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = !connectivity.contains(ConnectivityResult.none);

    if (!isOnline) {
      _ref.read(offlineQueueProvider.notifier).addToQueue(
        QueuedUpload(
          filePath: filePath,
          teamId: teamId,
          label: label,
          metadata: metadata?.toJson() ?? {},
        ),
      );
      throw Exception('Offline: Saved to queue automatically.');
    }

    try {
      await uploadImage(
        filePath: filePath,
        teamId: teamId,
        label: label,
        metadata: metadata,
      );
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('duplicate') || errorMsg.contains('data collection phase')) {
        throw Exception(e.toString().replaceAll('Exception: Server Rejection: ', ''));
      }
      
      _ref.read(offlineQueueProvider.notifier).addToQueue(
        QueuedUpload(
          filePath: filePath,
          teamId: teamId,
          label: label,
          metadata: metadata?.toJson() ?? {},
        ),
      );
      throw Exception('Upload failed. Saved to offline queue.');
    }
  }
}
