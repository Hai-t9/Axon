class CompetitionConfig {
  const CompetitionConfig({
    required this.id,
    required this.competitionId,
    this.labels,
    this.dataExample,
    this.scoringExample,
    this.overview,
    this.termsConditions,
    this.dataMarkdown,
    this.dataFormat,
    this.evaluation,
    this.duplicateThreshold,
    this.maxValidations,
  });

  final String id;
  final String competitionId;
  final Map<String, dynamic>? labels;
  final String? dataExample;
  final String? scoringExample;
  final String? overview;
  final String? termsConditions;
  final String? dataMarkdown;
  final String? dataFormat;
  final String? evaluation;
  final double? duplicateThreshold;
  final int? maxValidations;

  factory CompetitionConfig.fromJson(Map<String, dynamic> json) {
    return CompetitionConfig(
      id: json['id'].toString(),
      competitionId: json['competition_id'].toString(),
      labels: json['labels'] as Map<String, dynamic>?,
      dataExample: json['data_ex'] as String?,
      scoringExample: json['scoring_ex'] as String?,
      overview: json['overview'] as String?,
      termsConditions: json['terms_conditions'] as String?,
      dataMarkdown: json['data_md'] as String?,
      dataFormat: json['data_format'] as String?,
      evaluation: json['evaluation'] as String?,
      duplicateThreshold: (json['duplicate_threshhold'] as num?)?.toDouble(),
      maxValidations: json['max_validations'] as int?,
    );
  }
}

class Competition {
  const Competition({
    required this.id,
    required this.name,
    this.description,
    this.launchDate,
    this.invitationLink,
    this.config,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime? launchDate;
  final String? invitationLink;
  final CompetitionConfig? config;

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      launchDate: _parseDate(json['launch_date']),
      invitationLink: json['invitation_link'] as String?,
      config: json['config'] == null
          ? null
          : CompetitionConfig.fromJson(json['config'] as Map<String, dynamic>),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class CompetitionList {
  const CompetitionList({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<Competition> items;
  final int total;
  final int page;
  final int limit;

  factory CompetitionList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return CompetitionList(
      items: rawItems
          .map((item) => Competition.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
    );
  }

  factory CompetitionList.empty() {
    return const CompetitionList(items: [], total: 0, page: 1, limit: 20);
  }
}
