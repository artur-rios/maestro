enum AgentCliKind {
  claudeCode('claude-code'),
  codex('codex'),
  openCode('opencode');

  const AgentCliKind(this.persistedValue);

  final String persistedValue;

  static AgentCliKind fromPersistedValue(String value) {
    for (final kind in values) {
      if (kind.persistedValue == value) return kind;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported agent CLI kind.');
  }
}
