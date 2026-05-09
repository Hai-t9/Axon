import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/team_stats_model.dart';
import '../services/competition_service.dart';

class TeamStatsScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String teamName;
  final String competitionName;

  const TeamStatsScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.competitionName,
  });

  @override
  ConsumerState<TeamStatsScreen> createState() => _TeamStatsScreenState();
}

class _TeamStatsScreenState extends ConsumerState<TeamStatsScreen>
    with SingleTickerProviderStateMixin {
  TeamStatsModel? _stats;
  bool _loading = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(competitionServiceProvider);
      final stats = await service.getTeamStats(widget.teamId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
        _animController.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C28),
      body: RefreshIndicator(
        color: const Color(0xFF5F75EE),
        backgroundColor: const Color(0xFF252536),
        onRefresh: () async {
          _animController.reset();
          await _loadStats();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF5F75EE)),
                ),
              )
            else if (_stats == null)
              const SliverFillRemaining(
                child: Center(
                  child: Text('Failed to load statistics',
                      style: TextStyle(color: Colors.white60)),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _buildOverviewCards()),
              SliverToBoxAdapter(child: _buildMemberLeaderboard()),
              SliverToBoxAdapter(child: _buildContributionBreakdown()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF252536),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          widget.teamName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5F75EE), Color(0xFF3F54C6), Color(0xFF252536)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 200,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 56,
                child: Text(
                  widget.competitionName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _animController,
          curve: Curves.easeOutCubic,
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                Icons.group_rounded,
                'Members',
                _stats!.totalMembers.toString(),
                const Color(0xFF5F75EE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                Icons.photo_library_rounded,
                'Images',
                _stats!.imagesUploaded.toString(),
                const Color(0xFFE5A53C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                Icons.memory_rounded,
                'Models',
                _stats!.modelsSubmitted.toString(),
                const Color(0xFF33E1A6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252536),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberLeaderboard() {
    if (_stats!.members.isEmpty) return const SizedBox.shrink();

    final sorted = List<MemberStatsModel>.from(_stats!.members)
      ..sort((a, b) => b.totalContributions.compareTo(a.totalContributions));

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5F75EE).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.leaderboard_rounded,
                      color: Color(0xFF5F75EE), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Member Leaderboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF252536),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A3A50), width: 1),
              ),
              child: Column(
                children: List.generate(sorted.length, (index) {
                  final member = sorted[index];
                  final isFirst = index == 0;
                  final isLast = index == sorted.length - 1;
                  return _buildMemberTile(member, index + 1, isFirst, isLast);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(
      MemberStatsModel member, int rank, bool isFirst, bool isLast) {
    final maxContributions = _stats!.members.isEmpty
        ? 1
        : _stats!.members
            .map((m) => m.totalContributions)
            .reduce((a, b) => a > b ? a : b);
    final progress = maxContributions > 0
        ? member.totalContributions / maxContributions
        : 0.0;

    Color rankColor;
    IconData? rankIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700);
        rankIcon = Icons.emoji_events_rounded;
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0);
        rankIcon = Icons.emoji_events_rounded;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32);
        rankIcon = Icons.emoji_events_rounded;
        break;
      default:
        rankColor = Colors.white38;
        rankIcon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isFirst
            ? const Color(0xFF5F75EE).withOpacity(0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFF3A3A50), width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 22)
                : Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5F75EE).withOpacity(0.6),
                  const Color(0xFF33E1A6).withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty
                    ? member.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rank == 1
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF5F75EE),
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      size: 13, color: Color(0xFFE5A53C)),
                  const SizedBox(width: 4),
                  Text(
                    '${member.imagesUploaded}',
                    style: const TextStyle(
                      color: Color(0xFFE5A53C),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 13, color: Color(0xFF33E1A6)),
                  const SizedBox(width: 4),
                  Text(
                    '${member.imagesValidated}',
                    style: const TextStyle(
                      color: Color(0xFF33E1A6),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributionBreakdown() {
    if (_stats!.members.isEmpty) return const SizedBox.shrink();

    final totalUploads = _stats!.members.fold<int>(
        0, (sum, m) => sum + m.imagesUploaded);
    final totalValidations = _stats!.members.fold<int>(
        0, (sum, m) => sum + m.imagesValidated);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF33E1A6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded,
                      color: Color(0xFF33E1A6), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Contribution Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF252536),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A3A50), width: 1),
              ),
              child: Column(
                children: [
                  _buildBreakdownRow(
                    Icons.camera_alt_rounded,
                    'Images Captured',
                    totalUploads,
                    const Color(0xFFE5A53C),
                    totalUploads + totalValidations,
                  ),
                  const SizedBox(height: 16),
                  _buildBreakdownRow(
                    Icons.verified_rounded,
                    'Labels Validated',
                    totalValidations,
                    const Color(0xFF33E1A6),
                    totalUploads + totalValidations,
                  ),
                  if (_stats!.imagesUploaded > 0) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF3A3A50), height: 1),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Avg. per member',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5F75EE).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _stats!.totalMembers > 0
                                ? '${(_stats!.imagesUploaded / _stats!.totalMembers).toStringAsFixed(1)} images'
                                : '0 images',
                            style: const TextStyle(
                              color: Color(0xFF5F75EE),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
      IconData icon, String label, int value, Color color, int total) {
    final percentage = total > 0 ? value / total : 0.0;
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$value',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
