import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/status_badge.dart';
import '../widgets/summary_card.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  List<SupplierModel> suppliers = [];
  bool isLoading = true;
  bool _completionDialogShown = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliersFromApi();
  }

  Future<void> _loadSuppliersFromApi() async {
    try {
      final route = await ApiService().getTodayRoute();

      debugPrint('========== TODAY ROUTE ==========');
      debugPrint(route.toString());
      debugPrint('=================================');

      final stops = route['stops'] as List<dynamic>? ?? [];

      if (!mounted) return;

      setState(() {
        suppliers = stops.map((item) {
          return SupplierModel(
            supplierId: item['supplierId']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            location: item['location']?.toString() ?? '',
            expectedKg: (item['expectedKg'] as num?)?.toDouble() ?? 0,
            distanceKm: (item['distanceKm'] as num?)?.toDouble() ?? 0,
            barcodeValue: item['barcodeValue']?.toString() ?? '',
            status: item['status']?.toString() ?? '',
          );
        }).toList();
        isLoading = false;
      });

      _showCompletionDialogIfNeeded();
    } catch (error) {
      debugPrint('Load route error: $error');
      if (!mounted) return;

      setState(() {
        suppliers = [];
        isLoading = false;
      });
    }
  }

  int get remainingStops {
    return suppliers
        .where((supplier) => supplier.status.toLowerCase() != 'collected')
        .length;
  }

  double get totalDistance {
    return suppliers.fold<double>(
      0,
      (sum, supplier) => sum + supplier.distanceKm,
    );
  }

  void _startCollection() {
    if (remainingStops == 0) {
      Navigator.pushNamed(context, '/report');
      return;
    }

    SupplierModel? nextSupplier;

    for (final supplier in suppliers) {
      if (supplier.status.toLowerCase() != 'collected') {
        nextSupplier = supplier;
        break;
      }
    }

    if (nextSupplier == null) {
      Navigator.pushNamed(context, '/report');
      return;
    }

    Navigator.pushNamed(context, '/scan', arguments: nextSupplier.toMap());
  }

  void _showCompletionDialogIfNeeded() {
    if (_completionDialogShown || suppliers.isEmpty || remainingStops != 0) {
      return;
    }

    _completionDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text("Today's Route Completed"),
            content: const Text(
              'All scheduled collection stops for today have been completed.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushNamed(context, '/report');
                },
                child: const Text('View Trip Report'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    });
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
                  SummaryCard(
                    title: 'Total Distance',
                    value: isLoading
                        ? '-'
                        : '${totalDistance.toStringAsFixed(1)} km',
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
                            onTap: () => _showSupplierDetails(suppliers[index]),
                          );
                        },
                      ),
              ),
              CustomButton(
                label: remainingStops == 0
                    ? 'View Trip Report'
                    : 'Start Collection',
                icon: remainingStops == 0
                    ? Icons.assessment_outlined
                    : Icons.play_arrow,
                onPressed: _startCollection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupplierDetails(SupplierModel supplier) {
    final isCollected = supplier.status.toLowerCase() == 'collected';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            supplier.supplierId,
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusBadge(status: supplier.status),
                  ],
                ),
                const SizedBox(height: 18),
                _SupplierDetailRow(
                  label: 'Supplier ID',
                  value: supplier.supplierId,
                ),
                _SupplierDetailRow(
                  label: 'Supplier Name',
                  value: supplier.name,
                ),
                _SupplierDetailRow(label: 'Location', value: supplier.location),
                _SupplierDetailRow(
                  label: 'Expected KG',
                  value: '${_formatKg(supplier.expectedKg)} kg',
                ),
                _SupplierDetailRow(
                  label: 'Distance KM',
                  value: '${supplier.distanceKm.toStringAsFixed(1)} km',
                ),
                _SupplierDetailRow(
                  label: 'Barcode Value',
                  value: supplier.barcodeValue,
                ),
                _SupplierDetailRow(label: 'Status', value: supplier.status),
                const SizedBox(height: 16),
                CustomButton(
                  label: isCollected ? 'Already Collected' : 'Start Collection',
                  icon: isCollected ? Icons.check_circle : Icons.play_arrow,
                  onPressed: isCollected
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(
                            context,
                            '/scan',
                            arguments: supplier.toMap(),
                          );
                        },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatKg(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}

class SupplierModel {
  const SupplierModel({
    required this.supplierId,
    required this.name,
    required this.location,
    required this.expectedKg,
    required this.distanceKm,
    required this.barcodeValue,
    required this.status,
  });

  final String supplierId;
  final String name;
  final String location;
  final double expectedKg;
  final double distanceKm;
  final String barcodeValue;
  final String status;

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'name': name,
      'location': location,
      'expectedKg': expectedKg,
      'distanceKm': distanceKm,
      'distance': '${distanceKm.toStringAsFixed(1)} km',
      'barcodeValue': barcodeValue,
      'status': status,
    };
  }
}

class _ApiSupplierCard extends StatelessWidget {
  const _ApiSupplierCard({
    required this.supplier,
    required this.sequenceNumber,
    required this.onTap,
  });

  final SupplierModel supplier;
  final int sequenceNumber;
  final VoidCallback onTap;

  String _formatKg(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
                    supplier.supplierId,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expected: ${_formatKg(supplier.expectedKg)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (supplier.distanceKm > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Distance: ${supplier.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: supplier.status),
          ],
        ),
      ),
    );
  }
}

class _SupplierDetailRow extends StatelessWidget {
  const _SupplierDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
