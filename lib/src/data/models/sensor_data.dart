/// Sensor data model for fire detection system.
class SensorData {
  final String deviceId;
  final double temperature;
  final double smokeLevel;
  final double humidity;
  final double coLevel;
  final double lightLevel;
  final double flameLevel;
  final double batteryLevel;
  final RiskLevel riskLevel;
  final bool flameDetected;
  final bool isConnected;
  final bool alarmMuted;
  final DateTime lastUpdated;

  const SensorData({
    this.deviceId = 'MASTER_ROOM',
    required this.temperature,
    required this.smokeLevel,
    required this.riskLevel,
    required this.isConnected,
    required this.lastUpdated,
    this.humidity = 0,
    this.coLevel = 0,
    this.lightLevel = 0,
    this.flameLevel = 0,
    this.batteryLevel = 0,
    this.flameDetected = false,
    this.alarmMuted = false,
  });

  factory SensorData.fromMap(Map<String, dynamic> map, {String? deviceId}) {
    final device = _mapFromBackend(map['deviceId']);
    final flameDetected = _boolFromBackend(map['flameDetected'], false);
    
    var status = map['riskLevel'] ?? map['status'];
    if (status == null) {
      final temp = _doubleFromBackend(map['temperature'], 0);
      final smoke = _doubleFromBackend(map['smokeLevel'], 0);
      if (flameDetected || temp > 50.0 || smoke > 3000) {
        status = 'danger';
      } else if (temp >= 40.0 || smoke >= 300) {
        status = 'warning';
      } else {
        status = 'safe';
      }
    }

    final riskLevel = riskLevelFromBackend(
      status,
      flameDetected: flameDetected,
    );

    return SensorData(
      deviceId:
          deviceId ??
          device?['deviceCode']?.toString() ??
          device?['deviceId']?.toString() ??
          map['deviceId']?.toString() ??
          map['deviceCode']?.toString() ??
          'MASTER_ROOM',
      temperature: _doubleFromBackend(map['temperature'], 0),
      smokeLevel: _doubleFromBackend(map['smokeLevel'], 0),
      humidity: _doubleFromBackend(map['humidity'], 0),
      coLevel: _doubleFromBackend(map['coLevel'] ?? map['co2Level'], 0),
      lightLevel: _doubleFromBackend(map['lightLevel'], 0),
      flameLevel: _doubleFromBackend(map['flameLevel'], 0),
      batteryLevel: _doubleFromBackend(
        map['batteryLevel'] ?? device?['batteryLevel'],
        0,
      ),
      riskLevel: riskLevel,
      flameDetected: flameDetected,
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
    double? lightLevel,
    double? flameLevel,
    double? batteryLevel,
    RiskLevel? riskLevel,
    bool? flameDetected,
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
      lightLevel: lightLevel ?? this.lightLevel,
      flameLevel: flameLevel ?? this.flameLevel,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      riskLevel: riskLevel ?? this.riskLevel,
      flameDetected: flameDetected ?? this.flameDetected,
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
      'lightLevel': lightLevel,
      'flameLevel': flameLevel,
      'batteryLevel': batteryLevel,
      'riskLevel': riskLevel.backendValue,
      'flameDetected': flameDetected,
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
      return RiskLevel.high;
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
  final double lightLevel;
  final double flameLevel;
  final RiskLevel riskLevel;
  final String status;
  final bool flameDetected;
  final bool acknowledged;
  final bool muted;
  final bool emergencyCallRequested;

  const AlertHistory({
    this.id = '',
    this.deviceId = 'MASTER_ROOM',
    required this.timestamp,
    required this.temperature,
    required this.smokeLevel,
    required this.riskLevel,
    required this.status,
    this.humidity = 0,
    this.coLevel = 0,
    this.lightLevel = 0,
    this.flameLevel = 0,
    this.flameDetected = false,
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
    final reading =
        _mapFromBackend(map['readingId']) ?? _mapFromBackend(map['reading']);
    final flameDetected = _boolFromBackend(
      map['flameDetected'] ?? reading?['flameDetected'],
      false,
    );
    final riskLevel = riskLevelFromBackend(
      map['riskLevel'] ??
          reading?['riskLevel'] ??
          map['status'] ??
          reading?['status'] ??
          map['type'] ??
          map['severity'],
      flameDetected: flameDetected,
    );
    final status =
        map['message']?.toString() ??
        map['status']?.toString() ??
        reading?['status']?.toString();

    return AlertHistory(
      id: id ?? map['id']?.toString() ?? map['_id']?.toString() ?? '',
      deviceId:
          deviceId ??
          device?['deviceCode']?.toString() ??
          device?['deviceId']?.toString() ??
          map['deviceId']?.toString() ??
          'MASTER_ROOM',
      timestamp: _dateTimeFromBackend(
        map['timestamp'] ?? map['createdAt'] ?? map['updatedAt'],
      ),
      temperature: _doubleFromBackend(
        map['temperature'] ?? reading?['temperature'],
        0,
      ),
      smokeLevel: _doubleFromBackend(
        map['smokeLevel'] ?? reading?['smokeLevel'],
        0,
      ),
      humidity: _doubleFromBackend(map['humidity'] ?? reading?['humidity'], 0),
      coLevel: _doubleFromBackend(
        map['coLevel'] ??
            map['co2Level'] ??
            reading?['coLevel'] ??
            reading?['co2Level'],
        0,
      ),
      lightLevel: _doubleFromBackend(
        map['lightLevel'] ?? reading?['lightLevel'],
        0,
      ),
      flameLevel: _doubleFromBackend(
        map['flameLevel'] ?? reading?['flameLevel'],
        0,
      ),
      riskLevel: riskLevel,
      flameDetected: flameDetected,
      status: _statusForDisplay(status, riskLevel),
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
      'lightLevel': lightLevel,
      'flameLevel': flameLevel,
      'riskLevel': riskLevel.backendValue,
      'flameDetected': flameDetected,
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

/// Local data provider used when the remote API is not connected.
class LocalDataProvider {
  // Current sensor data
  static SensorData getCurrentSensorData() {
    return SensorData(
      deviceId: 'MASTER_ROOM',
      temperature: 28.5,
      smokeLevel: 15.0,
      humidity: 45.0,
      coLevel: 12.0,
      lightLevel: 650.0,
      flameLevel: 0,
      batteryLevel: 85.0,
      riskLevel: RiskLevel.low,
      flameDetected: false,
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
        lightLevel: 620.0,
        flameLevel: 0,
        flameDetected: false,
        riskLevel: RiskLevel.high,
        status: 'High Risk Detected',
      ),
      AlertHistory(
        timestamp: DateTime.now().subtract(Duration(hours: 5)),
        temperature: 32.1,
        smokeLevel: 28.5,
        humidity: 48.0,
        coLevel: 14.0,
        lightLevel: 640.0,
        flameLevel: 0,
        flameDetected: false,
        riskLevel: RiskLevel.medium,
        status: 'Medium Risk Alert',
      ),
      AlertHistory(
        timestamp: DateTime.now().subtract(Duration(hours: 12)),
        temperature: 26.8,
        smokeLevel: 12.0,
        humidity: 43.0,
        coLevel: 10.0,
        lightLevel: 680.0,
        flameLevel: 0,
        flameDetected: false,
        riskLevel: RiskLevel.low,
        status: 'Low Risk Reading',
      ),
      AlertHistory(
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        temperature: 29.5,
        smokeLevel: 18.0,
        humidity: 45.0,
        coLevel: 11.0,
        lightLevel: 660.0,
        flameLevel: 0,
        flameDetected: false,
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
      return 'Danger: High Gas Leakage';
    case RiskLevel.fire:
      return 'Fire Detected';
  }
}

String _statusForDisplay(String? status, RiskLevel riskLevel) {
  if (riskLevel == RiskLevel.high) {
    return _statusForRiskLevel(RiskLevel.high);
  }
  if (riskLevel == RiskLevel.fire) {
    return _statusForRiskLevel(RiskLevel.fire);
  }
  return status ?? _statusForRiskLevel(riskLevel);
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
