import 'package:flutter/material.dart';

import '../models/supplier.dart';
import '../utils/app_colors.dart';
import 'status_badge.dart';

class SupplierCard extends StatelessWidget {
  const SupplierCard({
    super.key,
    required this.supplier,
    this.sequenceNumber,
    this.trailing,
  });

  final Supplier supplier;
  final int? sequenceNumber;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              sequenceNumber?.toString() ?? supplier.id.toString(),
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        supplier.location,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      supplier.distance,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? StatusBadge(status: supplier.status),
        ],
      ),
    );
  }
}
