import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/export_models.dart';
import '../data/export_repository.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key, required this.competitionId});

  static const routeName = 'export';
  static const routePath = '/competitions/:id/export';
  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/export';

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool _exportingTeam = false;
  bool _exportingFull = false;
  String? _teamError;
  String? _fullError;

  Future<void> _doExportTeam() async {
    setState(() {
      _exportingTeam = true;
      _teamError = null;
    });
    try {
      final repo = ref.read(exportRepositoryProvider);
      final data = await repo.exportTeamData(widget.competitionId);
      _downloadJson(data, 'team_export.json');
    } on ApiException catch (e) {
      setState(() => _teamError = e.message);
    } catch (e) {
      setState(() => _teamError = e.toString());
    } finally {
      if (mounted) setState(() => _exportingTeam = false);
    }
  }

  Future<void> _doExportFull() async {
    setState(() {
      _exportingFull = true;
      _fullError = null;
    });
    try {
      final repo = ref.read(exportRepositoryProvider);
      final data = await repo.exportFullData(widget.competitionId);
      _downloadJson(data, 'full_export.json');
    } on ApiException catch (e) {
      setState(() => _fullError = e.message);
    } catch (e) {
      setState(() => _fullError = e.toString());
    } finally {
      if (mounted) setState(() => _exportingFull = false);
    }
  }

  void _downloadJson(ExportResponse data, String filename) {
    final json = {
      'type': data.type,
      'phase': data.phase,
      'phase_label': data.phaseLabel,
      'exported_at': DateTime.now().toIso8601String(),
      'total_images': data.totalImages,
      'total_teams': data.totalTeams,
      'images': data.images.map((img) => {
        'id': img.id,
        'team_id': img.teamId,
        'team_name': img.teamName,
        'author_id': img.authorId,
        'author_name': img.authorName,
        'filepath': img.filepath,
        'original_filename': img.originalFilename,
        'label': img.label,
        'status': img.status,
        'device': img.device,
        'time': img.time,
        'image_hash': img.imageHash,
      }).toList(),
      'labels': data.labels.map((lb) => {
        'image_id': lb.imageId,
        'label': lb.label,
        'validated': lb.validated,
        'validations': lb.validations.map((v) => {
          'validator_id': v.validatorId,
          'label': v.label,
          'validated_at': v.validatedAt,
        }).toList(),
      }).toList(),
      if (data.metadata != null)
        'metadata': data.metadata!.map((m) => {
          'image_id': m.imageId,
          if (m.gpsInfo != null) 'gps_info': m.gpsInfo,
          if (m.make != null) 'make': m.make,
          if (m.cameraModel != null) 'camera_model': m.cameraModel,
          if (m.software != null) 'software': m.software,
          if (m.orientation != null) 'orientation': m.orientation,
          if (m.dateTime != null) 'date_time': m.dateTime,
          if (m.imageWidth != null) 'image_width': m.imageWidth,
          if (m.imageLength != null) 'image_length': m.imageLength,
          if (m.newWidth != null) 'new_width': m.newWidth,
          if (m.newHeight != null) 'new_height': m.newHeight,
          if (m.englishName != null) 'english_name': m.englishName,
          if (m.scientificName != null) 'scientific_name': m.scientificName,
        }).toList(),
    };

    final blob = html.Blob([jsonEncode(json)], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    (html.document.createElement('a') as html.AnchorElement)
      ..href = url
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return AxonScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: PageHeader(title: 'Data Export',
                  subtitle: 'Export images, labels, and metadata for analysis')),
        ]),
        const SizedBox(height: AppSpacing.xl),
        _buildSectionCard(
          icon: Icons.cloud_download,
          title: 'Export Your Team Data',
          description: 'Download all images, labels, and validation records '
              'for your team in JSON format. Available after the Data Validation phase.',
          color: AppColors.accent,
          loading: _exportingTeam,
          error: _teamError,
          onExport: _doExportTeam,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionCard(
          icon: Icons.download_for_offline,
          title: 'Export All Data (Host Only)',
          description: 'Download all teams images, labels, validation records, '
              'and image metadata (EXIF, camera info, GPS, etc.) in JSON format. '
              'Requires host privileges.',
          color: AppColors.primaryDark,
          loading: _exportingFull,
          error: _fullError,
          onExport: _doExportFull,
        ),
      ]),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool loading,
    String? error,
    required VoidCallback onExport,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(description,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
            if (loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator()))
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download, size: 20),
                  label: const Text('Download JSON',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(error,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
