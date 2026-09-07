/// Whether an environment variable's name marks its value as a secret.
///
/// Matching on shape rather than a fixed list means a token this build has
/// never heard of — `GH_TOKEN`, a provider key added next month — is redacted
/// on the day it appears rather than the day someone remembers to list it.
bool isSecretEnvironmentKey(String key) =>
    _secretKeyPattern.hasMatch(key) && !_publicKeyPattern.hasMatch(key);

final RegExp _secretKeyPattern = RegExp(
  r'(?:^|_)(?:TOKEN|SECRET|PASSWORD|PASSWD|PWD|APIKEY|KEY|CREDENTIAL|CREDENTIALS|AUTH)$',
  caseSensitive: false,
);

/// Names that end in a secret-shaped word but never hold one.
///
/// Every entry has to be reachable: [_secretKeyPattern] only matches names
/// ending in one of its own words, so `KEYMAP` and `KEYBOARD` — which end in
/// neither `KEY` nor anything else it lists — could never have been excluded
/// by this, and their presence only suggested a breadth it did not have.
final RegExp _publicKeyPattern = RegExp(
  r'(?:^|_)(?:PUBLIC_KEY|SSH_AUTH|HOST_KEY)$',
  caseSensitive: false,
);

/// The shortest value worth redacting.
///
/// A one- or two-character value is far more likely to be a flag than a
/// credential, and blanking those would turn ordinary output into noise.
const int minimumRedactableSecretLength = 8;

/// The secret values carried by [environment], by key shape and length.
List<String> secretValuesIn(Map<String, String> environment) => environment
    .entries
    .where(
      (entry) =>
          isSecretEnvironmentKey(entry.key) &&
          entry.value.length >= minimumRedactableSecretLength,
    )
    .map((entry) => entry.value)
    .toSet()
    .toList(growable: false);

final class SecretRedactor {
  static final RegExp _authorization = RegExp(
    r'(authorization\s*:\s*(?:bearer|basic)\s+)([^\s,;]+)',
    caseSensitive: false,
  );
  static final RegExp _assignment = RegExp(
    r'''\b(password|passwd|pwd|token|secret|api[_-]?key)(\s*[=:]\s*)("[^"]*"|'[^']*'|[^\s,;]+)''',
    caseSensitive: false,
  );

  String redact(
    String input, {
    Map<String, String> environment = const <String, String>{},
  }) {
    var output = input.replaceAllMapped(
      _authorization,
      (match) => '${match.group(1)}[REDACTED]',
    );
    output = output.replaceAllMapped(
      _assignment,
      (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
    );

    final secrets =
        secretValuesIn(
            environment,
          ).where((value) => value != '[REDACTED]').toList()
          ..sort((left, right) => right.length.compareTo(left.length));
    for (final secret in secrets) {
      output = output.replaceAll(secret, '[REDACTED]');
    }
    return output;
  }
}
