import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';

/// Alert screen displayed when fire or gas danger is detected.
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
          final isFireAlert = sensorData.riskLevel == RiskLevel.fire;
          final isGasLeakage = sensorData.riskLevel == RiskLevel.high;
          final isCritical = isFireAlert || isGasLeakage;
          final isMuted = _isMuted || sensorData.alarmMuted;
          final headlineTop = isFireAlert
              ? 'FIRE'
              : isGasLeakage
              ? 'DANGER'
              : 'MONITOR';
          final headlineBottom = isFireAlert
              ? 'DETECTED'
              : isGasLeakage
              ? 'HIGH GAS LEAKAGE'
              : 'ACTIVE';
          final headlineColor = isCritical
              ? AppColors.danger
              : AppColors.warning;

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
                    _buildPulseIcon(
                      isFireAlert: isFireAlert,
                      isGasLeakage: isGasLeakage,
                    ),
                    const SizedBox(height: 40),
                    _buildAlertHeadline(
                      headlineTop,
                      fontSize: isCritical ? 56 : 42,
                      color: headlineColor,
                    ),
                    const SizedBox(height: 8),
                    _buildAlertHeadline(
                      headlineBottom,
                      fontSize: isGasLeakage ? 34 : (isCritical ? 56 : 42),
                      color: isFireAlert
                          ? Colors.deepOrange
                          : isGasLeakage
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 32),
                    _buildSensorReadings(sensorData, isCritical),
                    const SizedBox(height: 32),
                    _buildSafetyTips(isGasLeakage: isGasLeakage),
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

  Widget _buildAlertHeadline(
    String text, {
    required double fontSize,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildPulseIcon({
    required bool isFireAlert,
    required bool isGasLeakage,
  }) {
    final isCritical = isFireAlert || isGasLeakage;
    final color = isCritical ? AppColors.danger : AppColors.warning;
    final icon = isFireAlert
        ? Icons.local_fire_department
        : isGasLeakage
        ? Icons.gas_meter
        : Icons.sensors;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double pulse = _pulseController.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outermost pulsing ring
            Container(
              width: 180 + (40 * pulse),
              height: 180 + (40 * pulse),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08 * (1.0 - pulse)),
                border: Border.all(
                  color: color.withValues(alpha: 0.25 * (1.0 - pulse)),
                  width: 1.5,
                ),
              ),
            ),
            // Middle pulsing ring
            Container(
              width: 130 + (30 * pulse),
              height: 130 + (30 * pulse),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12 * (1.0 - pulse)),
                border: Border.all(
                  color: color.withValues(alpha: 0.35 * (1.0 - pulse)),
                  width: 2,
                ),
              ),
            ),
            // Core breathing circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 20 + (10 * pulse),
                    spreadRadius: 2 + (2 * pulse),
                  ),
                ],
              ),
              child: Icon(icon, size: 52, color: color),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSensorReadings(SensorData sensorData, bool isCritical) {
    final borderThemeColor = isCritical ? AppColors.danger : AppColors.warning;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderThemeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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

  Widget _buildSafetyTips({required bool isGasLeakage}) {
    final color = isGasLeakage ? AppColors.danger : AppColors.warning;
    final title = isGasLeakage ? 'GAS LEAK SAFETY' : 'SAFETY TIPS';
    final tipsList = isGasLeakage
        ? [
            'Avoid flames and electrical switches',
            'Ventilate the area if safe to do so',
            'Shut off the gas source if accessible',
            'Leave the area immediately',
            'Contact emergency services'
          ]
        : [
            'Evacuate the building immediately',
            'Use stairs, do not use elevators',
            'Help others to safety if possible',
            'Close doors behind you to contain fire',
            'Meet at designated assembly point'
          ];

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...tipsList.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: color.withValues(alpha: 0.7), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
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
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _showCallConfirmation(context, backend),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.phone, size: 20),
            label: const Text(
              'CALL EMERGENCY SERVICES',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (isMuted ? AppColors.textMuted : Colors.deepOrange).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
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
              backgroundColor: isMuted ? AppColors.surfaceHigh : Colors.deepOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 20),
            label: Text(
              isMuted ? 'UNMUTE ALARM' : 'MUTE ALARM',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
