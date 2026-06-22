import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'next' => AppColors.primaryGreen,
      'collected' => AppColors.primaryGreen,
      _ => Colors.blueGrey,
    };
    final label = status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
