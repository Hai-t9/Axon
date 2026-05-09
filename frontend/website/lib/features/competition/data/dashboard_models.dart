import 'package:website/features/competition/data/competition_models.dart';

class DashboardImageStats {
  final int total;
  final int verified;
  final int onHold;

  const DashboardImageStats({
    required this.total,
    required this.verified,
    required this.onHold,
  });

  factory DashboardImageStats.fromJson(Map<String, dynamic> json) {
    return DashboardImageStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      onHold: (json['on_hold'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardPhaseInfo {
  final String competitionId;
  final String currentPhase;
  final Map<String, dynamic> phaseDates;

  const DashboardPhaseInfo({
    required this.competitionId,
    required this.currentPhase,
    required this.phaseDates,
  });

  factory DashboardPhaseInfo.fromJson(Map<String, dynamic> json) {
    return DashboardPhaseInfo(
      competitionId: json['competition_id']?.toString() ?? '',
      currentPhase: json['current_phase'] as String? ?? 'Registration',
      phaseDates: json['phase_dates'] as Map<String, dynamic>? ?? {},
    );
  }
}



class LocationMetadata {
  final dynamic imageId;
  final String? gpsInfo;
  final Map<String, dynamic>? locationMetadata;

  const LocationMetadata({
    required this.imageId,
    this.gpsInfo,
    this.locationMetadata,
  });

  factory LocationMetadata.fromJson(Map<String, dynamic> json) {
    return LocationMetadata(
      imageId: json['image_id'],
      gpsInfo: json['gps_info'] as String?,
      locationMetadata: json['location_metadata'] as Map<String, dynamic>?,
    );
  }
}

abstract class DashboardBase {
  final DashboardPhaseInfo phaseInfo;
  final DashboardImageStats imageStats;
  final bool isHost;
  final Map<String, int> deviceStats;
  final Map<String, int> labelDistribution;
  final List<LocationMetadata> locations;

  const DashboardBase({
    required this.phaseInfo,
    required this.imageStats,
    required this.isHost,
    required this.deviceStats,
    required this.labelDistribution,
    required this.locations,
  });

  factory DashboardBase.fromJson(Map<String, dynamic> json) {
    final teamInfo = json['team_info'] as Map<String, dynamic>? ?? {};
    if (teamInfo.containsKey('total')) {
      return DashboardHostResponse.fromJson(json);
    } else {
      return DashboardParticipantResponse.fromJson(json);
    }
  }
}

class DashboardHostTeamInfo {
  final int total;

  const DashboardHostTeamInfo({required this.total});

  factory DashboardHostTeamInfo.fromJson(Map<String, dynamic> json) {
    return DashboardHostTeamInfo(
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardHostResponse extends DashboardBase {
  final CompetitionConfig config;
  final DashboardHostTeamInfo teamInfo;

  const DashboardHostResponse({
    required super.phaseInfo,
    required super.imageStats,
    required super.deviceStats,
    required super.labelDistribution,
    required super.locations,
    required this.config,
    required this.teamInfo,
  }) : super(isHost: true);

  factory DashboardHostResponse.fromJson(Map<String, dynamic> json) {
    final deviceStatsRaw = json['device_stats'] as Map<String, dynamic>? ?? {};
    final labelDistRaw = json['label_distribution'] as Map<String, dynamic>? ?? {};
    final locationsRaw = json['locations'] as List<dynamic>? ?? [];

    return DashboardHostResponse(
      phaseInfo: DashboardPhaseInfo.fromJson(json['phase_info'] as Map<String, dynamic>),
      imageStats: DashboardImageStats.fromJson(json['image_stats'] as Map<String, dynamic>),
      deviceStats: deviceStatsRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      labelDistribution: labelDistRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      locations: locationsRaw.map((e) => LocationMetadata.fromJson(e as Map<String, dynamic>)).toList(),
      config: CompetitionConfig.fromJson(json['config'] as Map<String, dynamic>),
      teamInfo: DashboardHostTeamInfo.fromJson(json['team_info'] as Map<String, dynamic>),
    );
  }
}

class DashboardParticipantConfig {
  final Map<String, dynamic>? labels;
  final String? dataExample;
  final String? overview;
  final String? termsConditions;
  final String? dataMarkdown;
  final String? dataFormat;

  const DashboardParticipantConfig({
    this.labels,
    this.dataExample,
    this.overview,
    this.termsConditions,
    this.dataMarkdown,
    this.dataFormat,
  });

  factory DashboardParticipantConfig.fromJson(Map<String, dynamic> json) {
    return DashboardParticipantConfig(
      labels: json['labels'] as Map<String, dynamic>?,
      dataExample: json['data_ex'] as String?,
      overview: json['overview'] as String?,
      termsConditions: json['terms_conditions'] as String?,
      dataMarkdown: json['data_md'] as String?,
      dataFormat: json['data_format'] as String?,
    );
  }
}

class DashboardParticipantTeam {
  final String id;
  final String name;
  final double score;

  const DashboardParticipantTeam({
    required this.id,
    required this.name,
    required this.score,
  });

  factory DashboardParticipantTeam.fromJson(Map<String, dynamic> json) {
    return DashboardParticipantTeam(
      id: json['id'].toString(),
      name: json['name'] as String? ?? 'Unknown Team',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardParticipantResponse extends DashboardBase {
  final DashboardParticipantConfig config;
  final DashboardParticipantTeam teamInfo;

  const DashboardParticipantResponse({
    required super.phaseInfo,
    required super.imageStats,
    required super.deviceStats,
    required super.labelDistribution,
    required super.locations,
    required this.config,
    required this.teamInfo,
  }) : super(isHost: false);

  factory DashboardParticipantResponse.fromJson(Map<String, dynamic> json) {
    final deviceStatsRaw = json['device_stats'] as Map<String, dynamic>? ?? {};
    final labelDistRaw = json['label_distribution'] as Map<String, dynamic>? ?? {};
    final locationsRaw = json['locations'] as List<dynamic>? ?? [];

    return DashboardParticipantResponse(
      phaseInfo: DashboardPhaseInfo.fromJson(json['phase_info'] as Map<String, dynamic>),
      imageStats: DashboardImageStats.fromJson(json['image_stats'] as Map<String, dynamic>),
      deviceStats: deviceStatsRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      labelDistribution: labelDistRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      locations: locationsRaw.map((e) => LocationMetadata.fromJson(e as Map<String, dynamic>)).toList(),
      config: DashboardParticipantConfig.fromJson(json['config'] as Map<String, dynamic>),
      teamInfo: DashboardParticipantTeam.fromJson(json['team_info'] as Map<String, dynamic>),
    );
  }
}
