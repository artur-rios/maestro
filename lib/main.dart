import 'package:flutter/widgets.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/features/foundation/data/production_foundation.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final root = await getApplicationSupportDirectory();
    final foundation = ProductionFoundation(
      paths: ApplicationPaths.fromRoot(root),
    );
    runApp(MaestroApp(foundationProbes: foundation.probes));
  } on Object catch (error) {
    runApp(
      MaestroApp(
        foundationProbes: <StaticFoundationProbe>[
          StaticFoundationProbe(
            FoundationCheck(
              id: 'application-data',
              health: FoundationHealth.blocked,
              message: 'Application data initialization failed: $error',
              remediation: 'Check local permissions and restart Maestro.',
            ),
          ),
        ],
      ),
    );
  }
}
