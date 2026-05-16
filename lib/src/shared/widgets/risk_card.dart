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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: details.color.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: details.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: details.color.withValues(alpha: 0.24)),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: isFireDetected ? 1.12 : 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(details.icon, color: details.color, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Risk assessment',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  details.label,
                  style: TextStyle(
                    color: details.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
          label: 'HIGH',
          description: 'Elevated conditions need attention',
          color: Colors.deepOrange,
          icon: Icons.report_problem_outlined,
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
