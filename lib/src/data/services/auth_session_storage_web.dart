// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:smart_fire_detection_app/src/data/services/auth_session_storage_base.dart';

class WebAuthSessionStorage implements AuthSessionStorage {
  const WebAuthSessionStorage();

  static const String _key = 'smart_fire_detection_auth_session_v1';

  @override
  Future<String?> read() async {
    return html.window.localStorage[_key];
  }

  @override
  Future<void> write(String value) async {
    html.window.localStorage[_key] = value;
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_key);
  }
}

AuthSessionStorage createAuthSessionStorage() {
  return const WebAuthSessionStorage();
}
