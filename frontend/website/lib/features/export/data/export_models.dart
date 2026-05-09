class ExportImage {
  final String id;
  final String teamId;
  final String teamName;
  final String authorId;
  final String? authorName;
  final String filepath;
  final String? originalFilename;
  final String? label;
  final String status;
  final String? device;
  final String? time;
  final String imageHash;

  const ExportImage({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.authorId,
    this.authorName,
    required this.filepath,
    this.originalFilename,
    this.label,
    required this.status,
    this.device,
    this.time,
    required this.imageHash,
  });

  factory ExportImage.fromJson(Map<String, dynamic> json) {
    return ExportImage(
      id: json['id'].toString(),
      teamId: json['team_id'].toString(),
      teamName: json['team_name'] as String? ?? '',
      authorId: json['author_id'].toString(),
      authorName: json['author_name'] as String?,
      filepath: json['filepath'] as String? ?? '',
      originalFilename: json['original_filename'] as String?,
      label: json['label'] as String?,
      status: json['status'] as String? ?? '',
      device: json['device'] as String?,
      time: json['time'] as String?,
      imageHash: json['image_hash'] as String? ?? '',
    );
  }
}

class ExportValidation {
  final String validatorId;
  final String label;
  final String? validatedAt;

  const ExportValidation({
    required this.validatorId,
    required this.label,
    this.validatedAt,
  });

  factory ExportValidation.fromJson(Map<String, dynamic> json) {
    return ExportValidation(
      validatorId: json['validator_id'].toString(),
      label: json['label'] as String? ?? '',
      validatedAt: json['validated_at'] as String?,
    );
  }
}

class ExportLabel {
  final String imageId;
  final String label;
  final bool validated;
  final List<ExportValidation> validations;

  const ExportLabel({
    required this.imageId,
    required this.label,
    required this.validated,
    this.validations = const [],
  });

  factory ExportLabel.fromJson(Map<String, dynamic> json) {
    final validationsList = json['validations'] as List<dynamic>? ?? [];
    return ExportLabel(
      imageId: json['image_id'].toString(),
      label: json['label'] as String? ?? '',
      validated: json['validated'] as bool? ?? false,
      validations: validationsList
          .map((v) => ExportValidation.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExportMetadata {
  final String imageId;
  final String? gpsInfo;
  final String? make;
  final String? cameraModel;
  final String? software;
  final double? orientation;
  final String? dateTime;
  final double? imageWidth;
  final double? imageLength;
  final double? newWidth;
  final double? newHeight;
  final String? englishName;
  final String? scientificName;

  const ExportMetadata({
    required this.imageId,
    this.gpsInfo,
    this.make,
    this.cameraModel,
    this.software,
    this.orientation,
    this.dateTime,
    this.imageWidth,
    this.imageLength,
    this.newWidth,
    this.newHeight,
    this.englishName,
    this.scientificName,
  });

  factory ExportMetadata.fromJson(Map<String, dynamic> json) {
    return ExportMetadata(
      imageId: json['image_id'].toString(),
      gpsInfo: json['gps_info'] as String?,
      make: json['make'] as String?,
      cameraModel: json['camera_model'] as String?,
      software: json['software'] as String?,
      orientation: (json['orientation'] as num?)?.toDouble(),
      dateTime: json['date_time'] as String?,
      imageWidth: (json['image_width'] as num?)?.toDouble(),
      imageLength: (json['image_length'] as num?)?.toDouble(),
      newWidth: (json['new_width'] as num?)?.toDouble(),
      newHeight: (json['new_height'] as num?)?.toDouble(),
      englishName: json['english_name'] as String?,
      scientificName: json['scientific_name'] as String?,
    );
  }
}

class ExportResponse {
  final String type;
  final String phase;
  final String phaseLabel;
  final List<ExportImage> images;
  final List<ExportLabel> labels;
  final List<ExportMetadata>? metadata;
  final int totalImages;
  final int totalTeams;

  const ExportResponse({
    required this.type,
    required this.phase,
    required this.phaseLabel,
    required this.images,
    this.labels = const [],
    this.metadata,
    required this.totalImages,
    required this.totalTeams,
  });

  factory ExportResponse.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] as List<dynamic>? ?? [];
    final labelsList = json['labels'] as List<dynamic>? ?? [];
    final metadataList = json['metadata'] as List<dynamic>?;
    return ExportResponse(
      type: json['type'] as String? ?? '',
      phase: json['phase'] as String? ?? '',
      phaseLabel: json['phase_label'] as String? ?? '',
      images: imagesList
          .map((i) => ExportImage.fromJson(i as Map<String, dynamic>))
          .toList(),
      labels: labelsList
          .map((l) => ExportLabel.fromJson(l as Map<String, dynamic>))
          .toList(),
      metadata: metadataList
          ?.map((m) => ExportMetadata.fromJson(m as Map<String, dynamic>))
          .toList(),
      totalImages: json['total_images'] as int? ?? 0,
      totalTeams: json['total_teams'] as int? ?? 0,
    );
  }
}
