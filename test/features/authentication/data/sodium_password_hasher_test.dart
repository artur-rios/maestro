import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/data/sodium_password_hasher.dart';

void main() {
  late SodiumPasswordHasher hasher;

  setUpAll(() async {
    hasher = await SodiumPasswordHasher.initialize();
  });

  test('GivenPassword_WhenHashed_ThenVerifierAcceptsOnlyOriginal', () async {
    final verifier = await hasher.create('correct horse battery staple');

    expect(
      await hasher.verify(verifier, 'correct horse battery staple'),
      isTrue,
    );
    expect(await hasher.verify(verifier, 'wrong password'), isFalse);
  });

  test(
    'GivenExpensiveHashing_WhenStarted_ThenEventLoopAdvancesBeforeHashCompletes',
    () async {
      var hashingCompleted = false;
      final hashing = hasher.create('another correct horse battery staple');
      unawaited(
        hashing.then<void>((_) {
          hashingCompleted = true;
        }),
      );

      await Future<void>.delayed(Duration.zero);

      expect(hashingCompleted, isFalse);
      await hashing;
    },
  );
}
