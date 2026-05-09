class TeamModel {
  final String id;
  final String name;
  final String? organization;
  final String compId;
  final Map<String, int> userEmails;

  const TeamModel({
    required this.id,
    required this.name,
    this.organization,
    required this.compId,
    this.userEmails = const {},
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    final raw = json['user_emails'] as Map<String, dynamic>?;
    return TeamModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      organization: json['organization'] as String?,
      compId: json['comp_id'].toString(),
      userEmails: raw?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}