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
///
/// `PWD` and `OLDPWD` are the shell's working directories: matching the bare
/// `PWD` word would blank the launch directory out of every path in run
/// output and diagnostics.
final RegExp _publicKeyPattern = RegExp(
  r'(?:(?:^|_)(?:PUBLIC_KEY|SSH_AUTH|HOST_KEY)|^(?:OLD)?PWD)$',
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
  /// An authorization header, quoted as in JSON or not, with the schemes
  /// credentials are sent under — GitHub's `token` among them.
  static final RegExp _authorization = RegExp(
    r'''(authorization["']?\s*:\s*["']?(?:bearer|basic|token)\s+)([^\s,;"']+)''',
    caseSensitive: false,
  );

  /// A secret-named key and its value: `password=…`, `GITHUB_TOKEN=…`,
  /// `ANTHROPIC_API_KEY="…"` and JSON's `"access_token":"…"` alike. The key
  /// may carry a prefix, so `\b` alone — which `_` does not break — is not
  /// the boundary.
  static final RegExp _assignment = RegExp(
    r'''((?<![A-Za-z0-9])[A-Za-z0-9_-]*?(?:password|passwd|pwd|token|secret|api[_-]?key)["']?)(\s*[=:]\s*)("[^"]*"|'[^']*'|[^\s,;]+)''',
    caseSensitive: false,
  );

  /// Credentials recognisable by shape alone, wherever they appear: GitHub
  /// tokens, Anthropic and OpenAI keys, Google access tokens, and JWTs.
  static final RegExp _tokenShape = RegExp(
    r'(?:\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|ya29\.[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,})|(?<![A-Za-z0-9])sk-(?:ant-)?[A-Za-z0-9_-]{20,})',
  );

  String redact(
    String input, {
    Map<String, String> environment = const <String, String>{},
  }) {
    // Exact values go first. A pattern that matched part of a secret holding
    // a delimiter would otherwise leave the rest of it in place, no longer
    // recognisable as the whole value.
    final secrets =
        secretValuesIn(
            environment,
          ).where((value) => value != '[REDACTED]').toList()
          ..sort((left, right) => right.length.compareTo(left.length));
    var output = input;
    for (final secret in secrets) {
      output = output.replaceAll(secret, '[REDACTED]');
    }
    output = output.replaceAllMapped(
      _authorization,
      (match) => '${match.group(1)}[REDACTED]',
    );
    output = output.replaceAllMapped(
      _assignment,
      (match) => match.group(3) == '[REDACTED]'
          ? match.group(0)!
          : '${match.group(1)}${match.group(2)}[REDACTED]',
    );
    return output.replaceAll(_tokenShape, '[REDACTED]');
  }
}
