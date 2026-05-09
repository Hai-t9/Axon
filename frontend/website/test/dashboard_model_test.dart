import 'package:flutter_test/flutter_test.dart';
import 'package:website/features/competition/data/dashboard_models.dart';

void main() {
  group('Dashboard Models Test', () {
    test('DashboardPhaseInfo.fromJson correctly parses backend PhaseResponse', () {
      final json = {
        'competition_id': 'c1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'current_phase': 'Evaluation',
        'phase_dates': {
          'Evaluation': '2026-05-08T12:00:00Z'
        }
      };

      final phase = DashboardPhaseInfo.fromJson(json);

      expect(phase.competitionId, 'c1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(phase.currentPhase, 'Evaluation');
      expect(phase.phaseDates['Evaluation'], '2026-05-08T12:00:00Z');
    });
  });
}
