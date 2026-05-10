import 'package:flutter/foundation.dart';

@immutable
class ModelFormState {
  final String modelName;
  final String framework;
  final String pythonVersion;
  final String? frameworkVersion;
  final String? description;
  final List<int>? fileBytes;
  final String? fileName;
  final String? error;
  final bool isSubmitting;
  final double uploadProgress;

  const ModelFormState({
    this.modelName = '',
    this.framework = 'pytorch',
    this.pythonVersion = '3.10',
    this.frameworkVersion,
    this.description,
    this.fileBytes,
    this.fileName,
    this.error,
    this.isSubmitting = false,
    this.uploadProgress = 0.0,
  });

  ModelFormState copyWith({
    String? modelName,
    String? framework,
    String? pythonVersion,
    String? frameworkVersion,
    String? description,
    List<int>? fileBytes,
    String? fileName,
    String? error,
    bool? isSubmitting,
    double? uploadProgress,
  }) {
    return ModelFormState(
      modelName: modelName ?? this.modelName,
      framework: framework ?? this.framework,
      pythonVersion: pythonVersion ?? this.pythonVersion,
      frameworkVersion: frameworkVersion ?? this.frameworkVersion,
      description: description ?? this.description,
      fileBytes: fileBytes ?? this.fileBytes,
      fileName: fileName ?? this.fileName,
      error: error ?? this.error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  bool get isValid => 
    modelName.isNotEmpty && 
    framework.isNotEmpty && 
    pythonVersion.isNotEmpty && 
    fileBytes != null && 
    fileName != null;
}
