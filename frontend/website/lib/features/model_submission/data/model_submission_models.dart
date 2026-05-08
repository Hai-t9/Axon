class ModelSubmission {
  final String id;
  final String teamId;
  final String competitionId;
  final String filename;
  final String status;
  final int version;
  final String? submittedAt;
  final String? framework;

  const ModelSubmission({
    required this.id,
    required this.teamId,
    required this.competitionId,
    required this.filename,
    required this.status,
    this.version = 1,
    this.submittedAt,
    this.framework,
  });

  factory ModelSubmission.fromJson(Map<String, dynamic> json) {
    return ModelSubmission(
      id: json['id'].toString(),
      teamId: json['team_id'].toString(),
      competitionId: json['competition_id'].toString(),
      filename: json['filename'] as String? ?? '',
      status: json['status'] as String? ?? 'received',
      version: (json['version'] as num?)?.toInt() ?? 1,
      submittedAt: json['submitted_at'] as String?,
      framework: json['framework'] as String?,
    );
  }
}

class ModelSpec {
  final int maxSizeMb;
  final List<String> supportedFormats;

  const ModelSpec({
    this.maxSizeMb = 500,
    this.supportedFormats = const [],
  });

  factory ModelSpec.fromJson(Map<String, dynamic> json) {
    return ModelSpec(
      maxSizeMb: (json['max_size_mb'] as num?)?.toInt() ?? 500,
      supportedFormats: (json['supported_formats'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
