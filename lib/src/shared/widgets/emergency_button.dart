import 'package:flutter/material.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({
    super.key,
    required this.onPressed,
    this.label = 'Emergency call',
    this.isAlertMode = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool isAlertMode;

  @override
  Widget build(BuildContext context) {
    final color = isAlertMode ? AppColors.danger : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        icon: const Icon(Icons.phone_in_talk_outlined, size: 20),
        label: Text(label.toUpperCase()),
      ),
    );
  }
}
