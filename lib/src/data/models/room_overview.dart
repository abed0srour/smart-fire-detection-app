import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';

class RoomOverview {
  const RoomOverview({
    required this.id,
    required this.name,
    required this.location,
    required this.devices,
    this.createdAt,
  });

  final String id;
  final String name;
  final String location;
  final DateTime? createdAt;
  final List<RoomDevice> devices;

  factory RoomOverview.fromMap(
    Map<String, dynamic> map, {
    List<RoomDevice> devices = const <RoomDevice>[],
  }) {
    return RoomOverview(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Room',
      location: map['location']?.toString() ?? '',
      createdAt: _dateTimeFromBackendOrNull(map['createdAt']),
      devices: devices,
    );
  }

  bool get hasDevices => devices.isNotEmpty;

  bool get hasReading => currentReading != null;

  SensorData? get currentReading {
    SensorData? selected;

    for (final device in devices) {
      final reading = device.latestReading;
      if (reading == null) {
        continue;
      }

      if (selected == null ||
          _riskWeight(reading.riskLevel) > _riskWeight(selected.riskLevel) ||
          (_riskWeight(reading.riskLevel) == _riskWeight(selected.riskLevel) &&
              reading.lastUpdated.isAfter(selected.lastUpdated))) {
        selected = reading;
      }
    }

    return selected;
  }

  RiskLevel get riskLevel => currentReading?.riskLevel ?? RiskLevel.low;

  RoomOverview copyWith({
    String? id,
    String? name,
    String? location,
    DateTime? createdAt,
    List<RoomDevice>? devices,
  }) {
    return RoomOverview(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      devices: devices ?? this.devices,
    );
  }
}

class RoomDevice {
  const RoomDevice({
    required this.id,
    required this.roomId,
    required this.deviceCode,
    required this.name,
    required this.isOnline,
    required this.batteryLevel,
    required this.alarmMuted,
    this.lastSeen,
    this.latestReading,
  });

  final String id;
  final String roomId;
  final String deviceCode;
  final String name;
  final bool isOnline;
  final double batteryLevel;
  final bool alarmMuted;
  final DateTime? lastSeen;
  final SensorData? latestReading;

  factory RoomDevice.fromMap(
    Map<String, dynamic> map, {
    SensorData? latestReading,
  }) {
    final room = _mapFromBackend(map['roomId']);
    final id = map['_id']?.toString() ?? map['id']?.toString() ?? '';
    final deviceCode =
        map['deviceCode']?.toString() ?? map['deviceId']?.toString() ?? id;

    return RoomDevice(
      id: id,
      roomId:
          room?['_id']?.toString() ??
          room?['id']?.toString() ??
          map['roomId']?.toString() ??
          '',
      deviceCode: deviceCode,
      name: map['name']?.toString() ?? 'Fire Detector Device',
      isOnline: _boolFromBackend(map['isOnline'], false),
      batteryLevel: _doubleFromBackend(map['batteryLevel'], 0),
      alarmMuted: _boolFromBackend(map['alarmMuted'], false),
      lastSeen: _dateTimeFromBackendOrNull(map['lastSeen']),
      latestReading: latestReading,
    );
  }

  RoomDevice copyWith({
    String? id,
    String? roomId,
    String? deviceCode,
    String? name,
    bool? isOnline,
    double? batteryLevel,
    bool? alarmMuted,
    DateTime? lastSeen,
    SensorData? latestReading,
  }) {
    return RoomDevice(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      deviceCode: deviceCode ?? this.deviceCode,
      name: name ?? this.name,
      isOnline: isOnline ?? this.isOnline,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      alarmMuted: alarmMuted ?? this.alarmMuted,
      lastSeen: lastSeen ?? this.lastSeen,
      latestReading: latestReading ?? this.latestReading,
    );
  }
}

int _riskWeight(RiskLevel riskLevel) {
  switch (riskLevel) {
    case RiskLevel.low:
      return 0;
    case RiskLevel.medium:
      return 1;
    case RiskLevel.high:
      return 2;
    case RiskLevel.fire:
      return 3;
  }
}

Map<String, dynamic>? _mapFromBackend(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

bool _boolFromBackend(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

double _doubleFromBackend(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

DateTime? _dateTimeFromBackendOrNull(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
