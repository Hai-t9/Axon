import 'package:flutter/foundation.dart';

@immutable
class SubmitModelRequest {
  final String teamId;
  final String modelName;
  final String framework;
  final String pythonVersion;
  final String? frameworkVersion;
  final String? description;

  const SubmitModelRequest({
    required this.teamId,
    required this.modelName,
    required this.framework,
    required this.pythonVersion,
    this.frameworkVersion,
    this.description,
  });

  Map<String, String> toQueryParameters() {
    return {
      'team_id': teamId,
      'model_name': modelName,
      'framework': framework,
      'python_version': pythonVersion,
      if (frameworkVersion != null) 'framework_version': frameworkVersion!,
      if (description != null) 'description': description!,
    };
  }
}

@immutable
class SubmitModelResponse {
  final String id;
  final String teamId;
  final String competitionId;
  final String filename;
  final String status;
  final int version;
  final String message;

  const SubmitModelResponse({
    required this.id,
    required this.teamId,
    required this.competitionId,
    required this.filename,
    required this.status,
    required this.version,
    required this.message,
  });

  factory SubmitModelResponse.fromJson(Map<String, dynamic> json) {
    return SubmitModelResponse(
      id: json['id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      competitionId: json['competition_id']?.toString() ?? '',
      filename: json['filename'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'pending',
      version: (json['version'] as num?)?.toInt() ?? 1,
      message: json['message'] as String? ?? 'Model submitted successfully',
    );
  }
}

@immutable
class ModelSpec {
  final List<String> requiredFiles;
  final String modelDir;
  final String dataDir;
  final String inferenceFunction;
  final List<String> allowedModelFormats;
  final List<String> requiredPackages;
  final double maxSizeMb;
  final String? pythonVersionMin;

  const ModelSpec({
    required this.requiredFiles,
    required this.modelDir,
    required this.dataDir,
    required this.inferenceFunction,
    required this.allowedModelFormats,
    required this.requiredPackages,
    required this.maxSizeMb,
    this.pythonVersionMin,
  });

  factory ModelSpec.fromJson(Map<String, dynamic> json) {
    return ModelSpec(
      requiredFiles: List<String>.from(json['required_files'] ?? []),
      modelDir: json['model_dir'] as String? ?? 'model',
      dataDir: json['data_dir'] as String? ?? 'data',
      inferenceFunction: json['inference_function'] as String? ?? 'predict',
      allowedModelFormats: List<String>.from(json['allowed_model_formats'] ?? []),
      requiredPackages: List<String>.from(json['required_packages'] ?? []),
      maxSizeMb: (json['max_size_mb'] as num?)?.toDouble() ?? 500.0,
      pythonVersionMin: json['python_version_min'] as String?,
    );
  }

  factory ModelSpec.defaultSpec() {
    return const ModelSpec(
      requiredFiles: ["Dockerfile", "inference.py", "requirements.txt"],
      modelDir: 'model',
      dataDir: 'data',
      inferenceFunction: 'predict',
      allowedModelFormats: ["pytorch", "tensorflow", "sklearn", "keras", "onnx"],
      requiredPackages: [],
      maxSizeMb: 500.0,
    );
  }
}

@immutable
class ModelSubmission {
  final String id;
  final String teamId;
  final String competitionId;
  final String filename;
  final String status;
  final int version;
  final DateTime submittedAt;
  final String? description;

  const ModelSubmission({
    required this.id,
    required this.teamId,
    required this.competitionId,
    required this.filename,
    required this.status,
    required this.version,
    required this.submittedAt,
    this.description,
  });

  factory ModelSubmission.fromJson(Map<String, dynamic> json) {
    return ModelSubmission(
      id: json['id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      competitionId: json['competition_id']?.toString() ?? '',
      filename: json['filename'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'pending',
      version: (json['version'] as num?)?.toInt() ?? 1,
      submittedAt: json['submitted_at'] != null 
          ? DateTime.parse(json['submitted_at'] as String)
          : DateTime.now(),
      description: json['metadata'] is Map 
          ? json['metadata']['description'] as String?
          : null,
    );
  }
}
