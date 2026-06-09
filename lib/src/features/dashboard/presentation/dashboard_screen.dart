import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';
import 'package:smart_fire_detection_app/src/data/services/mqtt_service.dart';
import 'package:smart_fire_detection_app/src/shared/widgets/emergency_button.dart';
import 'package:smart_fire_detection_app/src/shared/widgets/risk_card.dart';
import 'package:smart_fire_detection_app/src/shared/widgets/sensor_card.dart';

/// Main dashboard screen showing current sensor status.
/// Supports both Backend API and MQTT real-time sensor data.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  MqttService? _mqttService;
  Map<String, dynamic>? _latestSensorData;
  bool _useMqtt = false;

  bool get _hasMqttData => _useMqtt && _latestSensorData != null;

  @override
  void initState() {
    super.initState();
    _setupMqtt();
  }

  /// Initialize MQTT client and connect to broker
  Future<void> _setupMqtt() async {
    _mqttService = MqttService(
      broker: '172.20.10.3', // Local Mosquitto broker on your laptop
      port: 1883,
      deviceCode: 'MASTER_ROOM',
      onSensorData: (data) {
        if (!mounted) {
          return;
        }
        setState(() {
          _useMqtt = true;
          _latestSensorData = data;
        });
      },
    );

    final connected = await _mqttService?.connect() ?? false;
    if (!mounted) {
      return;
    }
    if (!connected) {
      // Fall back to backend if MQTT fails
      setState(() {
        _useMqtt = false;
      });
    }
  }

  Map<String, dynamic> _getStatusDisplay(SensorData sensorData) {
    switch (sensorData.riskLevel) {
      case RiskLevel.low:
        return {
          'text': 'SAFE',
          'color': AppColors.success,
          'icon': Icons.check_circle,
        };
      case RiskLevel.medium:
        return {
          'text': 'WARNING',
          'color': AppColors.warning,
          'icon': Icons.warning,
        };
      case RiskLevel.high:
        return {
          'text': 'HIGH GAS LEAKAGE',
          'color': AppColors.danger,
          'icon': Icons.gas_meter,
        };
      case RiskLevel.fire:
        return {
          'text': 'FIRE DETECTED',
          'color': AppColors.danger,
          'icon': Icons.local_fire_department,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text('Operations Dashboard'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: _buildLiveIndicator(),
            ),
          ),
        ],
      ),
      body: _buildUnifiedDashboard(backend),
    );
  }

  /// Dashboard powered by both MQTT real-time data and Backend API
  Widget _buildUnifiedDashboard(BackendService backend) {
    return StreamBuilder<SensorData>(
      stream: backend.watchCurrentSensorData(),
      builder: (context, snapshot) {
        // If MQTT data is available, parse it into SensorData
        SensorData sensorData;
        if (_hasMqttData) {
          sensorData = SensorData.fromMap(_latestSensorData!);
        } else {
          sensorData = snapshot.data ?? LocalDataProvider.getCurrentSensorData();
        }

        final statusDisplay = _getStatusDisplay(sensorData);

        return RefreshIndicator(
          onRefresh: () async {
            if (_useMqtt) {
              await _setupMqtt();
            } else {
              await backend.resetLocalData();
            }
          },
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot.hasError && !_hasMqttData)
                    _buildBackendError(context, backend.isRemoteBackend),
                  _buildStatusBanner(context, statusDisplay),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Sensor readings'),
                  const SizedBox(height: 16),
                  _buildSensorGrid(sensorData),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Risk assessment'),
                  const SizedBox(height: 16),
                  RiskCard(
                    riskLevel: sensorData.riskLevel,
                    isFireDetected: sensorData.riskLevel == RiskLevel.fire,
                  ),
                  const SizedBox(height: 24),
                  EmergencyButton(
                    onPressed: () => _showEmergencyDialog(context, backend),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveIndicator() {
    final isLive = _useMqtt ? (_mqttService?.isConnected ?? false) : true;
    final color = isLive ? AppColors.success : AppColors.danger;
    final text = isLive ? 'Live' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  // Existing Backend dashboard helper methods
  Widget _buildBackendError(BuildContext context, bool isRemoteBackend) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        isRemoteBackend
            ? 'Backend data is temporarily unavailable.'
            : 'Local data is temporarily unavailable.',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildStatusBanner(
    BuildContext context,
    Map<String, dynamic> statusDisplay,
  ) {
    final color = statusDisplay['color'] as Color;
    final isDanger = statusDisplay['text'] == 'FIRE DETECTED' || statusDisplay['text'] == 'HIGH GAS LEAKAGE';
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDanger ? 0.6 : 0.3), 
          width: isDanger ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (isDanger)
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(
              statusDisplay['icon'] as IconData,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM STATUS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusDisplay['text'] as String,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusMeta(color),
        ],
      ),
    );
  }

  Future<void> _showEmergencyDialog(
    BuildContext context,
    BackendService backend,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Call Emergency Services'),
        content: const Text(
          'Emergency contact will be called immediately. Confirm this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await backend.requestEmergencyCall(source: 'dashboard_screen');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency services contacted.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emergency request failed: $error')),
      );
    }
  }

  Widget _buildStatusMeta(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'LIVE',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, [
    String? trailing,
  ]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              trailing,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSensorGrid(SensorData sensorData) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.95,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SensorCard(
          title: 'Temperature',
          value: sensorData.temperature.toStringAsFixed(1),
          unit: '\u00B0C',
          icon: Icons.thermostat,
          accentColor: AppColors.info,
        ),
        SensorCard(
          title: 'Smoke Level',
          value: sensorData.smokeLevel.toStringAsFixed(1),
          unit: 'ppm',
          icon: Icons.cloud,
          accentColor: AppColors.textSecondary,
        ),
        SensorCard(
          title: 'Humidity',
          value: sensorData.humidity.toStringAsFixed(1),
          unit: '%',
          icon: Icons.opacity,
          accentColor: Colors.cyanAccent,
        ),
        SensorCard(
          title: 'CO2 Level',
          value: sensorData.coLevel.toStringAsFixed(1),
          unit: 'ppm',
          icon: Icons.science,
          accentColor: const Color(0xFFA78BFA),
        ),
        SensorCard(
          title: 'Light Level',
          value: sensorData.lightLevel.toStringAsFixed(0),
          unit: 'lux',
          icon: Icons.light_mode,
          accentColor: AppColors.warning,
        ),
        SensorCard(
          title: 'Flame',
          value: sensorData.flameDetected ? 'YES' : 'NO',
          unit: sensorData.flameLevel.toStringAsFixed(0),
          icon: Icons.local_fire_department,
          accentColor: sensorData.flameDetected
              ? AppColors.danger
              : AppColors.success,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mqttService?.disconnect();
    super.dispose();
  }
}
