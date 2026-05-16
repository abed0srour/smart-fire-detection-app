import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:smart_fire_detection_app/src/data/models/room_overview.dart';
import 'package:smart_fire_detection_app/src/data/models/app_settings.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';

typedef TokenProvider = Future<String> Function();

class RemoteBackendService implements BackendService {
  RemoteBackendService({
    required String baseUrl,
    required this.deviceId,
    required TokenProvider tokenProvider,
    http.Client? client,
    this.pollInterval = const Duration(seconds: 5),
  }) : baseUrl = _normalizeBaseUrl(baseUrl),
       _tokenProvider = tokenProvider,
       _client = client ?? http.Client();

  final String baseUrl;
  final TokenProvider _tokenProvider;
  final http.Client _client;
  final Duration pollInterval;

  final StreamController<SensorData> _sensorController =
      StreamController<SensorData>.broadcast();
  final StreamController<List<AlertHistory>> _alertHistoryController =
      StreamController<List<AlertHistory>>.broadcast();
  final StreamController<List<RoomOverview>> _roomsController =
      StreamController<List<RoomOverview>>.broadcast();
  final StreamController<AppSettings> _settingsController =
      StreamController<AppSettings>.broadcast();

  late final Stream<SensorData> _sensorStream = Stream<SensorData>.multi((
    controller,
  ) {
    final cached = _cachedSensorData;
    if (cached != null) {
      controller.add(cached);
    }

    final subscription = _sensorController.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  late final Stream<List<AlertHistory>> _alertHistoryStream =
      _createAlertHistoryStream(limit: 50);

  late final Stream<List<RoomOverview>> _roomOverviewStream =
      Stream<List<RoomOverview>>.multi((controller) {
        final cached = _cachedRoomOverviews;
        if (cached != null) {
          controller.add(cached);
        }

        final subscription = _roomsController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
      });

  _BackendRoom? _cachedRoom;
  _BackendDevice? _cachedDevice;
  SensorData? _cachedSensorData;
  List<AlertHistory>? _cachedAlertHistory;
  List<RoomOverview>? _cachedRoomOverviews;

  io.Socket? _socket;
  Future<void>? _socketStart;
  Future<void>? _sensorLoad;
  Future<void>? _alertHistoryLoad;
  Future<void>? _roomsLoad;
  int _alertHistoryLimit = 0;
  bool _isClosed = false;

  @override
  final String deviceId;

  @override
  bool get isRemoteBackend => true;

  @override
  String get backendName {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) {
      return 'Node API';
    }
    return 'Node API (${uri.host}:${uri.port})';
  }

  @override
  Stream<SensorData> watchCurrentSensorData() {
    _startRealtime();
    unawaited(_loadCurrentSensorData());
    return _sensorStream;
  }

  @override
  Stream<List<AlertHistory>> watchAlertHistory({int limit = 50}) {
    _startRealtime();
    unawaited(_loadAlertHistory(limit: limit));
    if (limit == 50) {
      return _alertHistoryStream;
    }
    return _createAlertHistoryStream(limit: limit);
  }

  @override
  Stream<AppSettings> watchSettings() async* {
    yield await _fetchSettings();
    yield* _settingsController.stream;
  }

  @override
  Stream<List<RoomOverview>> watchRoomOverviews() {
    _startRealtime();
    unawaited(_loadRoomOverviews());
    return _roomOverviewStream;
  }

  @override
  Future<RoomOverview> createRoom({
    required String name,
    String? location,
    String? deviceCode,
  }) async {
    final createdRoom = _asMap(
      await _request(
        method: 'POST',
        path: '/api/rooms',
        body: {'name': name.trim(), 'location': location?.trim()},
      ),
    );
    final room = RoomOverview.fromMap(createdRoom ?? <String, dynamic>{});
    final trimmedDeviceCode = deviceCode?.trim();

    if (trimmedDeviceCode == null || trimmedDeviceCode.isEmpty) {
      unawaited(_loadRoomOverviews(force: true));
      return room;
    }

    try {
      final createdDevice = _asMap(
        await _request(
          method: 'POST',
          path: '/api/devices',
          body: {
            'roomId': room.id,
            'deviceId': trimmedDeviceCode,
            'deviceCode': trimmedDeviceCode,
            'name': '${room.name} Detector',
            'batteryLevel': 100,
          },
        ),
      );
      final device = RoomDevice.fromMap(createdDevice ?? <String, dynamic>{});
      unawaited(_loadRoomOverviews(force: true));
      return room.copyWith(devices: [device]);
    } on RemoteBackendException catch (error) {
      unawaited(_loadRoomOverviews(force: true));
      throw RemoteBackendException(
        'Room created, but device could not be attached: ${error.message}',
      );
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final room = await _primaryRoom();
    final dangerTemperature = settings.temperatureThreshold;
    final warningTemperature = (dangerTemperature - 10)
        .clamp(0, 100)
        .toDouble();
    final dangerSmoke = settings.smokeThreshold;
    final warningSmoke = (dangerSmoke * 0.6).clamp(0, 100).toDouble();

    await _request(
      method: 'POST',
      path: '/api/thresholds',
      body: {
        'roomId': room.id,
        'temperatureWarning': warningTemperature,
        'temperatureDanger': dangerTemperature,
        'smokeWarning': warningSmoke,
        'smokeDanger': dangerSmoke,
      },
    );

    await _saveEmergencyPhone(settings.emergencyPhoneNumber);
    _settingsController.add(settings.copyWith(updatedAt: DateTime.now()));
  }

  @override
  Future<void> requestEmergencyCall({String source = 'app'}) async {
    final room = await _primaryRoom();
    final device = await _primaryDevice();

    await _request(
      method: 'POST',
      path: '/api/alerts/emergency-call',
      body: {
        'source': source,
        'roomId': room.id,
        'deviceId': device.id,
        'deviceCode': device.code,
      },
    );
  }

  @override
  Future<void> setAlarmMuted(bool muted) async {
    final device = await _primaryDevice();
    await _request(
      method: 'PUT',
      path: '/api/devices/${device.id}',
      body: {'alarmMuted': muted},
    );
    final updatedDevice = device.copyWith(alarmMuted: muted);
    _cachedDevice = updatedDevice;
    _applyDeviceUpdate(updatedDevice);
  }

  @override
  Future<void> resetLocalData() async {
    _cachedDevice = null;
    _cachedRoom = null;
    _cachedSensorData = null;
    _cachedAlertHistory = null;
    _cachedRoomOverviews = null;
    await Future.wait([
      _loadCurrentSensorData(force: true),
      _loadAlertHistory(force: true),
      _loadRoomOverviews(force: true),
    ]);
    if (!_isClosed) {
      _settingsController.add(await _fetchSettings());
    }
  }

  void close() {
    _isClosed = true;
    _socket?.dispose();
    _sensorController.close();
    _alertHistoryController.close();
    _roomsController.close();
    _settingsController.close();
    _client.close();
  }

  Stream<List<AlertHistory>> _createAlertHistoryStream({required int limit}) {
    return Stream<List<AlertHistory>>.multi((controller) {
      final cached = _cachedAlertHistory;
      if (cached != null) {
        controller.add(cached.take(limit).toList());
      }

      final subscription = _alertHistoryController.stream
          .map((alerts) => alerts.take(limit).toList())
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
      controller.onCancel = subscription.cancel;
    });
  }

  void _startRealtime() {
    if (_isClosed || _socket != null) {
      return;
    }

    _socketStart ??= _connectSocket();
    unawaited(_socketStart!);
  }

  Future<void> _connectSocket() async {
    try {
      final socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .disableAutoConnect()
            .setAuthFn((callback) {
              _tokenProvider()
                  .then((token) => callback({'token': token}))
                  .catchError((Object _) => callback(<String, dynamic>{}));
            })
            .build(),
      );

      if (_isClosed) {
        socket.dispose();
        return;
      }

      _socket = socket;
      socket.on('sensor:reading', _handleSensorReading);
      socket.on('alert:created', _handleAlertCreated);
      socket.on('device:updated', _handleDeviceUpdated);
      socket.on(
        'rooms:changed',
        (_) => unawaited(_loadRoomOverviews(force: true)),
      );
      socket.onConnectError((error) {
        _socketStart = null;
        _addRealtimeError(error);
      });
      socket.onError((error) => _addRealtimeError(error));
      socket.connect();
    } catch (error, stackTrace) {
      _socket = null;
      _socketStart = null;
      _addRealtimeError(error, stackTrace);
    }
  }

  void _addRealtimeError(Object error, [StackTrace? stackTrace]) {
    if (_isClosed) {
      return;
    }

    if (_cachedSensorData == null) {
      _sensorController.addError(error, stackTrace);
    }
    if (_cachedAlertHistory == null) {
      _alertHistoryController.addError(error, stackTrace);
    }
    if (_cachedRoomOverviews == null) {
      _roomsController.addError(error, stackTrace);
    }
  }

  Future<void> _loadCurrentSensorData({bool force = false}) {
    if (_isClosed || (!force && _cachedSensorData != null)) {
      return Future<void>.value();
    }

    final existingLoad = _sensorLoad;
    if (existingLoad != null) {
      return existingLoad;
    }

    _sensorLoad = () async {
      try {
        _setCurrentSensorData(await _fetchCurrentSensorData());
      } catch (error, stackTrace) {
        if (!_isClosed) {
          _sensorController.addError(error, stackTrace);
        }
      } finally {
        _sensorLoad = null;
      }
    }();

    return _sensorLoad!;
  }

  Future<void> _loadAlertHistory({int limit = 50, bool force = false}) {
    if (_isClosed) {
      return Future<void>.value();
    }

    if (!force && _cachedAlertHistory != null && _alertHistoryLimit >= limit) {
      return Future<void>.value();
    }

    final existingLoad = _alertHistoryLoad;
    if (existingLoad != null) {
      return existingLoad;
    }

    var targetLimit = _alertHistoryLimit;
    if (limit > targetLimit) {
      targetLimit = limit;
    }
    if (targetLimit == 0) {
      targetLimit = limit;
    }

    _alertHistoryLoad = () async {
      try {
        final alertHistory = await _fetchAlertHistory(limit: targetLimit);
        _alertHistoryLimit = targetLimit;
        _setAlertHistory(alertHistory);
      } catch (error, stackTrace) {
        if (!_isClosed) {
          _alertHistoryController.addError(error, stackTrace);
        }
      } finally {
        _alertHistoryLoad = null;
      }
    }();

    return _alertHistoryLoad!;
  }

  Future<void> _loadRoomOverviews({bool force = false}) {
    if (_isClosed || (!force && _cachedRoomOverviews != null)) {
      return Future<void>.value();
    }

    final existingLoad = _roomsLoad;
    if (existingLoad != null) {
      return existingLoad;
    }

    _roomsLoad = () async {
      try {
        _setRoomOverviews(await _fetchRoomOverviews());
      } catch (error, stackTrace) {
        if (!_isClosed) {
          _roomsController.addError(error, stackTrace);
        }
      } finally {
        _roomsLoad = null;
      }
    }();

    return _roomsLoad!;
  }

  void _setCurrentSensorData(SensorData sensorData) {
    if (_isClosed) {
      return;
    }

    _cachedSensorData = sensorData;
    _sensorController.add(sensorData);
  }

  void _setAlertHistory(List<AlertHistory> alertHistory) {
    if (_isClosed) {
      return;
    }

    _cachedAlertHistory = alertHistory;
    _alertHistoryController.add(alertHistory);
  }

  void _setRoomOverviews(List<RoomOverview> roomOverviews) {
    if (_isClosed) {
      return;
    }

    _cachedRoomOverviews = roomOverviews;
    _roomsController.add(roomOverviews);
  }

  void _handleSensorReading(Object? payload) {
    final payloadMap = _asMap(payload);
    final readingMap =
        _asMap(payloadMap?['reading']) ??
        _asMap(payloadMap?['data']) ??
        _asMap(payload);

    if (readingMap == null) {
      return;
    }

    final sensorData = SensorData.fromMap(
      readingMap,
      deviceId:
          payloadMap?['deviceCode']?.toString() ?? _deviceCode(readingMap),
    );

    _setCurrentSensorData(sensorData);
    _applySensorReadingToRooms(sensorData);
  }

  void _handleAlertCreated(Object? payload) {
    final alert = _alertHistoryFromRealtimePayload(payload);
    if (alert == null) {
      return;
    }

    final existing = _cachedAlertHistory ?? const <AlertHistory>[];
    final withoutDuplicate = alert.id.isEmpty
        ? existing
        : existing.where((item) => item.id != alert.id).toList();
    final maxItems = _alertHistoryLimit == 0 ? 50 : _alertHistoryLimit;
    _setAlertHistory([alert, ...withoutDuplicate].take(maxItems).toList());
  }

  AlertHistory? _alertHistoryFromRealtimePayload(Object? payload) {
    final payloadMap = _asMap(payload);
    if (payloadMap == null) {
      return null;
    }

    final alertMap = _asMap(payloadMap['alert']) ?? payloadMap;
    final readingMap = _asMap(payloadMap['reading']);
    final merged = <String, dynamic>{...alertMap};

    if (readingMap != null) {
      merged['temperature'] = readingMap['temperature'];
      merged['smokeLevel'] = readingMap['smokeLevel'];
      merged['humidity'] = readingMap['humidity'];
      merged['coLevel'] = readingMap['coLevel'] ?? readingMap['co2Level'];
      merged['riskLevel'] =
          readingMap['riskLevel'] ??
          readingMap['status'] ??
          alertMap['severity'] ??
          alertMap['type'];
      merged['timestamp'] = alertMap['createdAt'] ?? readingMap['createdAt'];
    }

    final deviceCode = payloadMap['deviceCode']?.toString();
    if (deviceCode != null && deviceCode.isNotEmpty) {
      merged['deviceId'] = deviceCode;
    }

    return AlertHistory.fromMap(merged);
  }

  void _handleDeviceUpdated(Object? payload) {
    final payloadMap = _asMap(payload);
    final deviceMap = _asMap(payloadMap?['device']) ?? _asMap(payload);

    if (deviceMap == null) {
      return;
    }

    final device = _BackendDevice.fromMap(deviceMap);
    _cachedDevice = device;
    _applyDeviceUpdate(device);
  }

  void _applyDeviceUpdate(_BackendDevice device) {
    final currentSensorData = _cachedSensorData;
    if (currentSensorData != null &&
        _matchesDeviceId(currentSensorData.deviceId, device)) {
      _setCurrentSensorData(
        currentSensorData.copyWith(
          batteryLevel: device.batteryLevel,
          isConnected: device.isOnline,
          alarmMuted: device.alarmMuted,
          lastUpdated: device.lastSeen ?? currentSensorData.lastUpdated,
        ),
      );
    }

    final roomOverviews = _cachedRoomOverviews;
    if (roomOverviews == null) {
      return;
    }

    var changed = false;
    final updatedRooms = roomOverviews.map((room) {
      var roomChanged = false;
      final devices = room.devices.map((roomDevice) {
        if (roomDevice.id != device.id &&
            roomDevice.deviceCode != device.code) {
          return roomDevice;
        }

        roomChanged = true;
        changed = true;
        return roomDevice.copyWith(
          isOnline: device.isOnline,
          batteryLevel: device.batteryLevel,
          alarmMuted: device.alarmMuted,
          lastSeen: device.lastSeen ?? roomDevice.lastSeen,
          latestReading: roomDevice.latestReading?.copyWith(
            batteryLevel: device.batteryLevel,
            isConnected: device.isOnline,
            alarmMuted: device.alarmMuted,
            lastUpdated:
                device.lastSeen ?? roomDevice.latestReading!.lastUpdated,
          ),
        );
      }).toList();

      return roomChanged ? room.copyWith(devices: devices) : room;
    }).toList();

    if (changed) {
      _setRoomOverviews(updatedRooms);
    }
  }

  void _applySensorReadingToRooms(SensorData sensorData) {
    final roomOverviews = _cachedRoomOverviews;
    if (roomOverviews == null) {
      return;
    }

    var changed = false;
    final updatedRooms = roomOverviews.map((room) {
      var roomChanged = false;
      final devices = room.devices.map((device) {
        if (device.id != sensorData.deviceId &&
            device.deviceCode != sensorData.deviceId) {
          return device;
        }

        roomChanged = true;
        changed = true;
        return device.copyWith(
          isOnline: sensorData.isConnected,
          batteryLevel: sensorData.batteryLevel,
          alarmMuted: sensorData.alarmMuted,
          lastSeen: sensorData.lastUpdated,
          latestReading: sensorData,
        );
      }).toList();

      return roomChanged ? room.copyWith(devices: devices) : room;
    }).toList();

    if (changed) {
      _setRoomOverviews(updatedRooms);
    }
  }

  bool _matchesDeviceId(String value, _BackendDevice device) {
    return value == device.id || value == device.code;
  }

  Future<SensorData> _fetchCurrentSensorData() async {
    final stats = await _request(method: 'GET', path: '/api/dashboard/stats');
    final statsMap = _asMap(stats);
    final latestReading = _asMap(statsMap?['latestReading']);

    if (latestReading != null) {
      return SensorData.fromMap(
        latestReading,
        deviceId: _deviceCode(latestReading),
      );
    }

    final device = await _primaryDevice();
    final latest = await _request(
      method: 'GET',
      path: '/api/sensors/latest/${device.id}',
    );
    final latestMap = _asMap(latest);
    if (latestMap != null) {
      return SensorData.fromMap(latestMap, deviceId: device.code);
    }

    return SensorData(
      deviceId: device.code,
      temperature: 0,
      smokeLevel: 0,
      humidity: 0,
      coLevel: 0,
      batteryLevel: device.batteryLevel,
      riskLevel: RiskLevel.low,
      isConnected: device.isOnline,
      alarmMuted: device.alarmMuted,
      lastUpdated: device.lastSeen ?? DateTime.now(),
    );
  }

  Future<List<AlertHistory>> _fetchAlertHistory({required int limit}) async {
    final alerts = await _request(method: 'GET', path: '/api/alerts');
    final alertItems = _asList(alerts);
    if (alertItems.isNotEmpty) {
      return alertItems
          .take(limit)
          .map(
            (item) => AlertHistory.fromMap(_asMap(item) ?? <String, dynamic>{}),
          )
          .toList();
    }

    final device = await _primaryDevice();
    final readings = await _request(
      method: 'GET',
      path: '/api/sensors/device/${device.id}',
    );

    return _asList(readings)
        .take(limit)
        .map(
          (item) => AlertHistory.fromMap(_asMap(item) ?? <String, dynamic>{}),
        )
        .toList();
  }

  Future<AppSettings> _fetchSettings() async {
    final room = await _primaryRoom();

    final threshold = _asMap(
      await _request(method: 'GET', path: '/api/thresholds/room/${room.id}'),
    );
    final emergencyPhone = await _primaryEmergencyPhone();

    return AppSettings(
      deviceId: deviceId,
      emergencyPhoneNumber: emergencyPhone,
      autoEmergencyCall: true,
      notificationsEnabled: true,
      temperatureThreshold: _doubleFromBackend(
        threshold?['temperatureDanger'],
        40,
      ),
      smokeThreshold: _normalizeSmokeThreshold(
        _doubleFromBackend(threshold?['smokeDanger'], 70),
      ),
      updatedAt: _dateTimeFromBackend(threshold?['updatedAt']),
    );
  }

  Future<List<RoomOverview>> _fetchRoomOverviews() async {
    final rooms = _asList(await _request(method: 'GET', path: '/api/rooms'))
        .map((item) {
          return RoomOverview.fromMap(_asMap(item) ?? <String, dynamic>{});
        })
        .where((room) => room.id.isNotEmpty)
        .toList();

    final devices = await Future.wait(
      _asList(
        await _request(method: 'GET', path: '/api/devices'),
      ).map(_roomDeviceWithLatestReading),
    );

    return rooms.map((room) {
      final roomDevices = devices
          .where((device) => device.roomId == room.id)
          .toList();
      return room.copyWith(devices: roomDevices);
    }).toList();
  }

  Future<RoomDevice> _roomDeviceWithLatestReading(Object? item) async {
    final device = RoomDevice.fromMap(_asMap(item) ?? <String, dynamic>{});

    if (device.id.isEmpty) {
      return device;
    }

    final latestReading = _asMap(
      await _request(method: 'GET', path: '/api/sensors/latest/${device.id}'),
    );

    if (latestReading == null) {
      return device;
    }

    return device.copyWith(
      latestReading: SensorData.fromMap(
        latestReading,
        deviceId: device.deviceCode,
      ),
    );
  }

  Future<_BackendRoom> _primaryRoom() async {
    final cached = _cachedRoom;
    if (cached != null) {
      return cached;
    }

    final rooms = _asList(await _request(method: 'GET', path: '/api/rooms'));
    if (rooms.isNotEmpty) {
      final room = _BackendRoom.fromMap(
        _asMap(rooms.first) ?? <String, dynamic>{},
      );
      _cachedRoom = room;
      return room;
    }

    final created = await _request(
      method: 'POST',
      path: '/api/rooms',
      body: {'name': 'Main Room', 'location': 'Default'},
    );
    final room = _BackendRoom.fromMap(_asMap(created) ?? <String, dynamic>{});
    _cachedRoom = room;
    return room;
  }

  Future<_BackendDevice> _primaryDevice() async {
    final cached = _cachedDevice;
    if (cached != null) {
      return cached;
    }

    final devices = _asList(
      await _request(method: 'GET', path: '/api/devices'),
    );
    if (devices.isNotEmpty) {
      final mappedDevices = devices
          .map(
            (item) =>
                _BackendDevice.fromMap(_asMap(item) ?? <String, dynamic>{}),
          )
          .toList();
      final matched = mappedDevices.where((device) => device.code == deviceId);
      final device = matched.isEmpty ? mappedDevices.first : matched.first;
      _cachedDevice = device;
      return device;
    }

    final room = await _primaryRoom();
    final created = await _request(
      method: 'POST',
      path: '/api/devices',
      body: {
        'roomId': room.id,
        'deviceId': deviceId,
        'deviceCode': deviceId,
        'name': 'Fire Detector Device',
        'batteryLevel': 100,
      },
    );
    final device = _BackendDevice.fromMap(
      _asMap(created) ?? <String, dynamic>{},
    );
    _cachedDevice = device;
    return device;
  }

  Future<String> _primaryEmergencyPhone() async {
    final contacts = _asList(
      await _request(method: 'GET', path: '/api/emergency-contacts'),
    );
    if (contacts.isEmpty) {
      return '+1-911-EMERGENCY';
    }

    final contactMaps = contacts
        .map((item) => _asMap(item) ?? <String, dynamic>{})
        .toList();
    final primary = contactMaps.where(
      (contact) => _boolFromBackend(contact['isPrimary'], false),
    );
    final contact = primary.isEmpty ? contactMaps.first : primary.first;
    return contact['phone']?.toString() ?? '+1-911-EMERGENCY';
  }

  Future<void> _saveEmergencyPhone(String phone) async {
    final contacts = _asList(
      await _request(method: 'GET', path: '/api/emergency-contacts'),
    );
    final contactMaps = contacts
        .map((item) => _asMap(item) ?? <String, dynamic>{})
        .toList();
    final primary = contactMaps.where(
      (contact) => _boolFromBackend(contact['isPrimary'], false),
    );
    final existing = primary.isEmpty
        ? (contactMaps.isEmpty ? null : contactMaps.first)
        : primary.first;

    final body = {
      'name': 'Primary Emergency Contact',
      'phone': phone,
      'relation': 'Emergency',
      'isPrimary': true,
    };

    if (existing == null) {
      await _request(
        method: 'POST',
        path: '/api/emergency-contacts',
        body: body,
      );
      return;
    }

    await _request(
      method: 'PUT',
      path: '/api/emergency-contacts/${existing['_id']}',
      body: body,
    );
  }

  Future<Object?> _request({
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    final token = await _tokenProvider();
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => await _client.put(uri, headers: headers, body: encodedBody),
      'PATCH' => await _client.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => throw RemoteBackendException('Unsupported HTTP method: $method'),
    };

    final decoded = _decodeBody(response.body);
    if (response.statusCode >= 400 || decoded['success'] == false) {
      final message = decoded['message']?.toString();
      throw RemoteBackendException(
        message == null || message.isEmpty
            ? 'Backend request failed with status ${response.statusCode}.'
            : message,
      );
    }

    return decoded.containsKey('data') ? decoded['data'] : decoded;
  }
}

class RemoteBackendException implements Exception {
  const RemoteBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _BackendRoom {
  const _BackendRoom({required this.id});

  final String id;

  factory _BackendRoom.fromMap(Map<String, dynamic> map) {
    return _BackendRoom(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
    );
  }
}

class _BackendDevice {
  const _BackendDevice({
    required this.id,
    required this.code,
    required this.batteryLevel,
    required this.isOnline,
    required this.alarmMuted,
    this.lastSeen,
  });

