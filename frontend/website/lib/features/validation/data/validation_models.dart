class ValidationImage {
  final String imageId;
  final String? filepath;
  final String? currentLabel;

  const ValidationImage({
    required this.imageId,
    this.filepath,
    this.currentLabel,
  });

  factory ValidationImage.fromJson(Map<String, dynamic> json) {
    return ValidationImage(
      imageId: json['id']?.toString() ?? json['image_id']?.toString() ?? '',
      filepath: json['filepath'] as String?,
      currentLabel: json['label'] as String?,
    );
  }
}

class ValidationBatch {
  final List<ValidationImage> images;

  const ValidationBatch({required this.images});

  factory ValidationBatch.fromJson(Map<String, dynamic> json) {
    final raw = json['images'] as List<dynamic>? ?? [];
    return ValidationBatch(
      images: raw
          .map((e) => ValidationImage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
