import 'package:maestro/features/foundation/domain/foundation_status.dart';

abstract interface class FoundationProbe {
  String get id;

  Future<FoundationCheck> probe();
}
