import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final uploadServiceProvider = Provider<UploadService>((ref) {
  final dio = ref.watch(dioProvider);
  return UploadService(dio);
});

class UploadService {
  final Dio _dio;

  UploadService(this._dio);

  Future<void> uploadImage(String filePath, String teamId, Map<String, dynamic> labelPayload) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'label': jsonEncode(labelPayload), // Field name must match backend's Form(None) param
      });

      final response = await _dio.post(
        '/api/v1/teams/$teamId/images',
        data: formData,
        onSendProgress: (int sent, int total) {
          // Can hook up to Riverpod state for progress bar
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return; // Success
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final detail = e.response?.data?['detail'] ?? 'Request rejected by server.';
        throw Exception("Server Rejection: $detail");
      }
      throw Exception(e.message ?? "An error occurred during upload.");
    }
  }
}

