abstract class AuthSessionStorage {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}
