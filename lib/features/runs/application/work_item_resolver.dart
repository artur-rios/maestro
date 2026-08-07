import 'package:maestro/features/runs/domain/run_models.dart';

abstract interface class WorkItemResolver {
  Future<WorkItemResolution> resolve(String raw);
}

sealed class WorkItemResolution {
  const WorkItemResolution();
}

final class WorkItemResolutionResolved extends WorkItemResolution {
  const WorkItemResolutionResolved(this.workItem);

  final RunWorkItem workItem;
}

final class WorkItemResolutionRejected extends WorkItemResolution {
  const WorkItemResolutionRejected({
    required this.code,
    required this.message,
    required this.remediation,
  });

  final String code;
  final String message;
  final String remediation;
}

final class FreeFormWorkItemResolver implements WorkItemResolver {
  const FreeFormWorkItemResolver();

  @override
  Future<WorkItemResolution> resolve(String raw) async {
    try {
      return WorkItemResolutionResolved(FreeFormRunWorkItem(text: raw));
    } on ArgumentError {
      return const WorkItemResolutionRejected(
        code: 'run.work_item.invalid',
        message: 'Enter a valid task.',
        remediation: 'Use non-empty text within the supported length.',
      );
    }
  }
}
