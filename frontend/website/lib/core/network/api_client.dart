import 'dart:async';
import 'dart:convert';
import 'package:http_parser/http_parser.dart' as parser;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    client: ref.watch(httpClientProvider),
  );
});

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(_normalize(baseUrl, path));
    final response = await _client.post(
      uri,
      headers: _mergeHeaders(headers),
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(500, 'Unexpected response format');
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(_normalize(baseUrl, path));
    final response = await _client.get(
      uri,
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(500, 'Unexpected response format');
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(_normalize(baseUrl, path));
    final response = await _client.put(
      uri,
      headers: _mergeHeaders(headers),
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(500, 'Unexpected response format');
  }

  Future<List<int>> getBytes(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(_normalize(baseUrl, path));
    final response = await _client.get(
      uri,
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    return response.bodyBytes;
  }

  Future<void> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(_normalize(baseUrl, path));
    final response = await _client.delete(
      uri,
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
    Map<String, String>? fields,
    Map<String, String>? headers,
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = Uri.parse(_normalize(baseUrl, path));
    final request = _MultipartRequestWithProgress(
      'POST',
      uri,
      onProgress: onProgress,
    );

    if (headers != null) request.headers.addAll(headers);
    if (fields != null) request.fields.addAll(fields);

    final ext = fileName.split('.').last.toLowerCase();
    request.files.add(http.MultipartFile.fromBytes(
      fileField,
      fileBytes,
      filename: fileName,
      contentType: _mediaTypeForExtension(ext),
    ));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException(500, 'Unexpected response format');
  }

  parser.MediaType? _mediaTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return parser.MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return parser.MediaType('image', 'jpeg');
      case 'svg':
        return parser.MediaType('image', 'svg+xml');
      default:
        return null;
    }
  }

  String _normalize(String base, String path) {
    final baseTrimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final pathTrimmed = path.startsWith('/') ? path : '/$path';
    return '$baseTrimmed$pathTrimmed';
  }

  String _parseError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'] ?? decoded['message'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {}
    return 'Request failed. Please try again.';
  }

  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    final baseHeaders = {'Content-Type': 'application/json'};
    if (headers == null || headers.isEmpty) {
      return baseHeaders;
    }
    return {...baseHeaders, ...headers};
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class _MultipartRequestWithProgress extends http.MultipartRequest {
  _MultipartRequestWithProgress(
    super.method,
    super.url, {
    this.onProgress,
  });

  final void Function(int bytes, int totalBytes)? onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    int bytes = 0;

    final t = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes += data.length;
        onProgress!(bytes, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(t));
  }
}
