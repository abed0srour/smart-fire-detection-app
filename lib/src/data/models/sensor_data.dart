/// Sensor data model for fire detection system.
class SensorData {
  final String deviceId;
  final double temperature;
  final double smokeLevel;
  final double humidity;
  final double coLevel;
  final double batteryLevel;
  final RiskLevel riskLevel;
  final bool isConnected;
  final bool alarmMuted;
  final DateTime lastUpdated;

  const SensorData({
    this.deviceId = 'SD-2024-001-A',
    required this.temperature,
    required this.smokeLevel,
    required this.riskLevel,
    required this.isConnected,
    required this.lastUpdated,
    this.humidity = 0,
    this.coLevel = 0,
    this.batteryLevel = 0,
    this.alarmMuted = false,
  });

  factory SensorData.fromMap(Map<String, dynamic> map, {String? deviceId}) {
    final device = _mapFromBackend(map['deviceId']);
    final status = map['riskLevel'] ?? map['status'];
    final riskLevel = riskLevelFromBackend(
      status,
      flameDetected: _boolFromBackend(map['flameDetected'], false),
    );

    return SensorData(
      deviceId:
          deviceId ??
          device?['deviceId']?.toString() ??
          device?['deviceCode']?.toString() ??
          map['deviceId']?.toString() ??
          'SD-2024-001-A',
      temperature: _doubleFromBackend(map['temperature'], 0),
      smokeLevel: _doubleFromBackend(map['smokeLevel'], 0),
      humidity: _doubleFromBackend(map['humidity'], 0),
      coLevel: _doubleFromBackend(map['coLevel'] ?? map['co2Level'], 0),
      batteryLevel: _doubleFromBackend(
        map['batteryLevel'] ?? device?['batteryLevel'],
        0,
      ),
      riskLevel: riskLevel,
      isConnected: _boolFromBackend(
        map['isConnected'] ?? map['isOnline'] ?? device?['isOnline'],
        false,
      ),
      alarmMuted: _boolFromBackend(
        map['alarmMuted'] ?? device?['alarmMuted'],
        false,
      ),
      lastUpdated: _dateTimeFromBackend(
        map['lastUpdated'] ??
            map['updatedAt'] ??
            map['createdAt'] ??
            device?['lastSeen'],
      ),
    );
  }

  SensorData copyWith({
    String? deviceId,
    double? temperature,
    double? smokeLevel,
    double? humidity,
    double? coLevel,
    double? batteryLevel,
    RiskLevel? riskLevel,
    bool? isConnected,
    bool? alarmMuted,
    DateTime? lastUpdated,
  }) {
    return SensorData(
      deviceId: deviceId ?? this.deviceId,
      temperature: temperature ?? this.temperature,
      smokeLevel: smokeLevel ?? this.smokeLevel,
      humidity: humidity ?? this.humidity,
      coLevel: coLevel ?? this.coLevel,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      riskLevel: riskLevel ?? this.riskLevel,
      isConnected: isConnected ?? this.isConnected,
      alarmMuted: alarmMuted ?? this.alarmMuted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'deviceId': deviceId,
      'temperature': temperature,
      'smokeLevel': smokeLevel,
      'humidity': humidity,
      'coLevel': coLevel,
      'batteryLevel': batteryLevel,
      'riskLevel': riskLevel.backendValue,
      'isConnected': isConnected,
      'alarmMuted': alarmMuted,
      'lastUpdated': lastUpdated,
    };
  }
}

/// Risk level enum.
enum RiskLevel { low, medium, high, fire }

extension RiskLevelSerialization on RiskLevel {
  String get backendValue {
    switch (this) {
      case RiskLevel.low:
        return 'low';
      case RiskLevel.medium:
        return 'medium';
      case RiskLevel.high:
        return 'high';
      case RiskLevel.fire:
        return 'fire';
    }
  }

  String get displayLabel {
    switch (this) {
      case RiskLevel.low:
        return 'LOW';
      case RiskLevel.medium:
        return 'MEDIUM';
      case RiskLevel.high:
        return 'HIGH';
      case RiskLevel.fire:
        return 'FIRE';
    }
  }
}

RiskLevel riskLevelFromBackend(Object? value, {bool flameDetected = false}) {
  if (flameDetected) {
    return RiskLevel.fire;
  }

  switch (value?.toString().toLowerCase()) {
    case 'medium':
    case 'warning':
      return RiskLevel.medium;
    case 'high':
    case 'danger':
      return RiskLevel.high;
    case 'fire':
    case 'critical':
      return RiskLevel.fire;
    case 'low':
    case 'safe':
    default:
      return RiskLevel.low;
  }
}

