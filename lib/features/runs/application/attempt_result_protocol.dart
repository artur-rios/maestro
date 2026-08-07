import 'package:maestro/features/runs/domain/run_models.dart';

sealed class AttemptResultRead {
  const AttemptResultRead();
}

final class AttemptResultAccepted extends AttemptResultRead {
  const AttemptResultAccepted(this.context);

  final DeclaredContext context;
}

final class AttemptResultRejected extends AttemptResultRead {
  const AttemptResultRejected(this.code);

  final String code;
}
