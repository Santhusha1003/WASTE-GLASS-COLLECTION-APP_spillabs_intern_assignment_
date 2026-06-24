import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';

// ─── Palette helpers ───────────────────────────────────────────────────────
const _kGreen = Color(0xFF0A8F35);
const _kGreenDark = Color(0xFF076828);
const _kGreenLight = Color(0xFFEAF7EE);
const _kBlueGrey = Color(0xFF546E7A);
const _kBlueGreyLight = Color(0xFFECF0F1);

// ═══════════════════════════════════════════════════════════════════════════
// SupplierModel
// ═══════════════════════════════════════════════════════════════════════════
class SupplierModel {
  const SupplierModel({
    required this.supplierId,
    required this.name,
    required this.location,
    required this.expectedKg,
    required this.distanceKm,
    required this.stopSequence,
    required this.barcodeValue,
    required this.status,
  });

  final String supplierId;
  final String name;
  final String location;
  final double expectedKg;
  final double distanceKm;
  final int stopSequence;
  final String barcodeValue;
  final String status;

  Map<String, dynamic> toMap() => {
    'supplierId': supplierId,
    'name': name,
    'location': location,
    'expectedKg': expectedKg,
    'distanceKm': distanceKm,
    'distance': '${distanceKm.toStringAsFixed(1)} km',
    'stopSequence': stopSequence,
    'barcodeValue': barcodeValue,
    'status': status,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// TripScreen
// ═══════════════════════════════════════════════════════════════════════════
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> with WidgetsBindingObserver {
  List<SupplierModel> todaySuppliers = [];
  List<SupplierModel> tomorrowSuppliers = [];
  bool isLoading = true;
  bool _completionDialogShown = false;
  late DateTime _loadedDay;
  Timer? _dayChangeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadedDay = _dateOnly(DateTime.now());
    _loadTodayAndTomorrowRoutes();
    _dayChangeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _reloadIfDayChanged(),
    );
  }

