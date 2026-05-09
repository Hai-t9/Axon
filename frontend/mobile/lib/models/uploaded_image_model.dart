class UploadedImageModel {
  final String id;
  final String filepath;
  final String status;
  final String? label;
  final String time;

  UploadedImageModel({
    required this.id,
    required this.filepath,
    required this.status,
    this.label,
    required this.time,
  });

  factory UploadedImageModel.fromJson(Map<String, dynamic> json) {
    return UploadedImageModel(
      id: json['id'].toString(),
      filepath: json['filepath'] ?? '',
      status: json['status'] ?? 'unknown',
      label: json['label'],
      time: json['time'] ?? '',
    );
  }
}
