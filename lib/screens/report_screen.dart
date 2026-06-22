import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/summary_card.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  static const _summaries = [
    _SupplierSummary('ABC Glass Supplier', 30, 30, true),
    _SupplierSummary('XYZ Glass Center', 25, 18, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Report')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.24),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 36),
                    SizedBox(height: 10),
                    Text(
                      'Trip Completed!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All scheduled stops have been processed.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  SummaryCard(
                    title: 'Total Collected',
                    value: '120.5 kg',
                    icon: Icons.recycling,
                  ),
                  SizedBox(width: 12),
                  SummaryCard(
                    title: 'Total Distance',
                    value: '15.8 km',
                    icon: Icons.route,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  SummaryCard(
                    title: 'Trip Duration',
                    value: '2h 35m',
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  SummaryCard(
                    title: 'Total Expected',
                    value: '55 kg',
                    icon: Icons.inventory_2_outlined,
                  ),
                  SizedBox(width: 12),
                  SummaryCard(
                    title: 'Total Collected',
                    value: '48 kg',
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Supplier Summary',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _summaries.length,
                  itemBuilder: (context, index) {
                    final summary = _summaries[index];
                    final hasShortfall =
                        summary.collectedKg < summary.expectedKg;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: hasShortfall
                              ? AppColors.warningRed.withValues(alpha: 0.35)
                              : AppColors.borderColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.045),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  summary.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Icon(
                                summary.completed
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color: summary.completed
                                    ? AppColors.primaryGreen
                                    : Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Expected: ${summary.expectedKg}kg'),
                          const SizedBox(height: 4),
                          Text('Collected: ${summary.collectedKg}kg'),
                          const SizedBox(height: 4),
                          const Text(
                            'Completed',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (hasShortfall) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Shortfall: ${summary.expectedKg - summary.collectedKg}kg',
                              style: TextStyle(
                                color: AppColors.warningRed,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              CustomButton(
                label: 'Sync to Server',
                icon: Icons.cloud_upload_outlined,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierSummary {
  const _SupplierSummary(
    this.name,
    this.expectedKg,
    this.collectedKg,
    this.completed,
  );

  final String name;
  final int expectedKg;
  final int collectedKg;
  final bool completed;
}