  final String id;
  final String code;
  final double batteryLevel;
  final bool isOnline;
  final bool alarmMuted;
  final DateTime? lastSeen;

  factory _BackendDevice.fromMap(Map<String, dynamic> map) {
    return _BackendDevice(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      code:
          map['deviceId']?.toString() ??
          map['deviceCode']?.toString() ??
          'SD-2024-001-A',
      batteryLevel: _doubleFromBackend(map['batteryLevel'], 0),
      isOnline: _boolFromBackend(map['isOnline'], false),
      alarmMuted: _boolFromBackend(map['alarmMuted'], false),
      lastSeen: _dateTimeFromBackendOrNull(map['lastSeen']),
    );
  }

  _BackendDevice copyWith({bool? alarmMuted}) {
    return _BackendDevice(
      id: id,
      code: code,
      batteryLevel: batteryLevel,
      isOnline: isOnline,
      alarmMuted: alarmMuted ?? this.alarmMuted,
      lastSeen: lastSeen,
    );
  }
}

String _normalizeBaseUrl(String baseUrl) {
  return baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
}

Map<String, dynamic> _decodeBody(String body) {
  if (body.isEmpty) {
    return <String, dynamic>{};
  }

  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{'data': decoded};
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return List<Object?>.from(value);
  }
  return const <Object?>[];
}

String? _deviceCode(Map<String, dynamic> reading) {
  final device = _asMap(reading['deviceId']);
  return device?['deviceId']?.toString() ?? device?['deviceCode']?.toString();
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

double _normalizeSmokeThreshold(double value) {
  if (value > 100) {
    return value / 10;
  }
  return value;
}

DateTime _dateTimeFromBackend(Object? value) {
  return _dateTimeFromBackendOrNull(value) ?? DateTime.now();
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
