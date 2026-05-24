import 'package:smart_fire_detection_app/src/data/services/auth_session_storage_base.dart';

class NoopAuthSessionStorage implements AuthSessionStorage {
  const NoopAuthSessionStorage();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}

AuthSessionStorage createAuthSessionStorage() {
  return const NoopAuthSessionStorage();
}
