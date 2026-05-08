class EvaluationResult {
  final String id;
  final String modelId;
  final String? teamName;
  final String protocol;
  final String status;
  final int totalFolds;
  final int completedFolds;
  final double? accuracy;
  final double? precision;
  final double? recall;
  final double? f1Score;
  final String? submittedAt;
  final String? completedAt;

  const EvaluationResult({
    required this.id,
    required this.modelId,
    this.teamName,
    this.protocol = 'standard',
    this.status = 'scheduled',
    this.totalFolds = 0,
    this.completedFolds = 0,
    this.accuracy,
    this.precision,
    this.recall,
    this.f1Score,
    this.submittedAt,
    this.completedAt,
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      id: json['id'].toString(),
      modelId: json['model_id'].toString(),
      teamName: json['team_name'] as String?,
      protocol: json['protocol'] as String? ?? 'standard',
      status: json['status'] as String? ?? 'scheduled',
      totalFolds: (json['total_folds'] as num?)?.toInt() ?? 0,
      completedFolds: (json['completed_folds'] as num?)?.toInt() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      precision: (json['precision'] as num?)?.toDouble(),
      recall: (json['recall'] as num?)?.toDouble(),
      f1Score: (json['f1_score'] as num?)?.toDouble(),
      submittedAt: json['submitted_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }

  double get progress => totalFolds > 0 ? completedFolds / totalFolds : 0;
}
