import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/domain/delivery_record.dart';
import 'package:maestro/features/delivery/presentation/delivery_controller.dart';
import 'package:maestro/features/delivery/presentation/delivery_panel.dart';

void main() {
  testWidgets('GivenCompletedDelivery_WhenRendered_ThenEvidenceIsVisible', (
    tester,
  ) async {
    final repository = _Repository()..record = _record();
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryPanel(
          runId: 'run-1',
          createController: () => DeliveryController(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delivery-pr-url')), findsOneWidget);
    expect(find.byKey(const Key('delivery-review')), findsOneWidget);
    expect(find.byKey(const Key('delivery-merge-commit')), findsOneWidget);
    expect(find.textContaining('completed'), findsOneWidget);
  });
}

DeliveryRecord _record() => DeliveryRecord(
  runId: 'run-1',
  repository: 'acme/app',
  issueNumber: 7,
  branchName: 'feature/7',
  headCommit: 'head',
  pullRequestNumber: 7,
  pullRequestUrl: 'https://github.com/acme/app/pull/7',
  reviewerIdentity: 'reviewer',
  reviewOutcome: DeliveryReviewOutcome.approved,
  findings: const <String>[],
  mergeCommit: 'merge',
  issueClosed: true,
  branchDeleted: true,
  failureCode: null,
  remediation: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  completedAt: DateTime.utc(2026),
);

final class _Repository implements DeliveryRecordRepository {
  DeliveryRecord? record;
  @override
  Future<DeliveryRecord?> findByRunId(String runId) async => record;
  @override
  Future<void> save(DeliveryRecord record) async {}
}
