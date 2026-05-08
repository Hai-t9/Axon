class CompetitionModel {
  final String id;
  final String name;
  final String? description;
  final DateTime? launchDate;
  final String? invitationLink;

  const CompetitionModel({
    required this.id,
    required this.name,
    this.description,
    this.launchDate,
    this.invitationLink,
  });

  factory CompetitionModel.fromJson(Map<String, dynamic> json) {
    return CompetitionModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      launchDate: json['launch_date'] != null
          ? DateTime.tryParse(json['launch_date'] as String)
          : null,
      invitationLink: json['invitation_link'] as String?,
    );
  }
}
