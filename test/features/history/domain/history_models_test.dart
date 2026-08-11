import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/history/domain/history_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test(
    'GivenTerminalAndPausedRuns_WhenFilteringHistory_ThenEveryMatchingStatusRemainsVisible',
    () {
      final entries = <HistorySummary>[
        HistorySummary(
          runId: 'done',
          label: 'Release',
          status: RunStatus.succeeded,
          occurredAt: DateTime.utc(2026),
        ),
        HistorySummary(
          runId: 'failed',
          label: 'Build',
          status: RunStatus.failed,
          occurredAt: DateTime.utc(2026),
        ),
        HistorySummary(
          runId: 'paused',
          label: 'Audit',
          status: RunStatus.paused,
          occurredAt: DateTime.utc(2026),
        ),
      ];

      final result = filterHistory(entries, const HistoryFilter(query: ''));

      expect(result.map((entry) => entry.runId), <String>[
        'done',
        'failed',
        'paused',
      ]);
    },
  );

  test('GivenHistory_WhenQueryDoesNotMatch_ThenAnEmptyResultIsNotAnError', () {
    final result = filterHistory(<HistorySummary>[
      HistorySummary(
        runId: 'run',
        label: 'Release',
        status: RunStatus.succeeded,
        occurredAt: DateTime.utc(2026),
      ),
    ], const HistoryFilter(query: 'missing'));

    expect(result, isEmpty);
  });

  test(
    'GivenMixedHistory_WhenAStatusFilterIsApplied_ThenOnlyThatLifecycleStateIsReturned',
    () {
      final result = filterHistory(<HistorySummary>[
        HistorySummary(
          runId: 'done',
          label: 'Release',
          status: RunStatus.succeeded,
          occurredAt: DateTime.utc(2026),
        ),
        HistorySummary(
          runId: 'failed',
          label: 'Build',
          status: RunStatus.failed,
          occurredAt: DateTime.utc(2026),
        ),
      ], const HistoryFilter(statuses: <RunStatus>{RunStatus.failed}));

      expect(result.single.runId, 'failed');
    },
  );
}
