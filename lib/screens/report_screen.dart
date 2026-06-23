import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/collection.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/summary_card.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const double _expectedKg = 30;

  late Future<List<CollectionModel>> _collectionsFuture;

  Map<String, dynamic>? backendReport;
  bool isReportLoading = false;

  @override
  void initState() {
    super.initState();
    _collectionsFuture = LocalDatabase.instance.getCollections();
    _loadBackendReport();
  }

  Future<void> _loadBackendReport() async {
    setState(() {
      isReportLoading = true;
    });

    final report = await ApiService().getReport();

    print("========== REPORT API ==========");
    print(report);
    print("================================");

    if (!mounted) return;

    setState(() {
      backendReport = report;
      isReportLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Report')),
      body: SafeArea(
        child: FutureBuilder<List<CollectionModel>>(
          future: _collectionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Failed to load offline collections.',
                  style: TextStyle(
                    color: AppColors.warningRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }

            final collections = snapshot.data ?? [];
            final totalCollected = collections.fold<double>(
              0,
              (sum, collection) => sum + collection.totalKg,
            );
            final backendTotalCollected = backendReport?['totalCollected'];
            final backendTotalExpected = backendReport?['totalExpected'];
            final supplierSummaries =
                backendReport?['supplierSummaries'] as List<dynamic>?;

            final displayTotalCollected = backendTotalCollected != null
                ? (backendTotalCollected as num).toDouble()
                : totalCollected;

            final displayExpectedKg = backendTotalExpected != null
                ? (backendTotalExpected as num).toDouble()
                : _expectedKg;

            final hasShortfall = displayTotalCollected < displayExpectedKg;
            final shortfallKg = displayExpectedKg - displayTotalCollected;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TripCompletedBanner(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      SummaryCard(
                        title: 'Total Collected',
                        value: '${_formatKg(displayTotalCollected)} kg',
                        icon: Icons.recycling,
                      ),
                      const SizedBox(width: 12),
                      const SummaryCard(
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
                  if (hasShortfall) ...[
                    const SizedBox(height: 16),
                    _ShortfallWarning(shortfallKg: shortfallKg),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Supplier Summary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (supplierSummaries == null || supplierSummaries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'No supplier summaries found.',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: supplierSummaries.length,
                      itemBuilder: (context, index) {
                        return _BackendSupplierSummaryCard(
                          summary: supplierSummaries[index],
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Sync To Server',
                    icon: Icons.cloud_upload_outlined,
                    onPressed: () async {
                      final syncedCount = await SyncService()
                          .syncOfflineCollections();

                      if (!context.mounted) return;

                      setState(() {
                        _collectionsFuture = LocalDatabase.instance
                            .getCollections();
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$syncedCount records synced successfully',
                          ),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    label: 'Back To Home',
                    icon: Icons.home_outlined,
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/trip',
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatKg(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}

class _TripCompletedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 36),
          SizedBox(height: 10),
          Text(
            'Trip Completed',
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
    );
  }
}

class _ShortfallWarning extends StatelessWidget {
  const _ShortfallWarning({required this.shortfallKg});

  final double shortfallKg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warningRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warningRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Shortfall warning: ${_formatKg(shortfallKg)} kg below expected collection target.',
              style: const TextStyle(
                color: AppColors.warningRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKg(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}

class _BackendSupplierSummaryCard extends StatelessWidget {
  const _BackendSupplierSummaryCard({required this.summary});

  final dynamic summary;

  @override
  Widget build(BuildContext context) {
    final supplierId = _readValue('supplierId');
    final name = _readValue('name');
    final expectedKg = _readNumber('expectedKg');
    final collectedKg = _readNumber('collectedKg');
    final status = _readValue('status');
    final hasShortfall = collectedKg < expectedKg;

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
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                hasShortfall ? Icons.warning_amber_rounded : Icons.check_circle,
                color: hasShortfall
                    ? AppColors.warningRed
                    : AppColors.primaryGreen,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Supplier ID: $supplierId'),
          const SizedBox(height: 4),
          Text('Expected: ${_formatKg(expectedKg)} kg'),
          const SizedBox(height: 4),
          Text('Collected: ${_formatKg(collectedKg)} kg'),
          const SizedBox(height: 8),
          Text(
            'Status: $status',
            style: TextStyle(
              color: hasShortfall
                  ? AppColors.warningRed
                  : AppColors.primaryGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _readValue(String key) {
    if (summary is Map) {
      final map = summary as Map;
      final value = map[key];
      return value?.toString() ?? '-';
    }

    return '-';
  }

  double _readNumber(String key) {
    if (summary is Map) {
      final map = summary as Map;
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
    }

    return 0;
  }

  String _formatKg(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}
