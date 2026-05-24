import 'package:smart_fire_detection_app/src/data/models/app_settings.dart';
import 'package:smart_fire_detection_app/src/data/models/room_overview.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';

abstract class BackendService {
  String get deviceId;

  bool get isRemoteBackend;

  String get backendName;

  Stream<SensorData> watchCurrentSensorData();

  Stream<List<AlertHistory>> watchAlertHistory({int limit = 50});

  Stream<AppSettings> watchSettings();

  Stream<List<RoomOverview>> watchRoomOverviews();

  Future<RoomOverview> createRoom({
    required String name,
    String? location,
    String? deviceCode,
  });

  Future<RoomOverview> updateRoom({
    required String roomId,
    required String name,
    String? location,
  });

  Future<void> deleteRoom(String roomId);

  Future<void> saveSettings(AppSettings settings);

  Future<void> requestEmergencyCall({String source = 'app'});

  Future<void> setAlarmMuted(bool muted);

  Future<void> resetLocalData();
}
