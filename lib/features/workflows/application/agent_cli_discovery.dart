import 'package:maestro/core/agents/agent_cli_kind.dart';

enum AgentCliInstallation { available, missing, inaccessible, transientFailure }

enum AgentCliSession { authenticated, unauthenticated, unverified }

enum AgentModelVerification { accountVerified, cliOnly, unverified }

final class AgentCliCatalog {
  AgentCliCatalog({
    required this.kind,
    required this.installation,
    required this.session,
    required this.modelVerification,
    required Iterable<String> models,
    required this.guidance,
    this.version,
  }) : models = List<String>.unmodifiable(models);

  final AgentCliKind kind;
  final AgentCliInstallation installation;
  final AgentCliSession session;
  final AgentModelVerification modelVerification;
  final List<String> models;
  final String guidance;
  final String? version;
}

abstract interface class AgentCliAdapter {
  AgentCliKind get kind;

  Future<AgentCliCatalog> discover();
}
