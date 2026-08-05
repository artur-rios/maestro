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
        environment.values
            .where((value) => value.isNotEmpty && value != '[REDACTED]')
            .toSet()
            .toList()
          ..sort((left, right) => right.length.compareTo(left.length));
    for (final secret in secrets) {
      output = output.replaceAll(secret, '[REDACTED]');
    }
    return output;
  }
}
