import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/platform/common/capability.dart';

abstract interface class AuthenticationPort
    implements CapabilityProbe, OperatingSystemAuthenticator {}
