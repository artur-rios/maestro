import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:sodium/sodium_sumo.dart';

final class SodiumPasswordHasher implements PasswordHasher {
  const SodiumPasswordHasher._(this._sodium);

  final SodiumSumo _sodium;

  static Future<SodiumPasswordHasher> initialize() async {
    final sodium = await SodiumSumoInit.init();
    return SodiumPasswordHasher._(sodium);
  }

  @override
  Future<String> create(String password) {
    return _sodium.runIsolated((_, _) {
      final pwhash = _sodium.crypto.pwhash;
      return pwhash.str(
        password: password,
        opsLimit: pwhash.opsLimitInteractive,
        memLimit: pwhash.memLimitInteractive,
      );
    });
  }

  @override
  Future<bool> verify(String verifier, String password) {
    return _sodium.runIsolated((_, _) {
      return _sodium.crypto.pwhash.strVerify(
        passwordHash: verifier,
        password: password,
      );
    });
  }
}
