import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/foundation/application/bootstrap_foundation.dart';
import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';

final foundationProbesProvider = Provider<List<FoundationProbe>>(
  (ref) => const <FoundationProbe>[],
);

final bootstrapFoundationProvider = Provider<BootstrapFoundation>(
  (ref) => BootstrapFoundation(ref.watch(foundationProbesProvider)),
);

final foundationControllerProvider =
    AsyncNotifierProvider<FoundationController, FoundationReport>(
      FoundationController.new,
    );

final class FoundationController extends AsyncNotifier<FoundationReport> {
  @override
  FutureOr<FoundationReport> build() {
    return ref.watch(bootstrapFoundationProvider)();
  }
}
