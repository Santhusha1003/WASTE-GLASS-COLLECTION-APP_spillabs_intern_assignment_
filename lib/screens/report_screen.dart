import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/collection.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../utils/app_colors.dart';

// ── Palette (mirrors trip_screen / scan_screen) ────────────────────────────
const _kGreen = Color(0xFF0A8F35);
const _kGreenDark = Color(0xFF076828);
const _kGreenLight = Color(0xFFEAF7EE);
const _kBlue = Color(0xFF1565C0);
const _kBlueLight = Color(0xFFE3F2FD);
const _kOrange = Color(0xFFE65100);
const _kOrangeLight = Color(0xFFFFF3E0);

// ── Helpers ────────────────────────────────────────────────────────────────
String _formatKg(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

String _formatDuration(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

// ═══════════════════════════════════════════════════════════════════════════
// ReportScreen
// ═══════════════════════════════════════════════════════════════════════════
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
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
    setState(() => isReportLoading = true);
    final report = await ApiService().getReport();

    debugPrint('========== REPORT API ==========');
    debugPrint(report.toString());
    debugPrint('================================');

    if (!mounted) return;
    setState(() {
      backendReport = report;
      isReportLoading = false;
    });
  }

  Future<void> _syncToServer() async {
    final syncedCount = await SyncService().syncOfflineCollections();
    if (!mounted) return;

    await _loadBackendReport();
    if (!mounted) return;
    setState(() {
      _collectionsFuture = LocalDatabase.instance.getCollections();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$syncedCount records synced successfully'),
        backgroundColor: _kGreen,
      ),
    );
  }

  void _backToHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/trip', (_) => false);
  }

  int _remainingStopCount(List<dynamic>? summaries) {
    if (summaries == null) return 0;
    return summaries.where((s) {
      if (s is! Map) return false;
      return (s['status']?.toString().trim().toLowerCase() ?? '') !=
          'collected';
    }).length;
  }

  int _completedStopCount(List<dynamic>? summaries) {
    if (summaries == null) return 0;
    return summaries.where((s) {
      if (s is! Map) return false;
      return (s['status']?.toString().trim().toLowerCase() ?? '') ==
          'collected';
    }).length;
  }

  double _totalDistanceFromSummaries(List<dynamic>? summaries) {
    if (summaries == null) return 0;
    return summaries.fold<double>(0, (sum, s) {
      if (s is! Map) return sum;
      final v = s['distanceKm'];
      return sum + (v is num ? v.toDouble() : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          // ── GRADIENT HEADER ────────────────────────────────────────────
          _ReportHeader(onBack: _backToHome, onSync: _syncToServer),

          // ── BODY ───────────────────────────────────────────────────────
          Expanded(
            child: isReportLoading
                ? const Center(child: CircularProgressIndicator(color: _kGreen))
                : FutureBuilder<List<CollectionModel>>(
                    future: _collectionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: _kGreen),
                        );
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
                      final localTotal = collections.fold<double>(
                        0,
                        (s, c) => s + c.totalKg,
                      );

                      final supplierSummaries =
                          backendReport?['supplierSummaries'] as List<dynamic>?;
                      final backendTotalCollected =
                          backendReport?['totalCollected'];
                      final backendTotalExpected =
                          backendReport?['totalExpected'];

                      final totalCollected = backendTotalCollected != null
                          ? (backendTotalCollected as num).toDouble()
                          : localTotal;
                      final totalExpected = backendTotalExpected != null
                          ? (backendTotalExpected as num).toDouble()
                          : 0.0;

                      // Distance: from summaries distanceKm, fallback 0
                      final totalDistance = _totalDistanceFromSummaries(
                        supplierSummaries,
                      );

                      final remainingStops = _remainingStopCount(
                        supplierSummaries,
                      );
                      final completedStops = _completedStopCount(
                        supplierSummaries,
                      );
                      final isTripCompleted =
                          supplierSummaries != null &&
                          supplierSummaries.isNotEmpty &&
                          remainingStops == 0;
                      final durationMinutes =
                          (isTripCompleted ? completedStops : remainingStops) *
                          30;
                      final durationLabel = isTripCompleted
                          ? 'Actual Trip Time'
                          : 'Est. Remaining';

                      final isEmpty =
                          backendReport == null || backendReport!.isEmpty;

                      return RefreshIndicator(
                        color: _kGreen,
                        onRefresh: () async {
                          await _loadBackendReport();
                          setState(() {
                            _collectionsFuture = LocalDatabase.instance
                                .getCollections();
                          });
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isEmpty)
                                _EmptyReportCard()
                              else ...[
                                // 1. Hero completion banner
                                _CompletionHero(
                                  isTripCompleted: isTripCompleted,
                                ),
                                const SizedBox(height: 20),

                                // 2. Summary cards row
                                _SummaryCardsRow(
                                  totalCollected: totalCollected,
                                  totalDistance: totalDistance,
                                  duration: _formatDuration(durationMinutes),
                                  durationLabel: durationLabel,
                                ),
                                const SizedBox(height: 16),

                                // 3. Supplier Summary header + legend
                                _SupplierSectionHeader(),
                                const SizedBox(height: 8),

                                // 4. Supplier tiles
                                if (supplierSummaries == null ||
                                    supplierSummaries.isEmpty)
                                  _EmptySupplierCard()
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < supplierSummaries.length;
                                        i++
                                      )
                                        _SupplierReportTile(
                                          summary: supplierSummaries[i],
                                          sequenceNumber: i + 1,
                                        ),
                                    ],
                                  ),

                                const SizedBox(height: 16),

                                // 5. Totals bottom card
                                _TotalsCard(
                                  totalExpected: totalExpected,
                                  totalCollected: totalCollected,
                                ),
                                const SizedBox(height: 22),
                              ],

                              // 6. Sync button
                              _SyncButton(onPressed: _syncToServer),
                              const SizedBox(height: 12),

                              // 7. Back to home
                              _BackHomeButton(onPressed: _backToHome),
                              const SizedBox(height: 16),

                              // 8. Footer note
                              const _FooterNote(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ReportHeader
// ═══════════════════════════════════════════════════════════════════════════
class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.onBack, required this.onSync});
  final VoidCallback onBack;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kGreenDark, _kGreen, Color(0xFF15A84A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(8, top + 8, 8, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Expanded(
            child: Text(
              'Trip Report',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            onPressed: onSync,
            icon: const Icon(
              Icons.cloud_upload_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CompletionHero
// ═══════════════════════════════════════════════════════════════════════════
class _CompletionHero extends StatelessWidget {
  const _CompletionHero({required this.isTripCompleted});
  final bool isTripCompleted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isTripCompleted ? _kGreenLight : _kBlueLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTripCompleted
                  ? Icons.check_circle_outline_rounded
                  : Icons.pending_outlined,
              size: 38,
              color: isTripCompleted ? _kGreen : _kBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isTripCompleted ? 'Trip Completed!' : 'Trip In Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isTripCompleted ? _kGreen : _kBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isTripCompleted
                ? 'Well done! All stops completed.'
                : 'Some scheduled stops are still pending.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SummaryCardsRow  — 3 compact summary cards
// ═══════════════════════════════════════════════════════════════════════════
class _SummaryCardsRow extends StatelessWidget {
  const _SummaryCardsRow({
    required this.totalCollected,
    required this.totalDistance,
    required this.duration,
    required this.durationLabel,
  });

  final double totalCollected;
  final double totalDistance;
  final String duration;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ReportSummaryCard(
          icon: Icons.recycling_rounded,
          label: 'Total Collected',
          value: '${_formatKg(totalCollected)} kg',
          iconBg: _kGreenLight,
          iconColor: _kGreen,
          valueColor: _kGreen,
        ),
        const SizedBox(width: 8),
        _ReportSummaryCard(
          icon: Icons.route_outlined,
          label: 'Total Distance',
          value: '${totalDistance.toStringAsFixed(1)} km',
          iconBg: _kBlueLight,
          iconColor: _kBlue,
          valueColor: _kBlue,
        ),
        const SizedBox(width: 8),
        _ReportSummaryCard(
          icon: Icons.timer_outlined,
          label: durationLabel,
          value: duration,
          iconBg: _kOrangeLight,
          iconColor: _kOrange,
          valueColor: _kOrange,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ReportSummaryCard  (reusable)
// ═══════════════════════════════════════════════════════════════════════════
class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconColor,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconBg;
  final Color iconColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SupplierSectionHeader
// ═══════════════════════════════════════════════════════════════════════════
class _SupplierSectionHeader extends StatelessWidget {
  const _SupplierSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Supplier Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
        // Legend
        Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 13, color: _kGreen),
            const SizedBox(width: 3),
            const Text(
              'Collected',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.warning_amber_rounded,
              size: 13,
              color: AppColors.warningRed,
            ),
            const SizedBox(width: 3),
            Text(
              'Shortfall',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warningRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SupplierReportTile  (reusable)
// ═══════════════════════════════════════════════════════════════════════════
class _SupplierReportTile extends StatelessWidget {
  const _SupplierReportTile({
    required this.summary,
    required this.sequenceNumber,
  });

  final dynamic summary;
  final int sequenceNumber;

  String _str(String key) {
    if (summary is Map) return (summary as Map)[key]?.toString() ?? '-';
    return '-';
  }

  double _num(String key) {
    if (summary is Map) {
      final v = (summary as Map)[key];
      if (v is num) return v.toDouble();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final name = _str('name');
    final expectedKg = _num('expectedKg');
    final collectedKg = _num('collectedKg');
    final status = _str('status');
    final normalized = status.trim().toLowerCase();

    final bool isCollected = normalized == 'collected';
    final bool hasShortfall = collectedKg < expectedKg;
    final bool isPending = !isCollected;

    // Color scheme
    final Color statusColor;
    final Color borderColor;
    final IconData statusIcon;
    final String statusLabel;

    if (isCollected && !hasShortfall) {
      statusColor = _kGreen;
      borderColor = _kGreen.withValues(alpha: 0.2);
      statusIcon = Icons.check_circle_outline_rounded;
      statusLabel = 'Collected';
    } else if (hasShortfall && isCollected) {
      statusColor = AppColors.warningRed;
      borderColor = AppColors.warningRed.withValues(alpha: 0.25);
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = 'Shortfall';
    } else if (isPending) {
      statusColor = const Color(0xFF546E7A);
      borderColor = AppColors.borderColor;
      statusIcon = Icons.schedule_outlined;
      statusLabel = 'Pending';
    } else {
      statusColor = AppColors.warningRed;
      borderColor = AppColors.warningRed.withValues(alpha: 0.25);
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = 'Shortfall';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sequence badge
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              sequenceNumber.toString(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Center info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Expected: ${_formatKg(expectedKg)} kg',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasShortfall && isCollected) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Shortfall: ${_formatKg(expectedKg - collectedKg)} kg',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warningRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right: status chip + collected kg
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCollected) ...[
                const SizedBox(height: 4),
                Text(
                  '${_formatKg(collectedKg)} kg',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _TotalsCard  (reusable)
// ═══════════════════════════════════════════════════════════════════════════
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totalExpected,
    required this.totalCollected,
  });

  final double totalExpected;
  final double totalCollected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreenLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Expected',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatKg(totalExpected)} kg',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: _kGreen.withValues(alpha: 0.25),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Collected',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatKg(totalCollected)} kg',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _kGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SyncButton
// ═══════════════════════════════════════════════════════════════════════════
class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreenDark, _kGreen],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Sync to Server',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _BackHomeButton
// ═══════════════════════════════════════════════════════════════════════════
class _BackHomeButton extends StatelessWidget {
  const _BackHomeButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined, size: 20),
        label: const Text('Back To Home'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _kGreen),
          foregroundColor: _kGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _FooterNote
// ═══════════════════════════════════════════════════════════════════════════
class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.mutedText),
        SizedBox(width: 5),
        Text(
          'All data will be securely saved to the server.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _EmptyReportCard
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyReportCard extends StatelessWidget {
  const _EmptyReportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.mutedText),
          SizedBox(height: 12),
          Text(
            'No report data available.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _EmptySupplierCard
// ═══════════════════════════════════════════════════════════════════════════
class _EmptySupplierCard extends StatelessWidget {
  const _EmptySupplierCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No supplier summaries found.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
