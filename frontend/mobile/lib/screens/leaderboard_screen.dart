import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_model.dart';
import '../services/competition_service.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String competitionId;
  final String competitionName;

  const LeaderboardScreen({
    super.key,
    required this.competitionId,
    required this.competitionName,
  });

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LeaderboardResponse? _publicData;
  LeaderboardResponse? _privateData;
  bool _loadingPublic = true;
  bool _loadingPrivate = true;
  String _selectedProtocol = 'standard';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final service = ref.read(competitionServiceProvider);
    try {
      final public = await service.getLeaderboard(
        widget.competitionId,
        type: 'public',
      );
      if (mounted) {
        setState(() {
          _publicData = public;
          _loadingPublic = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPublic = false);
    }
    try {
      final private = await service.getLeaderboard(
        widget.competitionId,
        type: 'private',
      );
      if (mounted) {
        setState(() {
          _privateData = private;
          _loadingPrivate = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrivate = false);
    }
  }

  bool get _isPhaseGated =>
      _publicData != null && int.tryParse(_publicData!.phase) != null && int.parse(_publicData!.phase) < 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C28),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${widget.competitionName} Leaderboard',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loadingPublic && _loadingPrivate
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5F75EE)))
          : _isPhaseGated
              ? _buildPhaseGated()
              : Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF5F75EE),
                      unselectedLabelColor: Colors.white38,
                      indicatorColor: const Color(0xFF5F75EE),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public, size: 18),
                              SizedBox(width: 8),
                              Text('Public', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 18),
                              SizedBox(width: 8),
                              Text('Private', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPublicTab(),
                          _buildPrivateTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPhaseGated() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF5F75EE).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 48, color: Color(0xFF5F75EE)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Leaderboard Locked',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The leaderboard will be available once the competition reaches the Model Submission phase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            if (_publicData != null && _publicData!.phaseLabel.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF252536),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3A3A50)),
                ),
                child: Text(
                  'Current phase: ${_publicData!.phaseLabel}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPublicTab() {
    if (_loadingPublic) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF5F75EE)));
    }
    if (_publicData == null || !_publicData!.showLeaderboard) {
      return _buildEmptyState('No public leaderboard data available yet.');
    }
    return RefreshIndicator(
      color: const Color(0xFF5F75EE),
      backgroundColor: const Color(0xFF252536),
      onRefresh: () async {
        setState(() => _loadingPublic = true);
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _publicData!.entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_publicData!.totalTeams} teams',
                    style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Phase: ${_publicData!.phaseLabel}',
                    style: const TextStyle(color: Color(0xFF5F75EE), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }
          final entry = _publicData!.entries[index - 1];
          return _buildPublicEntry(entry, index);
        },
      ),
    );
  }

  Widget _buildPrivateTab() {
    if (_loadingPrivate) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF5F75EE)));
    }
    if (_privateData == null || !_privateData!.showLeaderboard) {
      return _buildEmptyState('No private leaderboard data available yet.');
    }

    final protocols = ['standard', 'loto', 'toto'];
    final protocolEntries = _privateData!.entries
        .where((e) => e.protocol == _selectedProtocol)
        .toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF252536),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A50)),
          ),
          child: Row(
            children: protocols.map((p) {
              final selected = _selectedProtocol == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedProtocol = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF5F75EE) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      p.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: selected ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF5F75EE),
            backgroundColor: const Color(0xFF252536),
            onRefresh: () async {
              setState(() => _loadingPrivate = true);
              await _loadData();
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: protocolEntries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Protocol: $_selectedProtocol',
                          style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${protocolEntries.length} teams',
                          style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }
                final entry = protocolEntries[index - 1];
                return _buildPrivateEntry(entry, index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPublicEntry(LeaderboardEntry entry, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252536),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.rank <= 3
              ? entry.rank == 1
                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                  : entry.rank == 2
                      ? const Color(0xFFC0C0C0).withValues(alpha: 0.3)
                      : const Color(0xFFCD7F32).withValues(alpha: 0.3)
              : const Color(0xFF3A3A50),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SizedBox(
          width: 36,
          child: entry.rank <= 3
              ? Icon(
                  Icons.emoji_events_rounded,
                  color: entry.rank == 1
                      ? const Color(0xFFFFD700)
                      : entry.rank == 2
                          ? const Color(0xFFC0C0C0)
                          : const Color(0xFFCD7F32),
                  size: 24,
                )
              : Text(
                  '#${entry.rank}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
        ),
        title: Text(
          entry.team.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 12, color: Colors.white38),
            const SizedBox(width: 4),
            Text(
              '${entry.modelsSubmitted} model${entry.modelsSubmitted == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.score.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: entry.rank == 1
                    ? const Color(0xFFFFD700)
                    : entry.rank == 2
                        ? const Color(0xFFC0C0C0)
                        : entry.rank == 3
                            ? const Color(0xFFCD7F32)
                            : const Color(0xFF5F75EE),
              ),
            ),
            const Text(
              'PTS',
              style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateEntry(LeaderboardEntry entry, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252536),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.rank <= 3
              ? entry.rank == 1
                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                  : entry.rank == 2
                      ? const Color(0xFFC0C0C0).withValues(alpha: 0.3)
                      : const Color(0xFFCD7F32).withValues(alpha: 0.3)
              : const Color(0xFF3A3A50),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: entry.rank <= 3
                  ? Icon(
                      Icons.emoji_events_rounded,
                      color: entry.rank == 1
                          ? const Color(0xFFFFD700)
                          : entry.rank == 2
                              ? const Color(0xFFC0C0C0)
                              : const Color(0xFFCD7F32),
                      size: 24,
                    )
                  : Text(
                      '#${entry.rank}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.team.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _metricChip('Acc', entry.accuracy),
                      const SizedBox(width: 6),
                      _metricChip('Prec', entry.precision),
                      const SizedBox(width: 6),
                      _metricChip('Rec', entry.recall),
                      const SizedBox(width: 6),
                      _metricChip('F1', entry.f1Score),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, double? value) {
    final display = value != null ? value.toStringAsFixed(3) : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A3A50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 3),
          Text(
            display,
            style: TextStyle(
              color: value != null ? const Color(0xFF33E1A6) : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 48, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
