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
  bool _exportingTeamZip = false;
  bool _exportingFull = false;
  bool _exportingFullZip = false;
  String? _teamError;
  String? _teamZipError;
  String? _fullError;
  String? _fullZipError;

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

  Future<void> _doExportTeamZip() async {
    setState(() {
      _exportingTeamZip = true;
      _teamZipError = null;
    });
    try {
      final repo = ref.read(exportRepositoryProvider);
      await repo.downloadTeamDataset(widget.competitionId);
    } on ApiException catch (e) {
      setState(() => _teamZipError = e.message);
    } catch (e) {
      setState(() => _teamZipError = e.toString());
    } finally {
      if (mounted) setState(() => _exportingTeamZip = false);
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

  Future<void> _doExportFullZip() async {
    setState(() {
      _exportingFullZip = true;
      _fullZipError = null;
    });
    try {
      final repo = ref.read(exportRepositoryProvider);
      await repo.downloadFullDataset(widget.competitionId);
    } on ApiException catch (e) {
      setState(() => _fullZipError = e.message);
    } catch (e) {
      setState(() => _fullZipError = e.toString());
    } finally {
      if (mounted) setState(() => _exportingFullZip = false);
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
        _buildTeamSection(),
        const SizedBox(height: AppSpacing.lg),
        _buildFullSection(),
      ]),
    );
  }

  Widget _buildTeamSection() {
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
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.cloud_download, color: AppColors.accent, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Export Your Team Data',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            const Text('Download all images, labels, and validation records '
                'for your team in JSON format. Available after the Data Validation phase.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
            _buildButtonRow(
              label: 'JSON Metadata',
              icon: Icons.description,
              loading: _exportingTeam,
              error: _teamError,
              onPressed: _doExportTeam,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildButtonRow(
              label: 'Dataset (Images + Labels)',
              icon: Icons.folder_zip,
              loading: _exportingTeamZip,
              error: _teamZipError,
              onPressed: _doExportTeamZip,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullSection() {
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
                    color: AppColors.primaryDark.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.download_for_offline, color: AppColors.primaryDark, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Export All Data (Host Only)',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            const Text('Download all teams images, labels, validation records, '
                'and image metadata (EXIF, camera info, GPS, etc.) in JSON format. '
                'Requires host privileges.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
            _buildButtonRow(
              label: 'JSON Metadata',
              icon: Icons.description,
              loading: _exportingFull,
              error: _fullError,
              onPressed: _doExportFull,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildButtonRow(
              label: 'Dataset (Images + Labels)',
              icon: Icons.folder_zip,
              loading: _exportingFullZip,
              error: _fullZipError,
              onPressed: _doExportFullZip,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow({
    required String label,
    required IconData icon,
    required bool loading,
    String? error,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
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
    );
  }
}
