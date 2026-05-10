class ValidationImage {
  final String imageId;
  final String? filepath;
  final String? imageUrl;
  final String? currentLabel;

  const ValidationImage({
    required this.imageId,
    this.filepath,
    this.imageUrl,
    this.currentLabel,
  });

  factory ValidationImage.fromJson(Map<String, dynamic> json) {
    final id = json['image_id'] ?? json['id'];
    return ValidationImage(
      imageId: id?.toString() ?? '',
      filepath: json['filepath'] as String?,
      imageUrl: json['image_url'] as String?,
      currentLabel: (json['current_label'] ?? json['label']) as String?,
    );
  }
}

class ValidationListResponse {
  final List<ValidationImage> images;

  const ValidationListResponse({required this.images});

  factory ValidationListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['images'] as List<dynamic>? ?? [];
    return ValidationListResponse(
      images: raw
          .map((e) => ValidationImage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ValidationVoteResponse {
  final bool success;
  final String message;

  const ValidationVoteResponse({
    required this.success,
    required this.message,
  });

  factory ValidationVoteResponse.fromJson(Map<String, dynamic> json) {
    return ValidationVoteResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class ValidationPendingImage {
  final String id;
  final String filepath;
  final String label;

  const ValidationPendingImage({
    required this.id,
    required this.filepath,
    required this.label,
  });

  factory ValidationPendingImage.fromJson(Map<String, dynamic> json) {
    return ValidationPendingImage(
      id: json['id']?.toString() ?? '',
      filepath: json['filepath'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}
