import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gallery_models.dart';
import '../data/gallery_repository.dart';

final galleryTeamIdProvider = FutureProvider.family<String?, String>((ref, competitionId) async {
  final repo = ref.read(galleryRepositoryProvider);
  return repo.getMyTeamId(competitionId);
});

final galleryTeamStatsProvider = FutureProvider.family<TeamStats?, String>((ref, teamId) async {
  final repo = ref.read(galleryRepositoryProvider);
  try {
    return await repo.getTeamStats(teamId);
  } catch (_) {
    return null;
  }
});

final galleryImagesProvider =
    FutureProvider.family<GalleryImageList, GalleryImagesParams>((ref, params) async {
  final repo = ref.read(galleryRepositoryProvider);
  return repo.getTeamImages(
    teamId: params.teamId,
    status: params.status,
    authorId: params.authorId,
    label: params.label,
    limit: 200,
  );
});

class GalleryImagesParams {
  final String teamId;
  final String? status;
  final String? authorId;
  final String? label;

  const GalleryImagesParams({
    required this.teamId,
    this.status,
    this.authorId,
    this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryImagesParams &&
          teamId == other.teamId &&
          status == other.status &&
          authorId == other.authorId &&
          label == other.label;

  @override
  int get hashCode => Object.hash(teamId, status, authorId, label);
}
