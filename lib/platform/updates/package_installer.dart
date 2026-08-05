import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/release_manifest.dart';

final class StagedUpdate {
  const StagedUpdate({required this.artifact, required this.path});

  final ReleaseArtifact artifact;
  final String path;
}

abstract interface class PackageInstaller {
  Future<Result<void>> install(StagedUpdate update);
}
