import 'package:flutter_test/flutter_test.dart';
import 'package:website/features/leaderboard/data/leaderboard_models.dart';

void main() {
  group('Leaderboard Models Test', () {
    test('LeaderboardEntry.fromJson correctly parses nested team object from backend', () {
      final json = {
        'rank': 1,
        'team': {
          'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          'name': 'Alpha Squad'
        },
        'score': 0.985,
        'submitted_at': '2026-05-08T12:00:00Z',
      };

      final entry = LeaderboardEntry.fromJson(json);

      expect(entry.rank, 1);
      expect(entry.teamName, 'Alpha Squad');
      expect(entry.teamId, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(entry.score, 0.985);
      expect(entry.submittedAt, '2026-05-08T12:00:00Z');
    });

    test('LeaderboardData.fromJson correctly parses complete response', () {
      final json = {
        'entries': [
          {
            'rank': 1,
            'team': {
              'id': 'uuid-1',
              'name': 'Team 1'
            },
            'score': 0.9,
            'submitted_at': '2026-05-08T10:00:00Z'
          },
          {
            'rank': 2,
            'team': {
              'id': 'uuid-2',
              'name': 'Team 2'
            },
            'score': 0.85,
            'submitted_at': '2026-05-08T11:00:00Z'
          }
        ],
        'total_teams': 2,
        'last_updated': '2026-05-08T12:00:00Z',
      };

      final data = LeaderboardData.fromJson(json);

      expect(data.entries.length, 2);
      expect(data.totalTeams, 2);
      expect(data.lastUpdated, '2026-05-08T12:00:00Z');

      expect(data.entries[0].teamName, 'Team 1');
      expect(data.entries[1].teamName, 'Team 2');
    });
    
    test('LeaderboardEntry.fromJson handles missing team objects safely', () {
      final json = {
        'rank': 3,
        'score': 0.5,
      };

      final entry = LeaderboardEntry.fromJson(json);

      expect(entry.rank, 3);
      expect(entry.teamName, 'Unknown');
      expect(entry.score, 0.5);
    });
  });
}
