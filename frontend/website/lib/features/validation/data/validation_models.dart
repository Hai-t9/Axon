/// Represents a single image to be validated, with its display data.
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
    final id = json['id'];
    return ValidationImage(
      imageId: id is String ? id : (id is num ? id.toString() : ''),
      filepath: json['filepath'] as String?,
      imageUrl: json['image_url'] as String?,
      currentLabel: json['label'] as String?,
    );
  }
}

/// The response from GET /competitions/:compId/validations/list
/// Contains only image IDs — the frontend fetches details per image.
class ValidationListResponse {
  final List<String> imageIds;

  const ValidationListResponse({required this.imageIds});

  factory ValidationListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['image_ids'] as List<dynamic>? ?? [];
    return ValidationListResponse(
      imageIds: raw.map((e) => e as String).toList(),
    );
  }
}

/// The response from POST /images/:imageId/validations
class ValidationVoteResponse {
  final int validationId;
  final String label;

  const ValidationVoteResponse({
    required this.validationId,
    required this.label,
  });

  factory ValidationVoteResponse.fromJson(Map<String, dynamic> json) {
    return ValidationVoteResponse(
      validationId: (json['validation_id'] as num).toInt(),
      label: json['label'] as String,
    );
  }
}

/// Pending validation image (from GET /competitions/:compId/validations/pending)
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
