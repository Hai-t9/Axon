class GalleryImage {
  final String id;
  final String filepath;
  final String status;
  final String? label;
  final String time;
  final String? authorName;
  final String teamId;
  final String authorId;
  final String device;

  const GalleryImage({
    required this.id,
    required this.filepath,
    required this.status,
    this.label,
    required this.time,
    this.authorName,
    required this.teamId,
    required this.authorId,
    this.device = 'Unknown',
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      id: json['id'].toString(),
      filepath: json['filepath'] ?? '',
      status: json['status'] ?? 'unknown',
      label: json['label'],
      time: json['time'] ?? '',
      authorName: json['author_name'],
      teamId: json['team_id'].toString(),
      authorId: json['author_id'].toString(),
      device: json['device'] ?? 'Unknown',
    );
  }
}

class TeamMemberStats {
  final String userId;
  final String name;
  final String email;
  final int imagesUploaded;
  final int imagesValidated;

  const TeamMemberStats({
    required this.userId,
    required this.name,
    required this.email,
    required this.imagesUploaded,
    required this.imagesValidated,
  });

  factory TeamMemberStats.fromJson(Map<String, dynamic> json) {
    return TeamMemberStats(
      userId: json['user_id'].toString(),
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      imagesUploaded: json['images_uploaded'] as int? ?? 0,
      imagesValidated: json['images_validated'] as int? ?? 0,
    );
  }

  int get totalContributions => imagesUploaded + imagesValidated;
}

class TeamStats {
  final int totalMembers;
  final int imagesUploaded;
  final int modelsSubmitted;
  final List<TeamMemberStats> members;

  const TeamStats({
    required this.totalMembers,
    required this.imagesUploaded,
    required this.modelsSubmitted,
    this.members = const [],
  });

  factory TeamStats.fromJson(Map<String, dynamic> json) {
    final membersList = json['members'] as List<dynamic>? ?? [];
    return TeamStats(
      totalMembers: json['total_members'] as int? ?? 0,
      imagesUploaded: json['images_uploaded'] as int? ?? 0,
      modelsSubmitted: json['models_submitted'] as int? ?? 0,
      members: membersList
          .map((m) => TeamMemberStats.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GalleryData {
  final TeamStats stats;
  final List<GalleryImage> images;
  final int totalImages;

  const GalleryData({
    required this.stats,
    required this.images,
    required this.totalImages,
  });
}
