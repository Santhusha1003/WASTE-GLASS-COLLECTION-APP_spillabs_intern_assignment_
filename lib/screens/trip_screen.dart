import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/summary_card.dart';
import '../widgets/status_badge.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  List<dynamic> suppliers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliersFromApi();
  }

  Future<void> _loadSuppliersFromApi() async {
    final route = await ApiService().getTodayRoute();
    final stops = route['stops'];

    debugPrint("========== TODAY ROUTE ==========");
    debugPrint(route.toString());
    debugPrint("=================================");

    if (!mounted) return;

    setState(() {
      suppliers = stops is List ? stops : [];
      isLoading = false;
    });
  }

  int get remainingStops {
    return suppliers.where((supplier) {
      final status = _readValue(supplier, 'status', 'Status').toLowerCase();
      return status != 'collected';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waste Glass Collection')),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    Text(
                      "Today's Route",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Plan the most efficient glass collection route for today.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const SummaryCard(
                    title: 'Total Distance',
                    value: '15.8 km',
                    icon: Icons.map_outlined,
                  ),
                  const SizedBox(width: 12),
                  SummaryCard(
                    title: 'Remaining Stops',
                    value: isLoading ? '-' : remainingStops.toString(),
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Stop Sequence',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : suppliers.isEmpty
                    ? const Center(
                        child: Text(
                          'No suppliers found',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) {
                          return _ApiSupplierCard(
                            supplier: suppliers[index],
                            sequenceNumber: index + 1,
                          );
                        },
                      ),
              ),
              CustomButton(
                label: 'Start Collection',
                icon: Icons.play_arrow,
                onPressed: _startCollection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _readValue(
    dynamic supplier,
    String camelCaseKey,
    String pascalCaseKey,
  ) {
    if (supplier is Map) {
      final value = supplier[camelCaseKey] ?? supplier[pascalCaseKey];
      return value?.toString() ?? '-';
    }
    return '-';
  }

  void _startCollection() {
    final pendingSupplier = suppliers.cast<dynamic>().where((supplier) {
      final status = _readValue(supplier, 'status', 'Status');
      return status.trim().toLowerCase() == 'pending';
    }).firstOrNull;

    if (pendingSupplier == null) {
      Navigator.pushNamed(context, '/report');
      return;
    }

    Navigator.pushNamed(context, '/scan', arguments: pendingSupplier);
  }
}

class _ApiSupplierCard extends StatelessWidget {
  const _ApiSupplierCard({
    required this.supplier,
    required this.sequenceNumber,
  });

  final dynamic supplier;
  final int sequenceNumber;

  @override
  Widget build(BuildContext context) {
    final supplierId = _readValue('supplierId', 'SupplierId');
    final name = _readValue('name', 'Name');
    final location = _readValue('location', 'Location');
    final expectedKg = _readValue('expectedKg', 'ExpectedKg');
    final status = _readValue('status', 'Status');

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
              sequenceNumber.toString(),
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
                  supplierId,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
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
                        location,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Expected: $expectedKg kg',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: status),
        ],
      ),
    );
  }

  String _readValue(String camelCaseKey, String pascalCaseKey) {
    if (supplier is Map) {
      final map = supplier as Map;
      final value = map[camelCaseKey] ?? map[pascalCaseKey];
      return value?.toString() ?? '-';
    }

    return '-';
  }
}
