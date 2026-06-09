import 'package:flutter/material.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';

class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
    this.status = 'Live',
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color accentColor;
  final String status;

  double _getProgress() {
    final numericValue = double.tryParse(value);
    if (numericValue == null) {
      if (title.toLowerCase() == 'flame') {
        return value.toUpperCase() == 'YES' ? 1.0 : 0.0;
      }
      return 0.0;
    }

    switch (title.toLowerCase()) {
      case 'temperature':
        return (numericValue / 80.0).clamp(0.0, 1.0);
      case 'smoke level':
        return (numericValue / 600.0).clamp(0.0, 1.0);
      case 'humidity':
        return (numericValue / 100.0).clamp(0.0, 1.0);
      case 'co2 level':
        return (numericValue / 2000.0).clamp(0.0, 1.0);
      case 'light level':
        return (numericValue / 2000.0).clamp(0.0, 1.0);
      case 'flame':
        // Flame level can be read from unit or parsed value.
        final fl = double.tryParse(unit.trim()) ?? numericValue;
        return (fl / 1024.0).clamp(0.0, 1.0);
      default:
        return (numericValue / 100.0).clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surface.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: progress > 0.75 
              ? accentColor.withValues(alpha: 0.5) 
              : AppColors.border,
          width: progress > 0.75 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (progress > 0.75)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: progress > 0.75 ? accentColor : AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unit.trim().isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                color: progress > 0.75 ? accentColor : AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: accentColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
