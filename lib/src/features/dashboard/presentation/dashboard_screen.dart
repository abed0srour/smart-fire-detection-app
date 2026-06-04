import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';
import 'package:smart_fire_detection_app/src/shared/widgets/emergency_button.dart';
import 'package:smart_fire_detection_app/src/shared/widgets/risk_card.dart';
import 'package:smart_fire_detection_app/src/shared/widgets/sensor_card.dart';

/// Main dashboard screen showing current sensor status.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
      case RiskLevel.fire:
        return {
          'text': 'CRITICAL',
          'color': AppColors.danger,
          'icon': Icons.warning_amber,
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<SensorData>(
        stream: backend.watchCurrentSensorData(),
        builder: (context, snapshot) {
          final sensorData =
              snapshot.data ?? LocalDataProvider.getCurrentSensorData();
          final statusDisplay = _getStatusDisplay(sensorData);

          return RefreshIndicator(
            onRefresh: () async {
              await backend.resetLocalData();
            },
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.hasError)
                      _buildBackendError(context, backend.isRemoteBackend),
                    _buildStatusBanner(context, statusDisplay),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      context,
                      'Sensor readings',
                      backend.isRemoteBackend
                          ? backend.backendName
                          : 'Local Data',
                    ),
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
                    _buildSectionTitle(context, 'Device status'),
                    const SizedBox(height: 16),
                    _buildDeviceStatus(context, sensorData),
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
      ),
    );
  }

  Widget _buildBackendError(BuildContext context, bool isRemoteBackend) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.4),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
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
                  'System status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDisplay['text'] as String,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
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

  Widget _buildDeviceStatus(BuildContext context, SensorData sensorData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildStatusItem(
                  icon: sensorData.isConnected ? Icons.wifi : Icons.wifi_off,
                  label: sensorData.isConnected ? 'Connected' : 'Offline',
                  color: sensorData.isConnected
                      ? AppColors.success
                      : AppColors.danger,
                  value: sensorData.isConnected ? 'Online' : 'No Signal',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.battery_full,
                  label: 'Battery',
                  color: AppColors.success,
                  value: '${sensorData.batteryLevel.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.update, color: AppColors.info, size: 20),
              const SizedBox(width: 12),
              Text(
                'Last Updated',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const Spacer(),
              Text(
                _getLastUpdateTime(sensorData),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLastUpdateTime(SensorData sensorData) {
    final diff = DateTime.now().difference(sensorData.lastUpdated);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required Color color,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context, BackendService backend) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Emergency Call',
          style: TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Initiating emergency call to the registered emergency number.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await backend.requestEmergencyCall(source: 'dashboard');
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency call initiated!'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('CALL NOW'),
          ),
        ],
      ),
    );
  }
}
