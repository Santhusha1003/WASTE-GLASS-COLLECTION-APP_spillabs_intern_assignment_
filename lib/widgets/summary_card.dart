import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
  });

  final String title;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryGreen, size: 21),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
