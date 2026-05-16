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

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        icon: const Icon(Icons.phone_in_talk_outlined),
        label: Text(label.toUpperCase()),
      ),
    );
  }
}
