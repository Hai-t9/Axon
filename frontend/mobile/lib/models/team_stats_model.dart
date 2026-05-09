class TeamStatsModel {
  final int totalMembers;
  final int imagesUploaded;
  final int modelsSubmitted;
  final List<MemberStatsModel> members;

  const TeamStatsModel({
    required this.totalMembers,
    required this.imagesUploaded,
    required this.modelsSubmitted,
    this.members = const [],
  });

  factory TeamStatsModel.fromJson(Map<String, dynamic> json) {
    final membersList = json['members'] as List<dynamic>? ?? [];
    return TeamStatsModel(
      totalMembers: json['total_members'] as int? ?? 0,
      imagesUploaded: json['images_uploaded'] as int? ?? 0,
      modelsSubmitted: json['models_submitted'] as int? ?? 0,
      members: membersList
          .map((m) => MemberStatsModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MemberStatsModel {
  final String userId;
  final String name;
  final String email;
  final int imagesUploaded;
  final int imagesValidated;

  const MemberStatsModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.imagesUploaded,
    required this.imagesValidated,
  });

  factory MemberStatsModel.fromJson(Map<String, dynamic> json) {
    return MemberStatsModel(
      userId: json['user_id'].toString(),
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      imagesUploaded: json['images_uploaded'] as int? ?? 0,
      imagesValidated: json['images_validated'] as int? ?? 0,
    );
  }

  int get totalContributions => imagesUploaded + imagesValidated;
}
