import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/gallery_models.dart';
import '../data/gallery_repository.dart';
import '../state/gallery_controller.dart';

class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key, required this.competitionId});

  static const routeName = 'gallery';
  static const routePath = '/competitions/:id/gallery';
  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/gallery';

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  String? _statusFilter;
  String? _authorFilter;
  String? _labelFilter;

  String _getImageUrl(String filepath) {
    var base = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final normalizedPath = filepath.replaceAll('\\', '/');
    if (normalizedPath.startsWith('http')) return normalizedPath;
    if (!normalizedPath.startsWith('uploads/')) return '$base/uploads/$normalizedPath';
    return '$base/$normalizedPath';
  }

  void _showImageDetail(GalleryImage image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Image Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    tooltip: 'Delete image',
                    onPressed: () { Navigator.pop(ctx); _confirmDelete(image); },
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ]),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_getImageUrl(image.filepath), height: 320, width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                        height: 320,
                        color: AppColors.background,
                        child: const Center(
                            child: Icon(Icons.broken_image, size: 64, color: AppColors.textSecondary)))),
              ),
              const SizedBox(height: AppSpacing.lg),
              _detailRow('Status', image.status.toUpperCase(),
                  color: image.status == 'verified' ? AppColors.success : AppColors.primaryDark),
              const SizedBox(height: AppSpacing.sm),
              _detailRow('Label', image.label ?? 'Unlabeled',
                  color: image.label != null ? Colors.amber : AppColors.textSecondary),
              const SizedBox(height: AppSpacing.sm),
              _detailRow('Uploaded by', image.authorName ?? 'Unknown'),
              const SizedBox(height: AppSpacing.sm),
              _detailRow('Device', image.device),
              const SizedBox(height: AppSpacing.sm),
              _detailRow('Date', image.time.split('T').first),
              const SizedBox(height: AppSpacing.sm),
              _detailRow('Image ID', image.id),
            ]),
          )),
    );
  }

  void _confirmDelete(GalleryImage image) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Image'),
        content: Text('Are you sure you want to delete this image${image.label != null ? ' (${image.label})' : ''}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteImage(image);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteImage(GalleryImage image) async {
    try {
      await ref.read(galleryRepositoryProvider).deleteImage(image.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image deleted'),
        backgroundColor: AppColors.success,
      ));
      ref.invalidate(galleryImagesProvider);
      ref.invalidate(galleryTeamStatsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to delete image: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
      Expanded(
          child: Text(value,
              style: TextStyle(fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final teamIdAsync = ref.watch(galleryTeamIdProvider(widget.competitionId));

    return AxonScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: PageHeader(title: 'Gallery & Stats',
                  subtitle: 'Team images, statistics, and member contributions')),
        ]),
        const SizedBox(height: AppSpacing.lg),
        teamIdAsync.when(
          loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
          error: (err, _) => SizedBox(
              height: 300,
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Could not load your team: $err',
                  style: const TextStyle(color: AppColors.error)),
            ]))),
          data: (teamId) {
            if (teamId == null) {
              return const SizedBox(
                  height: 300,
                  child: Center(
                      child: Text('You are not assigned to any team.',
                          style: TextStyle(color: AppColors.textSecondary))));
            }
            return _buildGalleryContent(teamId);
          },
        ),
      ]),
    );
  }

  Widget _buildGalleryContent(String teamId) {
    final statsAsync = ref.watch(galleryTeamStatsProvider(teamId));
    final imagesParams = GalleryImagesParams(
      teamId: teamId,
      status: _statusFilter,
      authorId: _authorFilter,
      label: _labelFilter,
    );
    final imagesAsync = ref.watch(galleryImagesProvider(imagesParams));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      statsAsync.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => const SizedBox.shrink(),
        data: (stats) {
          if (stats == null) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildStatsOverview(stats),
            const SizedBox(height: AppSpacing.xl),
            _buildFilters(stats, teamId),
          ]);
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      imagesAsync.when(
        loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator())),
        error: (err, _) => Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                color: AppColors.error.withValues(alpha: 0.1)),
            child: Text('Failed to load images: $err', style: const TextStyle(color: AppColors.error))),
        data: (imageList) {
          final images = imageList.images;
          final stats = statsAsync.valueOrNull;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Images (${imageList.total})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            if (images.isEmpty)
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      color: AppColors.surface),
                  child: Column(children: [
                    Icon(Icons.image_not_supported, size: 48,
                        color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: AppSpacing.md),
                    Text('No images match your filters.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                  ]))
            else
              _buildImageGrid(images),
            const SizedBox(height: AppSpacing.xl),
            if (stats != null) ..._buildStatsSections(stats),
          ]);
        },
      ),
    ]);
  }

  List<Widget> _buildStatsSections(TeamStats stats) {
    return [
      if (stats.members.isNotEmpty) ...[
        Text('Member Leaderboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        _buildMemberLeaderboard(stats.members),
        const SizedBox(height: AppSpacing.xl),
        Text('Contribution Breakdown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        _buildContributionBreakdown(stats),
      ],
    ];
  }

  Widget _buildStatsOverview(TeamStats stats) {
    return Row(children: [
      Expanded(child: _statCard(Icons.group, 'Members', stats.totalMembers.toString(), AppColors.primaryDark)),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: _statCard(Icons.image, 'Images', stats.imagesUploaded.toString(), AppColors.accent)),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: _statCard(Icons.memory, 'Models', stats.modelsSubmitted.toString(), AppColors.success)),
    ]);
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
            child: Column(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 24)),
              const SizedBox(height: AppSpacing.sm),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ])));
  }

  Widget _buildFilters(TeamStats stats, String teamId) {
    final uniqueAuthors = <_AuthorOption>[];
    final seen = <String>{};
    for (final member in stats.members) {
      if (!seen.contains(member.userId)) {
        seen.add(member.userId);
        uniqueAuthors.add(_AuthorOption(id: member.userId, name: member.name));
      }
    }

    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.filter_list, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text('Filters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (_statusFilter != null || _authorFilter != null || _labelFilter != null) ...[
                  const Spacer(),
                  TextButton(
                      onPressed: () => setState(() {
                            _statusFilter = null;
                            _authorFilter = null;
                            _labelFilter = null;
                          }),
                      child: const Text('Clear all')),
                ],
              ]),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                _filterChip('All', _statusFilter == null, () => setState(() => _statusFilter = null)),
                _filterChip('Verified', _statusFilter == 'verified',
                    () => setState(() => _statusFilter = 'verified')),
                _filterChip('On Hold', _statusFilter == 'onhold',
                    () => setState(() => _statusFilter = 'onhold')),
                if (uniqueAuthors.isNotEmpty) ...[
                  const Divider(height: 1),
                  ...uniqueAuthors.map((a) => _filterChip(
                      a.name, _authorFilter == a.id,
                      () => setState(() => _authorFilter = _authorFilter == a.id ? null : a.id))),
                ],
              ]),
            ])));
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryDark,
        checkmarkColor: Colors.white,
        backgroundColor: AppColors.surfaceAlt,
        side: BorderSide(color: selected ? AppColors.primaryDark : AppColors.border),
        visualDensity: VisualDensity.compact);
  }

  Widget _buildImageGrid(List<GalleryImage> images) {
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: AppSpacing.md, mainAxisSpacing: AppSpacing.md, childAspectRatio: 1),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          return InkWell(
              onTap: () => _showImageDetail(image),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      image: DecorationImage(
                          image: NetworkImage(_getImageUrl(image.filepath)), fit: BoxFit.cover)),
                  child: Stack(children: [
                    Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: image.status == 'verified' ? AppColors.success : Colors.orange,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(image.status == 'verified' ? 'V' : 'H',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                    Positioned(
                        top: 2,
                        left: 2,
                        child: GestureDetector(
                            onTap: () => _confirmDelete(image),
                            child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.delete_outline,
                                    size: 14, color: Colors.white70))),
                      ),
                    Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (image.label != null)
                                    Text(image.label!,
                                        style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  if (image.authorName != null)
                                    Text(image.authorName!,
                                        style: const TextStyle(color: Colors.white70, fontSize: 9),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                ]))),
                  ])));
        });
  }

  Widget _buildMemberLeaderboard(List<TeamMemberStats> members) {
    final sorted = List<TeamMemberStats>.from(members)
      ..sort((a, b) => b.totalContributions.compareTo(a.totalContributions));
    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: Column(
            children: List.generate(sorted.length, (index) {
          final member = sorted[index];
          final maxContrib = sorted.first.totalContributions;
          final progress = maxContrib > 0 ? member.totalContributions / maxContrib : 0.0;
          final isFirst = index == 0;
          final isLast = index == sorted.length - 1;
          return Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                  color: isFirst ? AppColors.primaryDark.withValues(alpha: 0.06) : null,
                  borderRadius: BorderRadius.vertical(
                      top: isFirst ? const Radius.circular(16) : Radius.zero,
                      bottom: isLast ? const Radius.circular(16) : Radius.zero),
                  border: isLast
                      ? null
                      : const Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(children: [
                SizedBox(
                    width: 32,
                    child: index < 3
                        ? Icon(Icons.emoji_events,
                            color: index == 0
                                ? Colors.amber
                                : index == 1
                                    ? Colors.grey
                                    : Colors.brown,
                            size: 20)
                        : Text('${index + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
                const SizedBox(width: AppSpacing.sm),
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.success],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(member.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              index == 0 ? Colors.amber : AppColors.primaryDark),
                          minHeight: 4)),
                ])),
                const SizedBox(width: AppSpacing.sm),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.camera_alt, size: 12, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text('${member.imagesUploaded}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent)),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified, size: 12, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('${member.imagesValidated}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.success)),
                  ]),
                ]),
              ]));
        })));
  }

  Widget _buildContributionBreakdown(TeamStats stats) {
    final totalUploads = stats.members.fold<int>(0, (sum, m) => sum + m.imagesUploaded);
    final totalValidations = stats.members.fold<int>(0, (sum, m) => sum + m.imagesValidated);
    final grandTotal = totalUploads + totalValidations;
    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(children: [
              _breakdownRow(Icons.camera_alt, 'Images Captured', totalUploads, AppColors.accent, grandTotal),
              const SizedBox(height: AppSpacing.md),
              _breakdownRow(Icons.verified, 'Labels Validated', totalValidations, AppColors.success, grandTotal),
              if (totalUploads > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Avg. per member',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          stats.totalMembers > 0
                              ? '${(totalUploads / stats.totalMembers).toStringAsFixed(1)} images'
                              : '0 images',
                          style: const TextStyle(
                              color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 13))),
                ]),
              ],
            ])));
  }

  Widget _breakdownRow(IconData icon, String label, int value, Color color, int total) {
    final percentage = total > 0 ? value / total : 0.0;
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('$value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6)),
      ])),
    ]);
  }
}

class _AuthorOption {
  final String id;
  final String name;
  const _AuthorOption({required this.id, required this.name});
}
