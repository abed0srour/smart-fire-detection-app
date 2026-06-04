import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';

/// Alert screen displayed when fire is detected.
class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Alerts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<SensorData>(
        stream: backend.watchCurrentSensorData(),
        builder: (context, snapshot) {
          final sensorData =
              snapshot.data ?? LocalDataProvider.getCurrentSensorData();
          final isCritical =
              sensorData.riskLevel == RiskLevel.fire ||
              sensorData.riskLevel == RiskLevel.high;
          final isMuted = _isMuted || sensorData.alarmMuted;

          return SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildPulseIcon(isCritical),
                    const SizedBox(height: 40),
                    Text(
                      isCritical ? 'FIRE' : 'MONITOR',
                      style: TextStyle(
                        fontSize: isCritical ? 56 : 42,
                        fontWeight: FontWeight.w900,
                        color: isCritical
                            ? AppColors.danger
                            : AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCritical ? 'DETECTED' : 'ACTIVE',
                      style: TextStyle(
                        fontSize: isCritical ? 56 : 42,
                        fontWeight: FontWeight.w900,
                        color: isCritical
                            ? Colors.deepOrange
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSensorReadings(sensorData, isCritical),
                    const SizedBox(height: 32),
                    _buildSafetyTips(),
                    const SizedBox(height: 40),
                    _buildActions(context, backend, isMuted),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPulseIcon(bool isCritical) {
    final color = isCritical ? AppColors.danger : AppColors.warning;
    final icon = isCritical ? Icons.local_fire_department : Icons.sensors;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (0.1 * _pulseController.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(
                      alpha: 0.5 - (0.3 * _pulseController.value),
                    ),
                    width: 3,
                  ),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(
                      alpha: 0.3 - (0.2 * _pulseController.value),
                    ),
                    width: 2,
                  ),
                ),
              ),
              Icon(icon, size: 80, color: color),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorReadings(SensorData sensorData, bool isCritical) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isCritical ? AppColors.danger : AppColors.warning).withValues(
            alpha: 0.5,
          ),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReadingRow(
            'Temperature',
            '${sensorData.temperature.toStringAsFixed(1)}\u00B0C',
            AppColors.danger,
          ),
          const SizedBox(height: 16),
          _buildReadingRow(
            'Smoke Level',
            '${sensorData.smokeLevel.toStringAsFixed(1)} ppm',
            Colors.deepOrange,
          ),
          const SizedBox(height: 16),
          _buildReadingRow(
            'CO2 Level',
            '${sensorData.coLevel.toStringAsFixed(1)} ppm',
            const Color(0xFFA78BFA),
          ),
          const SizedBox(height: 16),
          _buildReadingRow(
            'Light Level',
            '${sensorData.lightLevel.toStringAsFixed(0)} lux',
            AppColors.warning,
          ),
          const SizedBox(height: 16),
          _buildReadingRow(
            'Flame',
            sensorData.flameDetected
                ? 'Detected (${sensorData.flameLevel.toStringAsFixed(0)})'
                : 'Clear (${sensorData.flameLevel.toStringAsFixed(0)})',
            sensorData.flameDetected ? AppColors.danger : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildReadingRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTips() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'SAFETY TIPS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '- Evacuate the building immediately\n'
            '- Use stairs, not elevators\n'
            '- Help others if possible\n'
            '- Close doors behind you\n'
            '- Meet at assembly point',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    BackendService backend,
    bool isMuted,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showCallConfirmation(context, backend),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.phone, size: 24),
            label: const Text(
              'CALL EMERGENCY SERVICES',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final muted = !isMuted;
              setState(() {
                _isMuted = muted;
              });
              await backend.setAlarmMuted(muted);
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(muted ? 'Alarm muted' : 'Alarm activated'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isMuted
                  ? AppColors.textMuted
                  : Colors.deepOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 24),
            label: Text(
              isMuted ? 'ALARM MUTED' : 'MUTE ALARM',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  void _showCallConfirmation(BuildContext context, BackendService backend) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Call Emergency Services',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Emergency contact will be called immediately.\n\nConfirm this action.',
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
              await backend.requestEmergencyCall(source: 'alert_screen');
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency services called!'),
                  backgroundColor: AppColors.danger,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('CONFIRM CALL'),
          ),
        ],
      ),
    );
  }
}