  @override
  void dispose() {
    _dayChangeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadIfDayChanged();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _reloadIfDayChanged() {
    final currentDay = _dateOnly(DateTime.now());
    if (currentDay != _loadedDay) _loadTodayAndTomorrowRoutes();
  }

  List<SupplierModel> _mapStops(Map<String, dynamic> route) {
    final stops = route['stops'] as List<dynamic>? ?? [];
    return stops.asMap().entries.map((entry) {
      final item = entry.value;
      return SupplierModel(
        supplierId: item['supplierId']?.toString() ?? '',
        name: item['name']?.toString() ?? '',
        location: item['location']?.toString() ?? '',
        expectedKg: (item['expectedKg'] as num?)?.toDouble() ?? 0,
        distanceKm: (item['distanceKm'] as num?)?.toDouble() ?? 0,
        stopSequence: (item['stopSequence'] as num?)?.toInt() ?? entry.key + 1,
        barcodeValue: item['barcodeValue']?.toString() ?? '',
        status: item['status']?.toString() ?? '',
      );
    }).toList();
  }

  Future<void> _loadTodayAndTomorrowRoutes() async {
    setState(() {
      isLoading = true;
      _completionDialogShown = false;
    });

    try {
      final today = _dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      final todayDate = DateFormat('yyyy-MM-dd').format(today);
      final tomorrowDate = DateFormat('yyyy-MM-dd').format(tomorrow);
      final routes = await Future.wait([
        ApiService().getRouteByDate(todayDate),
        ApiService().getRouteByDate(tomorrowDate),
      ]);
      if (!mounted) return;

      setState(() {
        _loadedDay = today;
        todaySuppliers = _mapStops(routes[0]);
        tomorrowSuppliers = _mapStops(routes[1]);
        isLoading = false;
      });

      _showCompletionDialogIfNeeded();
    } catch (error) {
      debugPrint('Load route error: $error');
      if (!mounted) return;
      setState(() {
        todaySuppliers = [];
        tomorrowSuppliers = [];
        isLoading = false;
      });
    }
  }

  Future<void> _loadSuppliersFromApi() => _loadTodayAndTomorrowRoutes();

  // ── Computed props ──────────────────────────────────────────────────────
  int get remainingStops =>
      todaySuppliers.where((s) => s.status.toLowerCase() != 'collected').length;

  double get totalDistance =>
      todaySuppliers.fold<double>(0, (sum, s) => sum + s.distanceKm);

  bool get allCollected => todaySuppliers.isNotEmpty && remainingStops == 0;

  /// Returns the index of the first pending stop, or -1.
  int get _nextStopIndex {
    for (var i = 0; i < todaySuppliers.length; i++) {
      if (todaySuppliers[i].status.toLowerCase() != 'collected') return i;
    }
    return -1;
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '—';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String get _estimatedDuration {
    final totalMinutes = todaySuppliers.length * 30;
    return _formatDuration(totalMinutes);
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  void _startCollection() {
    if (remainingStops == 0) {
      Navigator.pushNamed(context, '/report');
      return;
    }
    final idx = _nextStopIndex;
    if (idx == -1) {
      Navigator.pushNamed(context, '/report');
      return;
    }
    Navigator.pushNamed(
      context,
      '/scan',
      arguments: todaySuppliers[idx].toMap(),
    );
  }

  void _showCompletionDialogIfNeeded() {
    if (_completionDialogShown ||
        todaySuppliers.isEmpty ||
        remainingStops != 0) {
      return;
    }
    _completionDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Today's Route Completed"),
          content: const Text(
            'All scheduled collection stops for today have been completed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/report');
              },
              child: const Text('View Trip Report'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  void _showSupplierDetails(
    SupplierModel supplier, {
    required bool isTomorrow,
  }) {
    final isCollected = supplier.status.toLowerCase() == 'collected';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet header
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
                              color: _kGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusChip(
                      status: supplier.status,
                      forcePending: isTomorrow,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                // Detail rows
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Supplier ID',
                  value: supplier.supplierId,
                ),
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Supplier Name',
                  value: supplier.name,
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: supplier.location,
                ),
                _DetailRow(
                  icon: Icons.scale_outlined,
                  label: 'Expected KG',
                  value: '${_formatKg(supplier.expectedKg)} kg',
                ),
                _DetailRow(
                  icon: Icons.route_outlined,
                  label: 'Distance KM',
                  value: '${supplier.distanceKm.toStringAsFixed(1)} km',
                ),
                _DetailRow(
                  icon: Icons.qr_code,
                  label: 'Barcode',
                  value: supplier.barcodeValue,
                ),
                _DetailRow(
                  icon: Icons.info_outline,
                  label: 'Status',
                  value: supplier.status,
                ),
                const SizedBox(height: 20),
                if (isTomorrow) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kGreenLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'This stop is scheduled for tomorrow.',
                      style: TextStyle(
                        color: _kGreenDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Navigate button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: isCollected || isTomorrow
                        ? null
                        : () {
                            Navigator.pop(sheetCtx);
                            Navigator.pushNamed(
                              context,
                              '/scan',
                              arguments: supplier.toMap(),
                            );
                          },
                    icon: Icon(
                      isCollected
                          ? Icons.check_circle_outline
                          : Icons.navigation_outlined,
                    ),
                    label: Text(
                      isTomorrow
                          ? 'Available Tomorrow'
                          : isCollected
                          ? 'Already Collected'
                          : 'Navigate & Collect',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kGreen),
                      foregroundColor: _kGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

  String _formatKg(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final todayLabel = DateFormat('EEEE, d MMMM yyyy').format(today);
    final tomorrowLabel = DateFormat('EEEE, d MMMM yyyy').format(tomorrow);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          // ── GRADIENT HEADER ──────────────────────────────────────────────
          _GradientHeader(dateLabel: todayLabel),

          // ── SCROLLABLE BODY ──────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: _kGreen,
              onRefresh: _loadSuppliersFromApi,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── SUMMARY CARDS ──────────────────────────────────
                        Row(
                          children: [
                            RouteSummaryCard(
                              icon: Icons.map_outlined,
                              label: 'Total Distance',
                              value: isLoading
                                  ? '—'
                                  : '${totalDistance.toStringAsFixed(1)} km',
                            ),
                            const SizedBox(width: 12),
                            RouteSummaryCard(
                              icon: Icons.local_shipping_outlined,
                              label: 'Remaining Stops',
                              value: isLoading
                                  ? '—'
                                  : remainingStops.toString(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── STOP SEQUENCE HEADER ──────────────────────────
                        Row(
                          children: [
                            Text(
                              'Stop Sequence',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textDark,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ]),
                    ),
                  ),

                  if (isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: _kGreen),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _RouteDateSection(
                              sectionLabel: 'Today',
                              dateText: todayLabel,
                              suppliers: todaySuppliers,
                              nextStopIndex: _nextStopIndex,
                              emptyMessage: 'No stops scheduled for today',
                              onSupplierTap: (supplier) => _showSupplierDetails(
                                supplier,
                                isTomorrow: false,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _RouteDateSection(
                              sectionLabel: 'Tomorrow',
                              dateText: tomorrowLabel,
                              suppliers: tomorrowSuppliers,
                              nextStopIndex: -1,
                              emptyMessage: 'No stops scheduled for tomorrow',
                              forcePending: true,
                              onSupplierTap: (supplier) => _showSupplierDetails(
                                supplier,
                                isTomorrow: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── BOTTOM INFO PANEL ────────────────────────────────────
                  if (!isLoading && todaySuppliers.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _BottomInfoPanel(
                          estimatedDuration: _estimatedDuration,
                        ),
                      ),
                    ),

                  // ── ROUTE COMPLETED CARD or START BUTTON ─────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: isLoading
                          ? const SizedBox.shrink()
                          : allCollected
                          ? RouteCompletedCard(
                              onViewReport: () =>
                                  Navigator.pushNamed(context, '/report'),
                              onStartNext: _loadSuppliersFromApi,
                            )
                          : _StartCollectionButton(onPressed: _startCollection),
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
// _GradientHeader
// ═══════════════════════════════════════════════════════════════════════════
class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kGreenDark, _kGreen, Color(0xFF15A84A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 22),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_none_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Waste Glass Collection',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Today's Route",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Today — $dateLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RouteSummaryCard  (reusable widget)
// ═══════════════════════════════════════════════════════════════════════════
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kGreenLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _kGreen, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
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

// ═══════════════════════════════════════════════════════════════════════════
// _RouteDateSection
// ═══════════════════════════════════════════════════════════════════════════
class _RouteDateSection extends StatelessWidget {
  const _RouteDateSection({
    required this.sectionLabel,
    required this.dateText,
    required this.suppliers,
    required this.nextStopIndex,
    required this.emptyMessage,
    required this.onSupplierTap,
    this.forcePending = false,
  });

  final String sectionLabel;
  final String dateText;
  final List<SupplierModel> suppliers;
  final int nextStopIndex;
  final String emptyMessage;
  final ValueChanged<SupplierModel> onSupplierTap;
  final bool forcePending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: _kGreenLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kGreen.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  sectionLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${suppliers.length} ${suppliers.length == 1 ? 'stop' : 'stops'}',
                style: const TextStyle(
                  color: _kBlueGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dateText,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (suppliers.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            for (var index = 0; index < suppliers.length; index++)
              StopCard(
                supplier: suppliers[index],
                sequenceNumber: suppliers[index].stopSequence > 0
                    ? suppliers[index].stopSequence
                    : index + 1,
                isNext: index == nextStopIndex,
                forcePending: forcePending,
                onTap: () => onSupplierTap(suppliers[index]),
              ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// StatusChip  (reusable widget)
// ═══════════════════════════════════════════════════════════════════════════
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.isNext = false,
    this.forcePending = false,
  });

  final String status;
  final bool isNext;
  final bool forcePending;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final bool collected = normalized == 'collected';
    final bool next = !forcePending && (isNext || normalized == 'next');

    Color bgColor;
    Color textColor;
    Color borderColor;
    String label;
    bool outlined = false;

    if (collected) {
      bgColor = _kGreenLight;
      textColor = _kGreen;
      borderColor = _kGreen.withValues(alpha: 0.4);
      label = 'COLLECTED';
      outlined = true;
    } else if (next) {
      bgColor = _kGreen;
      textColor = Colors.white;
      borderColor = _kGreen;
      label = 'NEXT';
    } else {
      bgColor = _kBlueGreyLight;
      textColor = _kBlueGrey;
      borderColor = _kBlueGrey.withValues(alpha: 0.3);
      label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// StopCard  (reusable widget)
// ═══════════════════════════════════════════════════════════════════════════
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.supplier,
    required this.sequenceNumber,
    required this.isNext,
    required this.onTap,
    this.forcePending = false,
  });

  final SupplierModel supplier;
  final int sequenceNumber;
  final bool isNext;
  final VoidCallback onTap;
  final bool forcePending;

  @override
  Widget build(BuildContext context) {
    final bool collected = supplier.status.toLowerCase() == 'collected';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isNext
              ? Border.all(color: _kGreen.withValues(alpha: 0.35), width: 1.5)
              : Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isNext ? 0.08 : 0.045),
              blurRadius: isNext ? 20 : 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular sequence badge
              _SequenceBadge(
                number: sequenceNumber,
                isNext: isNext,
                collected: collected,
              ),
              const SizedBox(width: 14),

              // Center info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            supplier.location,
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (supplier.distanceKm > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.route_outlined,
                            size: 14,
                            color: AppColors.mutedText,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${supplier.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right side: status chip + arrow
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(
                    status: supplier.status,
                    isNext: isNext,
                    forcePending: forcePending,
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.mutedText,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SequenceBadge extends StatelessWidget {
  const _SequenceBadge({
    required this.number,
    required this.isNext,
    required this.collected,
  });

  final int number;
  final bool isNext;
  final bool collected;

  @override
  Widget build(BuildContext context) {
    final bgColor = collected
        ? _kGreenLight
        : isNext
        ? _kGreen
        : _kBlueGreyLight;
    final textColor = collected
        ? _kGreen
        : isNext
        ? Colors.white
        : _kBlueGrey;

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: collected
          ? Icon(Icons.check, color: textColor, size: 20)
          : Text(
              number.toString(),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _BottomInfoPanel
// ═══════════════════════════════════════════════════════════════════════════
class _BottomInfoPanel extends StatelessWidget {
  const _BottomInfoPanel({required this.estimatedDuration});
  final String estimatedDuration;

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
            child: _InfoItem(
              icon: Icons.warehouse_outlined,
              label: 'Start Location',
              value: 'Depot - Main Office',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: _kGreen.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _InfoItem(
              icon: Icons.access_time_outlined,
              label: 'Est. Duration',
              value: estimatedDuration,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: _kGreen, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _StartCollectionButton
// ═══════════════════════════════════════════════════════════════════════════
class _StartCollectionButton extends StatelessWidget {
  const _StartCollectionButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreenDark, _kGreen],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Text(
                'Start Collection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
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
// RouteCompletedCard  (reusable widget)
// ═══════════════════════════════════════════════════════════════════════════
class RouteCompletedCard extends StatelessWidget {
  const RouteCompletedCard({
    super.key,
    required this.onViewReport,
    required this.onStartNext,
  });

  final VoidCallback onViewReport;
  final VoidCallback onStartNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: _kGreen,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Route Completed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All scheduled stops have been processed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewReport,
                  icon: const Icon(Icons.assessment_outlined, size: 18),
                  label: const Text('View Trip Report'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kGreen),
                    foregroundColor: _kGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStartNext,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Start Next Route'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _DetailRow  (bottom sheet detail row)
// ═══════════════════════════════════════════════════════════════════════════
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kGreen),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
