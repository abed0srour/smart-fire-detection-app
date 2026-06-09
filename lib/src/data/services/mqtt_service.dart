import 'dart:convert';

import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:mqtt5_client/mqtt5_server_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

class MqttService {
  late MqttServerClient client;
  final String broker;
  final int port;
  final String deviceCode;
  final Function(Map<String, dynamic>)? onSensorData;

  bool _isConnected = false;

  MqttService({
    required this.broker,
    required this.port,
    required this.deviceCode,
    this.onSensorData,
  }) {
    client = MqttServerClient(broker, 'flutter-app-$deviceCode');
    client.port = port;
    client.keepAlivePeriod = 60;
    client.logging(on: true);
  }

  Future<bool> connect() async {
    try {
      print('[MQTT] Connecting to $broker:$port');
      await client.connect();

      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        print('[MQTT] Connected successfully');

        // Subscribe to sensor topic
        _subscribe();
        return true;
      }
    } catch (e) {
      print('[MQTT ERROR] Connection failed: $e');
      _isConnected = false;
    }
    return false;
  }

  void _subscribe() {
    final sensorTopic = 'fire-detection/$deviceCode/sensors';
    print('[MQTT] Subscribing to $sensorTopic');

    client.subscribe(sensorTopic, MqttQos.atLeastOnce);

    // Listen for messages
    client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      for (final MqttReceivedMessage<MqttMessage> message in c) {
        final topic = message.topic;
        if (message.payload is! MqttPublishMessage) {
          continue;
        }

        final payloadMessage =
            (message.payload as MqttPublishMessage).payload.message;
        final payloadBytes = payloadMessage?.toList() ?? <int>[];
        final payloadString = utf8.decode(payloadBytes);
        print('[MQTT] Received on $topic: $payloadString');

        // Parse sensor data
        try {
          final data = jsonDecode(payloadString);
          onSensorData?.call(data);
        } catch (e) {
          print('[MQTT ERROR] Failed to parse payload: $e');
        }
      }
    });
  }

  Future<void> sendCommand(String action, {Map<String, dynamic>? extra}) async {
    if (!_isConnected) {
      print('[MQTT ERROR] Not connected');
      return;
    }

    final commandTopic = 'fire-detection/$deviceCode/commands';
    final payload = {'action': action, ...?extra};

    try {
      final utf8Bytes = utf8.encode(jsonEncode(payload));
      final data = typed.Uint8Buffer();
      data.addAll(utf8Bytes);
      client.publishMessage(commandTopic, MqttQos.atLeastOnce, data);
      print('[MQTT] Sent command: $action');
    } catch (e) {
      print('[MQTT ERROR] Failed to send command: $e');
    }
  }

  Future<void> updateThresholds({
    required int gasWarning,
    required int gasDanger,
    required int tempWarning,
    required int tempDanger,
  }) async {
    if (!_isConnected) {
      print('[MQTT ERROR] Not connected');
      return;
    }

    final configTopic = 'fire-detection/$deviceCode/config';
    final payload = {
      'gas_warning': gasWarning,
      'gas_danger': gasDanger,
      'temp_warning': tempWarning,
      'temp_danger': tempDanger,
    };

    try {
      final utf8Bytes = utf8.encode(jsonEncode(payload));
      final data = typed.Uint8Buffer();
      data.addAll(utf8Bytes);
      client.publishMessage(configTopic, MqttQos.atLeastOnce, data);
      print('[MQTT] Sent config update');
    } catch (e) {
      print('[MQTT ERROR] Failed to send config: $e');
    }
  }

  bool get isConnected => _isConnected;

  Future<void> disconnect() async {
    client.disconnect();
    _isConnected = false;
    print('[MQTT] Disconnected');
  }
}
