import 'package:flutter/material.dart';
import '../models/team_stats_model.dart';

class MemberProfileScreen extends StatelessWidget {
  final MemberStatsModel member;
  final String competitionName;
  final int rank;

  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.competitionName,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final String compName = competitionName;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Profile'),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Hero(
                tag: 'member_avatar_${member.userId}',
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF5F75EE).withOpacity(0.8),
                        const Color(0xFF33E1A6).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF252536), width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5F75EE).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                member.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                member.email,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
              if (rankIcon != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rankColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(rankIcon, color: rankColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Rank #$rank',
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252536),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3A3A50), width: 1.5),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.emoji_events_outlined, color: Color(0xFF5F75EE)),
                      title: const Text('Competition'),
                      subtitle: Text(compName, style: const TextStyle(color: Colors.white70)),
                    ),
                    const Divider(color: Color(0xFF3A3A50), height: 1),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFE5A53C)),
                      title: const Text('Images Captured'),
                      trailing: Text(
                        '${member.imagesUploaded}',
                        style: const TextStyle(
                          color: Color(0xFFE5A53C),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const Divider(color: Color(0xFF3A3A50), height: 1),
                    ListTile(
                      leading: const Icon(Icons.verified_outlined, color: Color(0xFF33E1A6)),
                      title: const Text('Labels Validated'),
                      trailing: Text(
                        '${member.imagesValidated}',
                        style: const TextStyle(
                          color: Color(0xFF33E1A6),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const Divider(color: Color(0xFF3A3A50), height: 1),
                    ListTile(
                      leading: const Icon(Icons.star_rounded, color: Color(0xFFFFD700)),
                      title: const Text('Total Contributions'),
                      trailing: Text(
                        '${member.totalContributions}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
