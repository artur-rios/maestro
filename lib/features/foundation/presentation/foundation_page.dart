import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/features/foundation/presentation/foundation_controller.dart';

final class FoundationPage extends ConsumerWidget {
  const FoundationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foundationControllerProvider);
    return state.when(
      data: (report) => FoundationReportView(report: report),
      error: (error, _) => FoundationReportView(
        report: FoundationReport(<FoundationCheck>[
          FoundationCheck(
            id: 'bootstrap',
            health: FoundationHealth.blocked,
            message: 'Foundation initialization failed: $error',
            remediation: 'Restart Maestro and inspect the diagnostic log.',
          ),
        ]),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Maestro')),
        body: Semantics(
          label: 'Foundation status',
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

final class FoundationReportView extends StatelessWidget {
  const FoundationReportView({required this.report, super.key});

  final FoundationReport report;

  @override
  Widget build(BuildContext context) {
    final health = report.health.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Maestro')),
      body: Semantics(
        label: 'Foundation $health',
        child: report.checks.isEmpty
            ? const Center(child: Text('Foundation ready'))
            : ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Text(
                    'System diagnostics: $health',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final check in report.checks)
                    Card(
                      child: ListTile(
                        title: Text(check.message),
                        subtitle: check.remediation == null
                            ? null
                            : Text(check.remediation!),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
