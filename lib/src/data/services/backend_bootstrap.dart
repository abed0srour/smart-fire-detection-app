import 'package:smart_fire_detection_app/src/data/services/auth_service.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';
import 'package:smart_fire_detection_app/src/data/services/local_backend_service.dart';

class BackendBootstrap {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCXeVYjzDJG0Oz32y_91VZZxNOWB4JTNE0',
  );

  static const String deviceId = String.fromEnvironment(
    'DEVICE_ID',
    defaultValue: 'SD-2024-001-A',
  );

  static AuthService createAuthService() {
    return AuthService(
      firebaseApiKey: firebaseApiKey,
      backendBaseUrl: backendBaseUrl,
    );
  }

  static Future<BackendService> initialize() async {
    return LocalBackendService(deviceId: deviceId);
  }
}