/// Alert history item model.
class AlertHistory {
  final String id;
  final String deviceId;
  final DateTime timestamp;
  final double temperature;
  final double smokeLevel;
  final double humidity;
  final double coLevel;
  final RiskLevel riskLevel;
  final String status;
  final bool acknowledged;
  final bool muted;
  final bool emergencyCallRequested;

  const AlertHistory({
    this.id = '',
    this.deviceId = 'SD-2024-001-A',
    required this.timestamp,
    required this.temperature,
    required this.smokeLevel,
    required this.riskLevel,
    required this.status,
    this.humidity = 0,
    this.coLevel = 0,
    this.acknowledged = false,
    this.muted = false,
    this.emergencyCallRequested = false,
  });

  factory AlertHistory.fromMap(
    Map<String, dynamic> map, {
    String? id,
    String? deviceId,
  }) {
    final device = _mapFromBackend(map['deviceId']);
    final riskLevel = riskLevelFromBackend(
      map['riskLevel'] ?? map['severity'] ?? map['status'] ?? map['type'],
      flameDetected: _boolFromBackend(map['flameDetected'], false),
    );
    return AlertHistory(
      id: id ?? map['id']?.toString() ?? map['_id']?.toString() ?? '',
      deviceId:
          deviceId ??
          device?['deviceId']?.toString() ??
          device?['deviceCode']?.toString() ??
          map['deviceId']?.toString() ??
          'SD-2024-001-A',
      timestamp: _dateTimeFromBackend(
        map['timestamp'] ?? map['createdAt'] ?? map['updatedAt'],
      ),
      temperature: _doubleFromBackend(map['temperature'], 0),
      smokeLevel: _doubleFromBackend(map['smokeLevel'], 0),
      humidity: _doubleFromBackend(map['humidity'], 0),
      coLevel: _doubleFromBackend(map['coLevel'] ?? map['co2Level'], 0),
      riskLevel: riskLevel,
      status:
          map['status']?.toString() ??
          map['message']?.toString() ??
          _statusForRiskLevel(riskLevel),
      acknowledged: _boolFromBackend(
        map['acknowledged'] ?? map['isRead'],
        false,
      ),
      muted: _boolFromBackend(map['muted'], false),
      emergencyCallRequested: _boolFromBackend(
        map['emergencyCallRequested'],
        false,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'deviceId': deviceId,
      'timestamp': timestamp,
      'temperature': temperature,
      'smokeLevel': smokeLevel,
      'humidity': humidity,
      'coLevel': coLevel,
      'riskLevel': riskLevel.backendValue,
      'status': status,
      'acknowledged': acknowledged,
      'muted': muted,
      'emergencyCallRequested': emergencyCallRequested,
    };
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

/// Local data provider used until the Laravel API is connected.
class LocalDataProvider {
  // Current sensor data
  static SensorData getCurrentSensorData() {
    return SensorData(
      deviceId: 'SD-2024-001-A',
      temperature: 28.5,
      smokeLevel: 15.0,
      humidity: 45.0,
      coLevel: 12.0,
      batteryLevel: 85.0,
      riskLevel: RiskLevel.low,
      isConnected: true,
      lastUpdated: DateTime.now(),
    );
  }

  // Alert history data
  static List<AlertHistory> getAlertHistory() {
    return [
      AlertHistory(
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        temperature: 35.2,
        smokeLevel: 45.0,
        humidity: 50.0,
        coLevel: 18.0,
        riskLevel: RiskLevel.high,
        status: 'High Risk Detected',
      ),
      AlertHistory(
        timestamp: DateTime.now().subtract(Duration(hours: 5)),
        temperature: 32.1,
        smokeLevel: 28.5,
        humidity: 48.0,
        coLevel: 14.0,
        riskLevel: RiskLevel.medium,
        status: 'Medium Risk Alert',
      ),
      AlertHistory(
        timestamp: DateTime.now().subtract(Duration(hours: 12)),
        temperature: 26.8,
        smokeLevel: 12.0,
        humidity: 43.0,
        coLevel: 10.0,
        riskLevel: RiskLevel.low,
        status: 'Low Risk Reading',
      ),
      AlertHistory(
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        temperature: 29.5,
        smokeLevel: 18.0,
        humidity: 45.0,
        coLevel: 11.0,
        riskLevel: RiskLevel.low,
        status: 'Normal Status',
      ),
    ];
  }
}

String _statusForRiskLevel(RiskLevel riskLevel) {
  switch (riskLevel) {
    case RiskLevel.low:
      return 'Low Risk Reading';
    case RiskLevel.medium:
      return 'Medium Risk Alert';
    case RiskLevel.high:
      return 'High Risk Detected';
    case RiskLevel.fire:
      return 'Fire Detected';
  }
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

DateTime _dateTimeFromBackend(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  try {
    final converted = (value as dynamic)?.toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    // Backend timestamp objects are optional here so tests can use plain maps.
  }

  return DateTime.now();
}
