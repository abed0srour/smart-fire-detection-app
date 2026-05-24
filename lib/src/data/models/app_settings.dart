class AppSettings {
  final String deviceId;
  final String emergencyPhoneNumber;
  final bool autoEmergencyCall;
  final bool notificationsEnabled;
  final double temperatureThreshold;
  final double smokeThreshold;
  final DateTime updatedAt;

  const AppSettings({
    required this.deviceId,
    required this.emergencyPhoneNumber,
    required this.autoEmergencyCall,
    required this.notificationsEnabled,
    required this.temperatureThreshold,
    required this.smokeThreshold,
    required this.updatedAt,
  });

  factory AppSettings.defaults({String deviceId = 'MASTER_ROOM'}) {
    return AppSettings(
      deviceId: deviceId,
      emergencyPhoneNumber: '+1-911-EMERGENCY',
      autoEmergencyCall: true,
      notificationsEnabled: true,
      temperatureThreshold: 50,
      smokeThreshold: 3000,
      updatedAt: DateTime.now(),
    );
  }

  factory AppSettings.fromMap(
    Map<String, dynamic> map, {
    required String deviceId,
  }) {
    return AppSettings(
      deviceId: deviceId,
      emergencyPhoneNumber:
          map['emergencyPhoneNumber']?.toString() ?? '+1-911-EMERGENCY',
      autoEmergencyCall: _boolFromBackend(map['autoEmergencyCall'], true),
      notificationsEnabled: _boolFromBackend(map['notificationsEnabled'], true),
      temperatureThreshold: _doubleFromBackend(map['temperatureThreshold'], 50),
      smokeThreshold: _doubleFromBackend(map['smokeThreshold'], 3000),
      updatedAt: _dateTimeFromBackend(map['updatedAt']),
    );
  }

  AppSettings copyWith({
    String? deviceId,
    String? emergencyPhoneNumber,
    bool? autoEmergencyCall,
    bool? notificationsEnabled,
    double? temperatureThreshold,
    double? smokeThreshold,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      deviceId: deviceId ?? this.deviceId,
      emergencyPhoneNumber: emergencyPhoneNumber ?? this.emergencyPhoneNumber,
      autoEmergencyCall: autoEmergencyCall ?? this.autoEmergencyCall,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      temperatureThreshold: temperatureThreshold ?? this.temperatureThreshold,
      smokeThreshold: smokeThreshold ?? this.smokeThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'deviceId': deviceId,
      'emergencyPhoneNumber': emergencyPhoneNumber,
      'autoEmergencyCall': autoEmergencyCall,
      'notificationsEnabled': notificationsEnabled,
      'temperatureThreshold': temperatureThreshold,
      'smokeThreshold': smokeThreshold,
      'updatedAt': updatedAt,
    };
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
