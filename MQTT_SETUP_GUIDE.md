# MQTT Fire Detection System - Complete Setup Guide

## Overview

This system uses **MQTT** (Mosquitto) for bidirectional communication between Raspberry Pi and the Flutter app/backend:

- **Raspberry Pi → Broker**: Publishes sensor readings to `fire-detection/MASTER_ROOM/sensors`
- **App/Backend → Broker**: Can publish commands to `fire-detection/MASTER_ROOM/commands`
- **App** subscribes to sensor topic to get real-time updates

---

## Step 1: Install & Run MQTT Broker

### Option A: On Your Laptop (Windows)

**Download & Install Mosquitto:**
1. Download from: https://mosquitto.org/download/
2. Install and run (or use Windows 10 WSL)

**Or use Docker (easiest):**
```powershell
# If you have Docker installed
docker run -d --name mosquitto -p 1883:1883 eclipse-mosquitto
```

**Or use pre-built Windows executable:**
Download from: https://github.com/eclipse/mosquitto/releases

Start the broker:
```powershell
# Default install path
"C:\Program Files\mosquitto\mosquitto.exe"
```

### Option B: On Raspberry Pi

```bash
sudo apt-get update
sudo apt-get install -y mosquitto mosquitto-clients

# Start the broker
sudo systemctl start mosquitto
sudo systemctl enable mosquitto  # Auto-start on boot

# Check status
sudo systemctl status mosquitto
```

### Option C: On Linux/Mac

```bash
# macOS
brew install mosquitto
brew services start mosquitto

# Linux
sudo apt-get install mosquitto mosquitto-clients
sudo systemctl start mosquitto
```

---

## Step 2: Configure Mosquitto (Optional - Allow Anonymous Access)

**Default allows connections from localhost only. To allow remote connections:**

Edit mosquitto config file:
- **Windows**: `C:\Program Files\mosquitto\mosquitto.conf`
- **Linux/Mac**: `/etc/mosquitto/mosquitto.conf`

Add or uncomment:
```conf
listener 1883
protocol mqtt
allow_anonymous true
```

Save and restart Mosquitto.

---

## Step 3: Install Python Dependencies on Raspberry Pi

```bash
# Install paho-mqtt
sudo pip3 install paho-mqtt

# Verify installation
python3 -c "import paho.mqtt.client as mqtt; print('MQTT OK')"
```

---

## Step 4: Run Raspberry Pi Script

### Find Your Laptop IP Address

**Windows (PowerShell):**
```powershell
ipconfig
# Look for IPv4 Address under your network adapter, e.g., 192.168.0.100 or 172.20.10.3
```

**Linux/Mac:**
```bash
ifconfig
# Or
hostname -I
```

### Run the Script

```bash
# On Raspberry Pi
export MQTT_BROKER=<YOUR_LAPTOP_IP>      # e.g., 192.168.0.100
export MQTT_PORT=1883
export DEVICE_CODE=MASTER_ROOM

python3 main_mqtt.py
```

**Example:**
```bash
export MQTT_BROKER=172.20.10.3
export DEVICE_CODE=MASTER_ROOM
python3 main_mqtt.py
```

You should see:
```
==================================================
 MQTT FIRE DETECTION SYSTEM STARTED
==================================================
Broker: 172.20.10.3:1883
Device Code: MASTER_ROOM
Sensor topic: fire-detection/MASTER_ROOM/sensors
Command topic: fire-detection/MASTER_ROOM/commands
Config topic: fire-detection/MASTER_ROOM/config
==================================================

[MQTT] Connecting to broker...
[MQTT] Connected to broker 172.20.10.3:1883
[MQTT] Subscribed to fire-detection/MASTER_ROOM/commands and fire-detection/MASTER_ROOM/config

==================================================
Temperature: 28.5°C
Humidity: 65.2%
Smoke (MQ135): 245
Flame Level: 650
Flame Detected: False
Light Level: 456
Status: SAFE
  → All sensors normal
==================================================
[MQTT] Published sensor data to fire-detection/MASTER_ROOM/sensors
```

---

## Step 5: Flutter App MQTT Integration

### Install MQTT Package

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  mqtt5_client: ^4.8.1
  # or
  # mqtt_client: ^9.7.0
