class TeamModel {
  final String id;
  final String name;
  final String? organization;
  final String competitionId;

  const TeamModel({
    required this.id,
    required this.name,
    this.organization,
    required this.competitionId,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      organization: json['organization'] as String?,
      competitionId: json['competition_id'].toString(),
    );
  }
}
