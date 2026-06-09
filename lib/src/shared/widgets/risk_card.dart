import 'package:flutter/material.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';

class RiskCard extends StatelessWidget {
  const RiskCard({
    super.key,
    required this.riskLevel,
    required this.isFireDetected,
  });

  final RiskLevel riskLevel;
  final bool isFireDetected;

  @override
  Widget build(BuildContext context) {
    final details = _RiskDetails.fromLevel(riskLevel);

    final isDanger = riskLevel == RiskLevel.high || riskLevel == RiskLevel.fire;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            details.color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: details.color.withValues(alpha: isDanger ? 0.6 : 0.3),
          width: isDanger ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (isDanger)
            BoxShadow(
              color: details.color.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: details.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: details.color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: isFireDetected ? 1.15 : 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(details.icon, color: details.color, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk assessment'.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.label,
                  style: TextStyle(
                    color: details.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskDetails {
  const _RiskDetails({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String label;
  final String description;
  final Color color;
  final IconData icon;

  factory _RiskDetails.fromLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return const _RiskDetails(
          label: 'LOW',
          description: 'Readings are inside normal operating range',
          color: AppColors.success,
          icon: Icons.check_circle_outline,
        );
      case RiskLevel.medium:
        return const _RiskDetails(
          label: 'MEDIUM',
          description: 'Sensor values are trending above normal',
          color: AppColors.warning,
          icon: Icons.warning_amber_outlined,
        );
      case RiskLevel.high:
        return const _RiskDetails(
          label: 'HIGH GAS',
          description: 'Danger: high gas leakage',
          color: AppColors.danger,
          icon: Icons.gas_meter,
        );
      case RiskLevel.fire:
        return const _RiskDetails(
          label: 'FIRE',
          description: 'Fire condition detected',
          color: AppColors.danger,
          icon: Icons.local_fire_department,
        );
    }
  }
}