```

Run:
```bash
flutter pub get
```

### Create MQTT Service

Create `lib/src/data/services/mqtt_service.dart`:

```dart
import 'package:mqtt5_client/mqtt_client.dart';
import 'package:mqtt5_client/mqtt_server_client.dart';
import 'dart:convert';

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
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      for (final MqttReceivedMessage<MqttMessage> message in c) {
        final topic = message.topic;
        final payload = MqttPublishMessage.fromByteBuffer(
          0,
          message.payload as MqttPublishPayload,
        ).payload.message;
        
        String payloadString = utf8.decode(payload);
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
    final payload = {
      'action': action,
      ...?extra,
    };
    
    try {
      client.publishMessage(
        commandTopic,
        MqttQos.atLeastOnce,
        utf8.encode(jsonEncode(payload)) as Uint8List,
      );
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
      client.publishMessage(
        configTopic,
        MqttQos.atLeastOnce,
        utf8.encode(jsonEncode(payload)) as Uint8List,
      );
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
```

### Use MQTT Service in Dashboard

Modify `lib/src/features/dashboard/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/data/services/mqtt_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late MqttService _mqttService;
  Map<String, dynamic>? _latestSensorData;

  @override
  void initState() {
    super.initState();
    _setupMqtt();
  }

  void _setupMqtt() async {
    _mqttService = MqttService(
      broker: '172.20.10.3',  // Your laptop IP
      port: 1883,
      deviceCode: 'MASTER_ROOM',
      onSensorData: (data) {
        setState(() {
          _latestSensorData = data;
        });
      },
    );
    
    await _mqttService.connect();
  }

  @override
  Widget build(BuildContext context) {
    if (_latestSensorData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fire Detection Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                _mqttService.isConnected ? '🟢 Connected' : '🔴 Disconnected',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: _getStatusColor(_latestSensorData!['status']),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${_latestSensorData!['status'].toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_latestSensorData!['reasons'] != null)
                      ..._latestSensorData!['reasons']
                          .map<Widget>((reason) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '→ $reason',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ))
                          .toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sensor Data Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _sensorTile('Temperature', '${_latestSensorData!['temperature']}°C'),
                _sensorTile('Humidity', '${_latestSensorData!['humidity']}%'),
                _sensorTile('Smoke (MQ135)', '${_latestSensorData!['smokeLevel']}'),
                _sensorTile('Flame Level', '${_latestSensorData!['flameLevel']}'),
                _sensorTile('Light Level', '${_latestSensorData!['lightLevel']}'),
                _sensorTile('Battery', '${_latestSensorData!['batteryLevel']}%'),
              ],
            ),
            const SizedBox(height: 16),

            // Flame Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _latestSensorData!['flameDetected']
                        ? const Icon(Icons.fire_truck, color: Colors.red, size: 32)
                        : const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    const SizedBox(width: 16),
                    Text(
                      _latestSensorData!['flameDetected'] ? 'FIRE DETECTED!' : 'No flame',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _latestSensorData!['flameDetected']
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _mqttService.sendCommand('buzzer_on'),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Buzzer ON'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _mqttService.sendCommand('buzzer_off'),
                  icon: const Icon(Icons.volume_off),
                  label: const Text('Buzzer OFF'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _mqttService.sendCommand('all_off'),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('All OFF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensorTile(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'fire':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }
}
```

---

## Step 6: Test the System

### Terminal 1: Start MQTT Broker
```powershell
# Windows
mosquitto -c "C:\Program Files\mosquitto\mosquitto.conf"

# Or Docker
docker run -d -p 1883:1883 eclipse-mosquitto
```

### Terminal 2: Run Raspberry Pi Script
```bash
export MQTT_BROKER=172.20.10.3
export DEVICE_CODE=MASTER_ROOM
python3 main_mqtt.py
```

### Terminal 3: Monitor MQTT Messages
```bash
# Test with mosquitto_sub (if installed)
mosquitto_sub -h 172.20.10.3 -t "fire-detection/MASTER_ROOM/sensors"
```

### Terminal 4: Run Flutter App
```powershell
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://172.20.10.3:5000
```

---

## MQTT Topics Reference

| Topic | Direction | Purpose |
|-------|-----------|---------|
| `fire-detection/MASTER_ROOM/sensors` | Pi → App | Sensor readings (published every 2 seconds) |
| `fire-detection/MASTER_ROOM/commands` | App → Pi | Control commands (buzzer_on, buzzer_off, all_off) |
| `fire-detection/MASTER_ROOM/config` | App → Pi | Threshold updates (gas_warning, temp_danger, etc.) |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Connection refused` | Check broker IP and port, ensure firewall allows 1883 |
| `MQTT ERROR Not connected` | Broker not running or unreachable |
| `No data appearing in app` | Check Raspberry Pi script is publishing, verify topic subscription |
| `Raspberry Pi can't reach broker` | Use correct IP (not localhost), ensure same network |
| `Buzzer commands not working` | Verify GrovePi is connected, test with local script first |

---

## Commands You Can Send

Publish to `fire-detection/MASTER_ROOM/commands`:

```json
{"action": "buzzer_on"}
{"action": "buzzer_off"}
{"action": "all_off"}
{"action": "set_lights", "status": "warning"}
```

Send from app or terminal:
```bash
mosquitto_pub -h 172.20.10.3 -t "fire-detection/MASTER_ROOM/commands" -m '{"action":"buzzer_on"}'
```

