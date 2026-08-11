import 'package:maestro/features/runs/domain/run_models.dart';

final class HistorySummary {
  const HistorySummary({
    required this.runId,
    required this.label,
    required this.status,
    required this.occurredAt,
  });

  final String runId;
  final String label;
  final RunStatus status;
  final DateTime occurredAt;
}

final class HistoryFilter {
  const HistoryFilter({this.query = '', this.statuses = const <RunStatus>{}});

  final String query;
  final Set<RunStatus> statuses;
}

/// Immutable evidence references returned for a selected historical run.
final class HistoryDetail {
  HistoryDetail({
    required this.summary,
    required this.snapshotJson,
    required Iterable<HistoryAttempt> attempts,
    required Iterable<HistoryAuditEvent> auditEvents,
    required Iterable<HistoryLogSegment> logSegments,
  }) : attempts = List<HistoryAttempt>.unmodifiable(attempts),
       auditEvents = List<HistoryAuditEvent>.unmodifiable(auditEvents),
       logSegments = List<HistoryLogSegment>.unmodifiable(logSegments);

  final HistorySummary summary;
  final String snapshotJson;
  final List<HistoryAttempt> attempts;
  final List<HistoryAuditEvent> auditEvents;
  final List<HistoryLogSegment> logSegments;
}

final class HistoryLogSegment {
  HistoryLogSegment({
    required this.id,
    required this.attemptId,
    required this.sequence,
    required this.channel,
    required List<int> bytes,
    required this.compression,
  }) : bytes = List<int>.unmodifiable(bytes);
  final String id;
  final String attemptId;
  final int sequence;
  final String channel;
  final List<int> bytes;
  final String compression;
}

final class HistoryAttempt {
  const HistoryAttempt({
    required this.id,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.exitCode,
    this.failureCode,
  });
  final String id;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? exitCode;
  final String? failureCode;
}

final class HistoryAuditEvent {
  const HistoryAuditEvent({
    required this.id,
    required this.action,
    required this.outcome,
    required this.occurredAt,
    required this.details,
  });
  final String id;
  final String action;
  final String outcome;
  final DateTime occurredAt;
  final String details;
}

List<HistorySummary> filterHistory(
  Iterable<HistorySummary> entries,
  HistoryFilter filter,
) {
  final query = filter.query.trim().toLowerCase();
  return List<HistorySummary>.unmodifiable(
    entries.where((entry) {
      final matchesText =
          query.isEmpty ||
          entry.label.toLowerCase().contains(query) ||
          entry.runId.toLowerCase().contains(query);
      return matchesText &&
          (filter.statuses.isEmpty || filter.statuses.contains(entry.status));
    }),
  );
}
