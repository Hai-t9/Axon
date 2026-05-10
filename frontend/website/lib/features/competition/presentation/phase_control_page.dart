import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/competition_repository.dart';
import 'competition_dashboard_page.dart';

const Map<String, String> phaseLabels = {
  '0': 'Awaiting Initialisation',
  '1': 'Data Collection',
  '2': 'Data Validation',
  '3': 'Model Submission',
  '4': 'Finale & Leaderboard',
};

class PhaseControlPage extends ConsumerStatefulWidget {
  const PhaseControlPage({super.key, required this.competitionId});

  static const routeName = 'phase-control';
  static const routePath = '/competitions/:id/phases';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/phases';

  @override
  ConsumerState<PhaseControlPage> createState() => _PhaseControlPageState();
}

class _PhaseControlPageState extends ConsumerState<PhaseControlPage> {
  Map<String, dynamic>? _phase;
  List<dynamic> _timeline = [];
  bool _loading = true;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  static const _phaseList = ['0', '1', '2', '3', '4'];

  @override
  void initState() {
    super.initState();
    _loadPhase();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhase() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(competitionRepositoryProvider);
      final phase = await repo.getPhase(widget.competitionId);
      final timeline = await repo.getPhaseTimeline(widget.competitionId);
      setState(() {
        _phase = phase;
        _timeline = timeline['phases'] as List<dynamic>? ?? [];
        _loading = false;
      });
      _updateCountdown();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMsg(e.toString(), isError: true);
      }
    }
  }

  void _updateCountdown() {
    _countdownTimer?.cancel();
    if (_phase == null) return;

    final phaseDates = _phase!['phase_dates'] as Map<String, dynamic>?;
    final currentPhase = _phase!['current_phase'] as String;
    final deadlines = phaseDates?['deadlines'] as Map<String, dynamic>?;
    final deadlineStr = deadlines?[currentPhase] as String?;

    if (deadlineStr == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }

    final deadline = _parseUtc(deadlineStr);
    if (deadline == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = deadline.difference(DateTime.now().toUtc());
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        setState(() => _remaining = Duration.zero);
        _loadPhase();
      } else {
        setState(() => _remaining = remaining);
      }
    });
  }

  DateTime? _parseUtc(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
  }

  void _showMsg(String msg, {bool isError = false}) {
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _advancePhase() async {
    try {
      final repo = ref.read(competitionRepositoryProvider);
      final result = await repo.advancePhase(widget.competitionId);
      _showMsg('Advanced to phase ${result['current_phase']}');
      await _loadPhase();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _decrementPhase() async {
    try {
      final repo = ref.read(competitionRepositoryProvider);
      final result = await repo.decrementPhase(widget.competitionId);
      _showMsg('Decremented to phase ${result['current_phase']}');
      await _loadPhase();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _extendDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 12))),
    );
    if (time == null || !mounted) return;

    final localDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final deadline = localDeadline.toUtc();

    try {
      final repo = ref.read(competitionRepositoryProvider);
      await repo.setPhaseDeadline(widget.competitionId, deadline);
      _showMsg('Deadline updated.');
      await _loadPhase();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return 'No deadline set';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (days > 0) return '$days days  ${hours.toString().padLeft(2, '0')}h  ${minutes.toString().padLeft(2, '0')}m';
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}h  ${minutes.toString().padLeft(2, '0')}m  ${seconds.toString().padLeft(2, '0')}s';
    if (minutes > 0) return '${minutes.toString().padLeft(2, '0')}m  ${seconds.toString().padLeft(2, '0')}s';
    return '${seconds.toString().padLeft(2, '0')}s';
  }

  String _phaseLabel(String phase) => phaseLabels[phase] ?? 'Unknown';

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'rolled_back':
        return 'Rolled Back';
      default:
        return status;
    }
  }

  String _formatDeadline(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${_two(local.month)}-${_two(local.day)}  $h:$m';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPhase = _phase?['current_phase'] as String? ?? '0';
    final currentIdx = _phaseList.indexOf(currentPhase);
    final isLast = currentIdx >= _phaseList.length - 1;
    final isFirst = currentIdx <= 0;
    final nextPhase = isLast ? null : _phaseList[currentIdx + 1];
    final prevPhase = isFirst ? null : _phaseList[currentIdx - 1];
    final isPhaseFour = currentPhase == '4';

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: PageHeader(title: 'Phase Control', subtitle: 'Manage competition phases.')),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh phase data',
              onPressed: _loading ? null : _loadPhase,
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => context.go(CompetitionDashboardPage.routeForId(widget.competitionId)),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Dashboard'),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()))
          else ...[
            // Current phase card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lan_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Phase',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('Phase $currentPhase: ${_phaseLabel(currentPhase)}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      )),
                    ]),
                    if (!isPhaseFour) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Row(children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Deadline: ${_formatDuration(_remaining)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _remaining != Duration.zero ? AppColors.primaryDark : AppColors.textSecondary,
                              fontWeight: _remaining != Duration.zero ? FontWeight.w600 : FontWeight.normal,
                            )),
                      ]),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                      if (isFirst)
                        ElevatedButton.icon(
                          onPressed: _advancePhase,
                          icon: const Icon(Icons.play_arrow_outlined, size: 18),
                          label: const Text('Kickstart Competition'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _decrementPhase,
                          icon: const Icon(Icons.skip_previous_outlined, size: 18),
                          label: Text('Back to Phase $prevPhase'),
                        ),
                        if (!isLast)
                          ElevatedButton.icon(
                            onPressed: _advancePhase,
                            icon: const Icon(Icons.skip_next_outlined, size: 18),
                            label: Text('Advance to Phase $nextPhase'),
                          ),
                      ],
                      if (!isPhaseFour) ...[
                        const SizedBox(width: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _extendDeadline,
                          icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                          label: const Text('Extend Deadline'),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Phase Timeline
            Text('Phase Timeline',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            if (_timeline.isEmpty)
              Card(child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(child: Text('No phases recorded yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))),
              ))
            else
              ..._timeline.reversed.map((entry) {
                final phase = entry['phase'] as String? ?? '';
                final status = entry['status'] as String? ?? '';
                final start = entry['start'] as String?;
                final deadline = entry['deadline'] as String?;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        status == 'completed' ? Icons.check_circle_outline : Icons.hourglass_top_outlined,
                        color: _statusColor(status), size: 18,
                      ),
                    ),
                    title: Text('Phase $phase: ${_phaseLabel(phase)}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (start != null) Text('Started: ${start.split('T').first}',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        if (deadline != null) Text('Deadline: ${_formatDeadline(deadline)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Chip(
                          label: Text(_statusLabel(status),
                              style: TextStyle(fontSize: 11, color: _statusColor(status))),
                          backgroundColor: _statusColor(status).withValues(alpha: 0.1),
                          side: BorderSide.none,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}