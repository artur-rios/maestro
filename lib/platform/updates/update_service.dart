import 'dart:typed_data';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/manifest_verifier.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:maestro/platform/updates/update_approval.dart';
import 'package:maestro/platform/updates/update_downloader.dart';

enum UpdateCheckReason { manual, scheduled }

final class SignedManifestPayload {
  const SignedManifestPayload({
    required this.manifest,
    required this.signature,
  });

  final Uint8List manifest;
  final Uint8List signature;
}

abstract interface class UpdateManifestSource {
  Future<Result<SignedManifestPayload>> fetch();
}

final class UpdateCandidate {
  const UpdateCandidate({required this.verified, required this.reason});

  final VerifiedReleaseManifest verified;
  final UpdateCheckReason reason;
  ReleaseArtifact get artifact => verified.artifact;
}

final class UpdateOutcome {
  const UpdateOutcome({required this.version, required this.packageType});

  final String version;
  final String packageType;
}

final class UpdateService {
  const UpdateService({
    required this.installedVersion,
    required this.source,
    required this.verifier,
    required this.downloader,
    required this.installer,
  });

  final String installedVersion;
  final UpdateManifestSource source;
  final ReleaseManifestVerifier verifier;
  final UpdateDownloader downloader;
  final PackageInstaller installer;

  Future<Result<UpdateCandidate?>> check(UpdateCheckReason reason) async {
    final fetched = await source.fetch();
    return switch (fetched) {
      FailureResult<SignedManifestPayload>(:final failure) =>
        FailureResult<UpdateCandidate?>(failure),
      Success<SignedManifestPayload>(:final value) => _verifiedCandidate(
        verifier.verify(value.manifest, value.signature),
        reason,
      ),
    };
  }

  Future<Result<UpdateOutcome>> install(
    UpdateCandidate candidate,
    UpdateApproval approval,
  ) async {
    if (!approval.isApproved ||
        approval.artifactDigest != candidate.artifact.sha256) {
      return const FailureResult<UpdateOutcome>(
        SecurityFailure(
          code: 'update.approval.required',
          message: 'Installation requires approval for this exact update.',
        ),
      );
    }
    final downloaded = await downloader.download(candidate.artifact);
    switch (downloaded) {
      case FailureResult<StagedUpdate>(:final failure):
        return FailureResult<UpdateOutcome>(failure);
      case Success<StagedUpdate>(:final value):
        final installed = await installer.install(value);
        return switch (installed) {
          FailureResult<void>(:final failure) => FailureResult<UpdateOutcome>(
            failure,
          ),
          Success<void>() => Success<UpdateOutcome>(
            UpdateOutcome(
              version: candidate.verified.manifest.version,
              packageType: candidate.artifact.packageType,
            ),
          ),
        };
    }
  }

  Result<UpdateCandidate?> _verifiedCandidate(
    Result<VerifiedReleaseManifest> result,
    UpdateCheckReason reason,
  ) {
    return switch (result) {
      FailureResult<VerifiedReleaseManifest>(:final failure) =>
        FailureResult<UpdateCandidate?>(failure),
      Success<VerifiedReleaseManifest>(:final value) =>
        Success<UpdateCandidate?>(
          _isNewer(value.manifest.version, installedVersion)
              ? UpdateCandidate(verified: value, reason: reason)
              : null,
        ),
    };
  }

  static bool _isNewer(String candidate, String installed) {
    final candidateParts = _versionParts(candidate);
    final installedParts = _versionParts(installed);
    for (var index = 0; index < 3; index += 1) {
      if (candidateParts[index] != installedParts[index]) {
        return candidateParts[index] > installedParts[index];
      }
    }
    return false;
  }

  static List<int> _versionParts(String version) {
    final core = version.split(RegExp('[-+]')).first;
    final parts = core.split('.').map(int.parse).toList(growable: false);
    if (parts.length != 3) {
      throw FormatException('Invalid semantic version: $version');
    }
    return parts;
  }
}
