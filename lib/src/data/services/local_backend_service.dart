import 'dart:async';

import 'package:smart_fire_detection_app/src/data/models/app_settings.dart';
import 'package:smart_fire_detection_app/src/data/models/room_overview.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';

class LocalBackendService implements BackendService {
  LocalBackendService({this.deviceId = 'SD-2024-001-A'}) {
    _sensorData = LocalDataProvider.getCurrentSensorData().copyWith(
      deviceId: deviceId,
    );
    _alerts = LocalDataProvider.getAlertHistory();
    _settings = AppSettings.defaults(deviceId: deviceId);
    _rooms = [_buildLocalRoom(_sensorData, index: 0)];
  }

  @override
  final String deviceId;

  late SensorData _sensorData;
  late List<AlertHistory> _alerts;
  late AppSettings _settings;
  late List<RoomOverview> _rooms;

  final StreamController<SensorData> _sensorController =
      StreamController<SensorData>.broadcast();
  final StreamController<List<AlertHistory>> _alertsController =
      StreamController<List<AlertHistory>>.broadcast();
  final StreamController<AppSettings> _settingsController =
      StreamController<AppSettings>.broadcast();
  final StreamController<List<RoomOverview>> _roomsController =
      StreamController<List<RoomOverview>>.broadcast();

  @override
  bool get isRemoteBackend => false;

  @override
  String get backendName => 'Local';

  @override
  Stream<SensorData> watchCurrentSensorData() async* {
    yield _sensorData;
    yield* _sensorController.stream;
  }

  @override
  Stream<List<AlertHistory>> watchAlertHistory({int limit = 50}) async* {
    yield _alerts.take(limit).toList();
    yield* _alertsController.stream;
  }

  @override
  Stream<AppSettings> watchSettings() async* {
    yield _settings;
    yield* _settingsController.stream;
  }

  @override
  Stream<List<RoomOverview>> watchRoomOverviews() async* {
    yield _rooms;
    yield* _roomsController.stream;
  }

  @override
  Future<RoomOverview> createRoom({
    required String name,
    String? location,
    String? deviceCode,
  }) async {
    final trimmedName = name.trim();
    final createdAt = DateTime.now();
    final index = _rooms.length;
    final resolvedDeviceCode = (deviceCode == null || deviceCode.trim().isEmpty)
        ? 'LOCAL-ROOM-${index + 1}'
        : deviceCode.trim();
    final reading = _sampleSensorData(
      deviceCode: resolvedDeviceCode,
      index: index,
      updatedAt: createdAt,
    );
    final room = _buildLocalRoom(
      reading,
      index: index,
      id: 'local-room-${createdAt.microsecondsSinceEpoch}',
      name: trimmedName.isEmpty ? 'Room ${index + 1}' : trimmedName,
      location: location?.trim() ?? '',
      createdAt: createdAt,
    );

    _rooms = [room, ..._rooms];
    _roomsController.add(_rooms);
    return room;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings.copyWith(updatedAt: DateTime.now());
    _settingsController.add(_settings);
  }

  @override
  Future<void> requestEmergencyCall({String source = 'app'}) async {
    final alert = AlertHistory(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      deviceId: deviceId,
      timestamp: DateTime.now(),
      temperature: _sensorData.temperature,
      smokeLevel: _sensorData.smokeLevel,
      humidity: _sensorData.humidity,
      coLevel: _sensorData.coLevel,
      riskLevel: _sensorData.riskLevel,
      status: 'Emergency call requested',
      emergencyCallRequested: true,
    );
    _alerts = [alert, ..._alerts];
    _alertsController.add(_alerts);
  }

  @override
  Future<void> setAlarmMuted(bool muted) async {
    _sensorData = _sensorData.copyWith(alarmMuted: muted);
    _sensorController.add(_sensorData);
    _syncRoomReading(_sensorData);
  }

  @override
  Future<void> resetLocalData() async {
    _sensorData = LocalDataProvider.getCurrentSensorData().copyWith(
      deviceId: deviceId,
    );
    _alerts = LocalDataProvider.getAlertHistory();
    _settings = AppSettings.defaults(deviceId: deviceId);
    _rooms = [_buildLocalRoom(_sensorData, index: 0)];
    _sensorController.add(_sensorData);
    _alertsController.add(_alerts);
    _settingsController.add(_settings);
    _roomsController.add(_rooms);
  }

  RoomOverview _buildLocalRoom(
    SensorData reading, {
    required int index,
    String? id,
    String? name,
    String? location,
    DateTime? createdAt,
  }) {
    final roomId = id ?? 'local-main-room';
    return RoomOverview(
      id: roomId,
      name: name ?? 'Main Room',
      location: location ?? 'Default',
      createdAt: createdAt ?? DateTime.now(),
      devices: [
        RoomDevice(
          id: 'local-device-$index',
          roomId: roomId,
          deviceCode: reading.deviceId,
          name: 'Fire Detector Device',
          isOnline: reading.isConnected,
          batteryLevel: reading.batteryLevel,
          alarmMuted: reading.alarmMuted,
          lastSeen: reading.lastUpdated,
          latestReading: reading,
        ),
      ],
    );
  }

  SensorData _sampleSensorData({
    required String deviceCode,
    required int index,
    required DateTime updatedAt,
  }) {
    final riskLevel = switch (index % 4) {
      1 => RiskLevel.medium,
      2 => RiskLevel.high,
      _ => RiskLevel.low,
    };

    return SensorData(
      deviceId: deviceCode,
      temperature: 25 + (index * 4.5),
      smokeLevel: 12 + (index * 8),
      humidity: 42 + (index * 2),
      coLevel: 10 + (index * 3),
      batteryLevel: (92 - (index * 6)).clamp(45, 100).toDouble(),
      riskLevel: riskLevel,
      isConnected: true,
      lastUpdated: updatedAt,
    );
  }

  void _syncRoomReading(SensorData reading) {
    _rooms = _rooms.map((room) {
      final devices = room.devices.map((device) {
        if (device.deviceCode != reading.deviceId) {
          return device;
        }

        return device.copyWith(
          isOnline: reading.isConnected,
          batteryLevel: reading.batteryLevel,
          alarmMuted: reading.alarmMuted,
          lastSeen: reading.lastUpdated,
          latestReading: reading,
        );
      }).toList();

      return room.copyWith(devices: devices);
    }).toList();
    _roomsController.add(_rooms);
  }
}
