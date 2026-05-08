class TeamModel {
  final String id;
  final String name;
  final String? organization;
  final String compId;
  final List<String> userIds;

  const TeamModel({
    required this.id,
    required this.name,
    this.organization,
    required this.compId,
    this.userIds = const [],
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      organization: json['organization'] as String?,
      compId: json['comp_id'].toString(),
      userIds: (json['user_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}