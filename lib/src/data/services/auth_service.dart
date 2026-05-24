import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:smart_fire_detection_app/src/data/services/auth_session_storage.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';
import 'package:smart_fire_detection_app/src/data/services/remote_backend_service.dart';

class AuthSession {
  const AuthSession({
    required this.idToken,
    required this.refreshToken,
    required this.localId,
    required this.email,
    required this.expiresAt,
  });

  final String idToken;
  final String refreshToken;
  final String localId;
  final String email;
  final DateTime expiresAt;

  bool get shouldRefresh {
    return DateTime.now().isAfter(
      expiresAt.subtract(const Duration(minutes: 5)),
    );
  }

  AuthSession copyWith({
    String? idToken,
    String? refreshToken,
    String? localId,
    String? email,
    DateTime? expiresAt,
  }) {
    return AuthSession(
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      localId: localId ?? this.localId,
      email: email ?? this.email,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'idToken': idToken,
      'refreshToken': refreshToken,
      'localId': localId,
      'email': email,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory AuthSession.fromMap(Map<String, dynamic> map) {
    final expiresAt = DateTime.tryParse(map['expiresAt']?.toString() ?? '');
    if (expiresAt == null) {
      throw const AuthException('Stored session is invalid.');
    }

    return AuthSession(
      idToken: map['idToken']?.toString() ?? '',
      refreshToken: map['refreshToken']?.toString() ?? '',
      localId: map['localId']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      expiresAt: expiresAt,
    );
  }
}

class AuthService {
  AuthService({
    required this.firebaseApiKey,
    required this.backendBaseUrl,
    http.Client? client,
    AuthSessionStorage? sessionStorage,
  }) : _client = client ?? http.Client(),
       _sessionStorage = sessionStorage ?? createAuthSessionStorage();

  final String firebaseApiKey;
  final String backendBaseUrl;
  final http.Client _client;
  final AuthSessionStorage _sessionStorage;

  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async {
    return _firebasePasswordRequest(
      endpoint: 'accounts:signUp',
      email: email,
      password: password,
    );
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    return _firebasePasswordRequest(
      endpoint: 'accounts:signInWithPassword',
      email: email,
      password: password,
    );
  }

  Future<AuthSession> refreshSession(AuthSession session) async {
    final uri = Uri.https('securetoken.googleapis.com', '/v1/token', {
      'key': firebaseApiKey,
    });

    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': session.refreshToken,
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw AuthException(_messageFromFirebase(body));
    }

    final expiresIn =
        int.tryParse(body['expires_in']?.toString() ?? '') ?? 3600;
    return session.copyWith(
      idToken: body['id_token']?.toString(),
      refreshToken: body['refresh_token']?.toString(),
      localId: body['user_id']?.toString(),
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Future<void> saveSession(AuthSession session) async {
    await _sessionStorage.write(jsonEncode(session.toMap()));
  }

  Future<AuthSession?> restoreSession() async {
    final rawSession = await _sessionStorage.read();
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) {
        throw const AuthException('Stored session is invalid.');
      }

      var session = AuthSession.fromMap(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );

      if (session.refreshToken.isEmpty) {
        throw const AuthException('Stored session is missing a refresh token.');
      }

      if (session.idToken.isEmpty || session.shouldRefresh) {
        try {
          session = await refreshSession(session);
          await saveSession(session);
        } on AuthException {
          await clearSession();
          return null;
        } catch (_) {
          return session;
        }
      }

      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    await _sessionStorage.clear();
  }

  Future<void> saveProfile({
    required AuthSession session,
    required String fullName,
    required String phone,
    String? address,
  }) async {
    await backendRequest(
      method: 'POST',
      path: '/api/users/profile',
      idToken: session.idToken,
      body: {
        'fullName': fullName,
        'email': session.email,
        'phone': phone,
        'address': address,
      },
    );
  }

  Future<Map<String, dynamic>?> getProfile(AuthSession session) async {
    final data = await backendRequest(
      method: 'GET',
      path: '/api/users/profile',
      idToken: session.idToken,
    );
    if (data == null) {
      return null;
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Future<Object?> backendRequest({
    required String method,
    required String path,
    required String idToken,
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('${_normalizedBaseUrl()}$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };

    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => await _client.put(uri, headers: headers, body: encodedBody),
      'PATCH' => await _client.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => throw BackendException('Unsupported HTTP method: $method'),
    };

    final decoded = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw BackendException(_messageFromBackend(decoded, response.statusCode));
    }

    if (decoded['success'] == false) {
      throw BackendException(_messageFromBackend(decoded, response.statusCode));
    }

    return decoded.containsKey('data') ? decoded['data'] : decoded;
  }

  Future<AuthSession> _firebasePasswordRequest({
    required String endpoint,
    required String email,
    required String password,
  }) async {
    if (firebaseApiKey.isEmpty) {
      throw AuthException('Firebase API key is missing.');
    }

    final uri = Uri.https('identitytoolkit.googleapis.com', '/v1/$endpoint', {
      'key': firebaseApiKey,
    });

    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw AuthException(_messageFromFirebase(body));
    }

    final expiresIn = int.tryParse(body['expiresIn']?.toString() ?? '') ?? 3600;
    return AuthSession(
      idToken: body['idToken']?.toString() ?? '',
      refreshToken: body['refreshToken']?.toString() ?? '',
      localId: body['localId']?.toString() ?? '',
      email: body['email']?.toString() ?? email,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  String _normalizedBaseUrl() {
    return backendBaseUrl.endsWith('/')
        ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
        : backendBaseUrl;
  }
}

enum AuthStatus { signedOut, loading, signedIn }

class AuthController extends ChangeNotifier {
  AuthController({required AuthService authService, required this.deviceId})
    : _authService = authService {
    unawaited(_restoreSession());
  }

  final AuthService _authService;
  final String deviceId;

  AuthSession? _session;
  RemoteBackendService? _backend;
  AuthStatus _status = AuthStatus.loading;
  String? _errorMessage;
  bool _isDisposed = false;

  AuthStatus get status => _status;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isSignedIn => _status == AuthStatus.signedIn && _backend != null;
  String? get errorMessage => _errorMessage;
  BackendService? get backend => _backend;

  Future<void> signUpAndCreateProfile({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? address,
  }) async {
    await _runAuthAction(() async {
      final session = await _authService.signUp(
        email: email,
        password: password,
      );
      await _authService.saveProfile(
        session: session,
        fullName: fullName,
        phone: phone,
        address: address,
      );
      await _authService.saveSession(session);
      _activate(session);
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(() async {
      final session = await _authService.signIn(
        email: email,
        password: password,
      );
      final profile = await _authService.getProfile(session);
      if (profile == null) {
        throw BackendException(
          'No backend profile was found. Create an account first.',
        );
      }
      await _authService.saveSession(session);
      _activate(session);
    });
  }

  Future<String> validIdToken() async {
    final current = _session;
    if (current == null) {
      throw AuthException('You are not signed in.');
    }

    if (current.idToken.isNotEmpty && !current.shouldRefresh) {
      return current.idToken;
    }

    final refreshed = await _authService.refreshSession(current);
    _session = refreshed;
    await _authService.saveSession(refreshed);
    return refreshed.idToken;
  }

  void signOut() {
    unawaited(_authService.clearSession());
    _backend?.close();
    _backend = null;
    _session = null;
    _status = AuthStatus.signedOut;
    _errorMessage = null;
    _notify();
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _authService.restoreSession();
      if (session == null) {
        _status = AuthStatus.signedOut;
        _errorMessage = null;
        _notify();
        return;
      }

      Map<String, dynamic>? profile;
      try {
        profile = await _authService.getProfile(session);
      } on BackendException {
        profile = const <String, dynamic>{};
      }

      if (profile == null) {
        await _authService.clearSession();
        _status = AuthStatus.signedOut;
        _errorMessage = null;
        _notify();
        return;
      }

      _activate(session);
      _status = AuthStatus.signedIn;
      _errorMessage = null;
    } catch (_) {
      await _authService.clearSession();
      _backend?.close();
      _backend = null;
      _session = null;
      _status = AuthStatus.signedOut;
      _errorMessage = null;
    }

    _notify();
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _notify();

    try {
      await action();
      _status = AuthStatus.signedIn;
    } on AuthException catch (error) {
      _status = AuthStatus.signedOut;
      _errorMessage = error.message;
    } on BackendException catch (error) {
      _status = AuthStatus.signedOut;
      _errorMessage = error.message;
    } catch (error) {
      _status = AuthStatus.signedOut;
      _errorMessage = 'Unable to authenticate. Check backend and network.';
    }

    _notify();
  }

  void _activate(AuthSession session) {
    _session = session;
    _backend?.close();
    _backend = RemoteBackendService(
      baseUrl: _authService.backendBaseUrl,
      deviceId: deviceId,
      tokenProvider: validIdToken,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _backend?.close();
    super.dispose();
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, dynamic> _decodeBody(http.Response response) {
  if (response.body.isEmpty) {
    return <String, dynamic>{};
  }

  final decoded = jsonDecode(response.body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{'data': decoded};
}

String _messageFromFirebase(Map<String, dynamic> body) {
  final error = body['error'];
  if (error is Map) {
    final message = error['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return _humanizeFirebaseMessage(message);
    }
  }
  return 'Firebase authentication failed.';
}

String _messageFromBackend(Map<String, dynamic> body, int statusCode) {
  final message = body['message']?.toString();
  if (message != null && message.isNotEmpty) {
    return message;
  }
  return 'Backend request failed with status $statusCode.';
}

String _humanizeFirebaseMessage(String message) {
  switch (message) {
    case 'EMAIL_EXISTS':
      return 'This email is already registered.';
    case 'EMAIL_NOT_FOUND':
    case 'INVALID_LOGIN_CREDENTIALS':
    case 'INVALID_PASSWORD':
      return 'Invalid email or password.';
    case 'WEAK_PASSWORD : Password should be at least 6 characters':
      return 'Password should be at least 6 characters.';
    case 'CONFIGURATION_NOT_FOUND':
      return 'Firebase Authentication is not configured. Enable Email/Password sign-in for this Firebase project and use its Web API key.';
    case 'API key not valid. Please pass a valid API key.':
      return 'Firebase API key is invalid. Use the Web API key from Firebase project settings.';
    default:
      return message.replaceAll('_', ' ').toLowerCase();
  }
}
