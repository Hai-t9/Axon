class DataValidationItem {
  final String imageId;
  final String? filepath;
  final String? currentLabel;
  final String? collectedBy;

  const DataValidationItem({
    required this.imageId,
    this.filepath,
    this.currentLabel,
    this.collectedBy,
  });

  factory DataValidationItem.fromJson(Map<String, dynamic> json) {
    return DataValidationItem(
      imageId: json['image_id']?.toString() ?? json['id']?.toString() ?? '',
      filepath: json['filepath'] as String?,
      currentLabel: json['current_label'] as String? ?? json['label'] as String?,
      collectedBy: json['collected_by'] as String?,
    );
  }
}

class ValidationProgress {
  final int totalImages;
  final int validatedImages;
  final int pendingImages;
  final double progressPercentage;

  const ValidationProgress({
    this.totalImages = 0,
    this.validatedImages = 0,
    this.pendingImages = 0,
    this.progressPercentage = 0.0,
  });

  factory ValidationProgress.fromJson(Map<String, dynamic> json) {
    return ValidationProgress(
      totalImages: (json['total_images'] as num?)?.toInt() ?? 0,
      validatedImages: (json['validated_images'] as num?)?.toInt() ?? 0,
      pendingImages: (json['pending_images'] as num?)?.toInt() ?? 0,
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
