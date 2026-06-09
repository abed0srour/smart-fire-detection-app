import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';

/// Screen showing alert history from the active data source.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Color _getRiskColor(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return AppColors.success;
      case RiskLevel.medium:
        return AppColors.warning;
      case RiskLevel.high:
        return Colors.deepOrange;
      case RiskLevel.fire:
        return AppColors.danger;
    }
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
          'Alert History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<AlertHistory>>(
        stream: backend.watchAlertHistory(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildEmptyState(
              icon: Icons.cloud_off,
              title: 'History unavailable',
              subtitle: 'Check backend connection and API status.',
            );
          }

          final alertHistory = snapshot.data ?? const <AlertHistory>[];
          if (alertHistory.isEmpty) {
            return _buildEmptyState(
              icon: Icons.history,
              title: 'No alerts recorded',
              subtitle: 'All clear. Keep monitoring.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alertHistory.length,
            itemBuilder: (context, index) {
              final alert = alertHistory[index];
              return _buildAlertItem(context, alert);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, AlertHistory alert) {
    final riskColor = _getRiskColor(alert.riskLevel);
    
    // Choose status icon based on risk level
    IconData statusIcon;
    Color statusIconColor;
    switch (alert.riskLevel) {
      case RiskLevel.low:
        statusIcon = Icons.shield_outlined;
        statusIconColor = AppColors.success;
        break;
      case RiskLevel.medium:
        statusIcon = Icons.warning_amber_rounded;
        statusIconColor = AppColors.warning;
        break;
      case RiskLevel.high:
        statusIcon = Icons.error_outline_rounded;
        statusIconColor = Colors.deepOrange;
        break;
      case RiskLevel.fire:
        statusIcon = Icons.local_fire_department_rounded;
        statusIconColor = AppColors.danger;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            // Subtle left accent bar
            border: Border(left: BorderSide(color: riskColor, width: 6)),
            // Subtle gradient matching risk level
            gradient: LinearGradient(
              colors: [
                riskColor.withValues(alpha: 0.03),
                Colors.transparent,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAlertDetails(context, alert),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Icon, Status & Date, Risk Badge, Chevron
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status Icon Container
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusIconColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            color: statusIconColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Status Text and Timestamp
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.status,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatDate(alert.timestamp),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Risk Level Badge
                        Container(
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            alert.riskLevel.displayLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: riskColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: AppColors.border,
                        height: 1,
                        thickness: 0.5,
                      ),
                    ),
                    
                    // Sensor Readings Wrap
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSensorChip(
                          icon: Icons.thermostat,
                          color: AppColors.info,
                          value: '${alert.temperature.toStringAsFixed(1)}\u00B0C',
                        ),
                        _buildSensorChip(
                          icon: Icons.cloud,
                          color: AppColors.textSecondary,
                          value: '${alert.smokeLevel.toStringAsFixed(1)} ppm',
                        ),
                        _buildSensorChip(
                          icon: Icons.science,
                          color: const Color(0xFFA78BFA),
                          value: '${alert.coLevel.toStringAsFixed(1)} ppm',
                        ),
                        _buildSensorChip(
                          icon: Icons.light_mode,
                          color: AppColors.warning,
                          value: '${alert.lightLevel.toStringAsFixed(0)} lux',
                        ),
                        if (alert.flameDetected)
                          _buildSensorChip(
                            icon: Icons.local_fire_department,
                            color: AppColors.danger,
                            value: 'Flame',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorChip({
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showAlertDetails(BuildContext context, AlertHistory alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Alert Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Status', alert.status, AppColors.textPrimary),
            _buildDetailRow(
              'Date & Time',
              _formatDate(alert.timestamp),
              AppColors.textSecondary,
            ),
            _buildDetailRow(
              'Temperature',
              '${alert.temperature.toStringAsFixed(1)}\u00B0C',
              AppColors.info,
            ),
            _buildDetailRow(
              'Smoke Level',
              '${alert.smokeLevel.toStringAsFixed(1)} ppm',
              AppColors.textSecondary,
            ),
            _buildDetailRow(
              'CO2 Level',
              '${alert.coLevel.toStringAsFixed(1)} ppm',
              const Color(0xFFA78BFA),
            ),
            _buildDetailRow(
              'Light Level',
              '${alert.lightLevel.toStringAsFixed(0)} lux',
              AppColors.warning,
            ),
            _buildDetailRow(
              'Flame',
              alert.flameDetected
                  ? 'Detected (${alert.flameLevel.toStringAsFixed(0)})'
                  : 'Clear (${alert.flameLevel.toStringAsFixed(0)})',
              alert.flameDetected ? AppColors.danger : AppColors.success,
            ),
            _buildDetailRow(
              'Risk Level',
              alert.riskLevel.displayLabel,
              _getRiskColor(alert.riskLevel),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
