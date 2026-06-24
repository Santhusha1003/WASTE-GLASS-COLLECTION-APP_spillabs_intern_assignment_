import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../database/local_database.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

// ── Palette helpers (mirrors trip_screen) ─────────────────────────────────
const _kGreen = Color(0xFF0A8F35);
const _kGreenDark = Color(0xFF076828);
const _kGreenLight = Color(0xFFEAF7EE);

// ═══════════════════════════════════════════════════════════════════════════
// ScanScreen
// ═══════════════════════════════════════════════════════════════════════════
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clearGlassController = TextEditingController();
  final _coloredGlassController = TextEditingController();

  bool isSupplierVerified = false;
  bool _isSaving = false;
  bool _didReadRouteArguments = false;
  int _offlineSavedCount = 0;
  String scannedSupplierId = '';
  String _verifiedSupplierId = '';
  String _condition = 'Good';

  _ScanSupplier _selectedSupplier = const _ScanSupplier(
    supplierId: '',
    name: 'Selected Supplier',
    location: '',
    distance: '',
    barcodeValue: '',
  );

  _ScanSupplier get _currentSupplier => _selectedSupplier;

  @override
  void initState() {
    super.initState();
    _loadOfflineSavedCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadRouteArguments) return;
    _didReadRouteArguments = true;
    _selectedSupplier = _ScanSupplier.fromRouteArguments(
      ModalRoute.of(context)?.settings.arguments,
    );
  }

  @override
  void dispose() {
    _clearGlassController.dispose();
    _coloredGlassController.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineSavedCount() async {
    try {
      final collections = await LocalDatabase.instance.getCollections();
      if (!mounted) return;
      setState(() => _offlineSavedCount = collections.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _offlineSavedCount = 0);
    }
  }

  Future<void> _openScanner() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
    if (!mounted || scannedValue == null) return;

    _verifyScannedBarcode(scannedValue);
  }

  void _verifyScannedBarcode(String barcode) {
    final normalized = barcode.trim().toUpperCase();
    final supplierId = _currentSupplier.supplierId.trim().toUpperCase();
    final barcodeValue = _currentSupplier.barcodeValue.trim().toUpperCase();
    final verified =
        normalized == supplierId ||
        (barcodeValue.isNotEmpty && normalized == barcodeValue);

    setState(() {
      scannedSupplierId = normalized;
      isSupplierVerified = verified;
      _verifiedSupplierId = verified ? supplierId : '';
    });

    if (verified) {
      _showSnackBar('Supplier Verified');
    } else {
      _showSnackBar(
        'Wrong supplier barcode. Please scan the current stop barcode.',
        isError: true,
      );
    }
  }

  Future<void> _confirmCollection() async {
    if (!isSupplierVerified || _verifiedSupplierId.isEmpty || _isSaving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final clearKg = double.parse(_clearGlassController.text.trim());
      final coloredKg = double.parse(_coloredGlassController.text.trim());
      final api = ApiService();
      final submitted = await api.createCollection(
        supplierId: _verifiedSupplierId,
        clearKg: clearKg,
        coloredKg: coloredKg,
        condition: _condition,
      );

      if (submitted) {
        // Re-read every API resource affected by collection creation before
        // showing summary/report screens.
        await Future.wait([
          api.getCollections(),
          api.getTodayRoute(),
          api.getReport(),
        ]);
      } else {
        await LocalDatabase.instance.insertCollection(
          supplierId: _verifiedSupplierId,
          clearKg: clearKg,
          coloredKg: coloredKg,
          condition: _condition,
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      await _loadOfflineSavedCount();
      if (!mounted) return;

      _showSnackBar(
        submitted
            ? 'Collection confirmed successfully'
            : 'No connection. Collection saved offline',
      );
      Navigator.pushNamedAndRemoveUntil(context, '/report', (_) => false);
    } catch (_) {
      if (mounted) _showSnackBar('Failed to save collection', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.warningRed : _kGreen,
      ),
    );
  }

  String? _requiredNumber(String? value, String emptyMsg) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return emptyMsg;
    final n = double.tryParse(v);
    if (n == null || n < 0) return 'Enter a valid quantity';
    return null;
  }

  String? _requiredCondition(String? value) {
    if (value == null || value.trim().isEmpty) return 'Select a condition';
    return null;
  }

  // ── build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          // ── GRADIENT HEADER ────────────────────────────────────────────
          _ScanHeader(onBack: () => Navigator.maybePop(context)),

          // ── SCROLLABLE CONTENT ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Next Stop card
                    _NextStopCard(supplier: _currentSupplier),
                    const SizedBox(height: 20),

                    // 2. Scan section title
                    _SectionLabel(
                      text: 'Scan Supplier Barcode',
                      trailing: _offlineSavedCount > 0
                          ? Text(
                              '$_offlineSavedCount saved offline',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),

                    // 3. Compact scan area
                    _ScanFrameCard(onScan: _openScanner),
                    const SizedBox(height: 12),

                    // 4. Scan button
                    _ScanBarcodeButton(onPressed: _openScanner),
                    const SizedBox(height: 12),

                    // 5. Verification status
                    _VerificationBadge(
                      isVerified: isSupplierVerified,
                      scannedId: scannedSupplierId,
                    ),
                    const SizedBox(height: 20),

                    // 6. Collection details card
                    _CollectionDetailsCard(
                      isEnabled: isSupplierVerified,
                      clearGlassController: _clearGlassController,
                      coloredGlassController: _coloredGlassController,
                      condition: _condition,
                      onConditionChanged: (v) {
                        if (v != null) setState(() => _condition = v);
                      },
                      requiredNumber: _requiredNumber,
                      requiredCondition: _requiredCondition,
                    ),
                    const SizedBox(height: 20),

                    // 7. Confirm button
                    _ConfirmButton(
                      isEnabled: isSupplierVerified && !_isSaving,
                      isSaving: _isSaving,
                      onPressed: _confirmCollection,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ScanHeader  — gradient app bar
// ═══════════════════════════════════════════════════════════════════════════
class _ScanHeader extends StatelessWidget {
  const _ScanHeader({required this.onBack});
  final VoidCallback onBack;

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
              'Scan & Collect',
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
            onPressed: () {},
            icon: const Icon(
              Icons.help_outline_rounded,
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
// _NextStopCard  — compact light-green supplier card
// ═══════════════════════════════════════════════════════════════════════════
class _NextStopCard extends StatelessWidget {
  const _NextStopCard({required this.supplier});
  final _ScanSupplier supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kGreenLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Stop',
                  style: TextStyle(
                    color: _kGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  supplier.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (supplier.location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          supplier.location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (supplier.distance.isNotEmpty) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.near_me_outlined, size: 16, color: _kGreen),
                const SizedBox(height: 4),
                Text(
                  supplier.distance,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SectionLabel
// ═══════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ScanFrameCard  — compact scan preview with corner brackets
// ═══════════════════════════════════════════════════════════════════════════
class _ScanFrameCard extends StatelessWidget {
  const _ScanFrameCard({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onScan,
      child: Container(
        height: 176,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _kGreen.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Corner brackets
            ..._corners(),
            // Center content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.barcode_reader,
                    size: 44,
                    color: _kGreen.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Position barcode within the frame',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedText,
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

  List<Widget> _corners() {
    const size = 22.0;
    const thickness = 3.0;
    const color = _kGreen;
    const pad = 16.0;

    Widget bracket({
      required Alignment alignment,
      required BorderRadius radius,
      required Border border,
    }) {
      return Positioned.fill(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(pad),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(border: border, borderRadius: radius),
            ),
          ),
        ),
      );
    }

    return [
      bracket(
        alignment: Alignment.topLeft,
        radius: const BorderRadius.only(topLeft: Radius.circular(6)),
        border: const Border(
          top: BorderSide(color: color, width: thickness),
          left: BorderSide(color: color, width: thickness),
        ),
      ),
      bracket(
        alignment: Alignment.topRight,
        radius: const BorderRadius.only(topRight: Radius.circular(6)),
        border: const Border(
          top: BorderSide(color: color, width: thickness),
          right: BorderSide(color: color, width: thickness),
        ),
      ),
      bracket(
        alignment: Alignment.bottomLeft,
        radius: const BorderRadius.only(bottomLeft: Radius.circular(6)),
        border: const Border(
          bottom: BorderSide(color: color, width: thickness),
          left: BorderSide(color: color, width: thickness),
        ),
      ),
      bracket(
        alignment: Alignment.bottomRight,
        radius: const BorderRadius.only(bottomRight: Radius.circular(6)),
        border: const Border(
          bottom: BorderSide(color: color, width: thickness),
          right: BorderSide(color: color, width: thickness),
        ),
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ScanBarcodeButton
// ═══════════════════════════════════════════════════════════════════════════
class _ScanBarcodeButton extends StatelessWidget {
  const _ScanBarcodeButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.document_scanner_outlined, size: 18),
        label: const Text('Scan Barcode'),
        style: FilledButton.styleFrom(
          backgroundColor: _kGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          elevation: 0,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _VerificationBadge
// ═══════════════════════════════════════════════════════════════════════════
class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.isVerified, required this.scannedId});

  final bool isVerified;
  final String scannedId;

  @override
  Widget build(BuildContext context) {
    if (scannedId.isEmpty) {
      return const Text(
        'Scan the current supplier barcode to unlock the collection form.',
        style: TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final color = isVerified ? _kGreen : AppColors.warningRed;
    final label = isVerified
        ? 'Supplier Verified'
        : 'Barcode does not match the current stop';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified_outlined : Icons.error_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CollectionDetailsCard
// ═══════════════════════════════════════════════════════════════════════════
class _CollectionDetailsCard extends StatelessWidget {
  const _CollectionDetailsCard({
    required this.isEnabled,
    required this.clearGlassController,
    required this.coloredGlassController,
    required this.condition,
    required this.onConditionChanged,
    required this.requiredNumber,
    required this.requiredCondition,
  });

  final bool isEnabled;
  final TextEditingController clearGlassController;
  final TextEditingController coloredGlassController;
  final String condition;
  final ValueChanged<String?> onConditionChanged;
  final String? Function(String?, String) requiredNumber;
  final String? Function(String?) requiredCondition;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card title
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _kGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Collection Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              if (!isEnabled) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Locked',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Clear glass
          _CollectionRow(
            icon: Icons.water_outlined,
            label: 'Clear Glass',
            child: TextFormField(
              enabled: isEnabled,
              controller: clearGlassController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _fieldDecoration('e.g. 10.5'),
              validator: (v) => requiredNumber(v, 'Clear Glass is required'),
            ),
          ),
          const SizedBox(height: 10),

          // Coloured glass
          _CollectionRow(
            icon: Icons.color_lens_outlined,
            label: 'Colored Glass',
            child: TextFormField(
              enabled: isEnabled,
              controller: coloredGlassController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _fieldDecoration('e.g. 5.0'),
              validator: (v) => requiredNumber(v, 'Colored Glass is required'),
            ),
          ),
          const SizedBox(height: 10),

          // Condition
          _CollectionRow(
            icon: Icons.fact_check_outlined,
            label: 'Condition',
            child: DropdownButtonFormField<String>(
              initialValue: condition,
              decoration: _fieldDecoration(null),
              items: const [
                DropdownMenuItem(value: 'Good', child: Text('Good')),
                DropdownMenuItem(value: 'Average', child: Text('Average')),
                DropdownMenuItem(value: 'Poor', child: Text('Poor')),
              ],
              validator: requiredCondition,
              onChanged: isEnabled ? onConditionChanged : null,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      filled: true,
      fillColor: AppColors.backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kGreen, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.borderColor.withValues(alpha: 0.5),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.warningRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.warningRed, width: 1.5),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 96,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _kGreenLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: _kGreen),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ConfirmButton  — gradient full-width button
// ═══════════════════════════════════════════════════════════════════════════
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.isEnabled,
    required this.isSaving,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [_kGreenDark, _kGreen],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isEnabled ? null : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: _kGreen.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              const SizedBox(width: 10),
              Text(
                isSaving ? 'Saving...' : 'Confirm Collection',
                style: TextStyle(
                  color: isEnabled ? Colors.white : Colors.grey.shade600,
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
// _BarcodeScannerPage  — UNCHANGED logic, only minor style tweak
// ═══════════════════════════════════════════════════════════════════════════
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;

    String? value;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        value = raw;
        break;
      }
    }

    if (value == null || value.trim().isEmpty) return;

    _hasScanned = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Supplier Barcode'),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleBarcode),
          Center(
            child: Container(
              width: 260,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: Colors.black.withValues(alpha: 0.55),
              child: const SafeArea(
                top: false,
                child: Text(
                  'Scan the selected supplier barcode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ScanSupplier  — UNCHANGED model
// ═══════════════════════════════════════════════════════════════════════════
class _ScanSupplier {
  const _ScanSupplier({
    required this.supplierId,
    required this.name,
    required this.location,
    required this.distance,
    required this.barcodeValue,
  });

  factory _ScanSupplier.fromRouteArguments(Object? arguments) {
    if (arguments is Map) {
      final supplierId = _readValue(arguments, 'supplierId', 'SupplierId');
      return _ScanSupplier(
        supplierId: supplierId,
        name: _readValue(
          arguments,
          'name',
          'Name',
          fallback: 'Selected Supplier',
        ),
        location: _readValue(arguments, 'location', 'Location'),
        distance: _readValue(arguments, 'distance', 'Distance'),
        barcodeValue: _readValue(
          arguments,
          'barcodeValue',
          'BarcodeValue',
          fallback: supplierId,
        ),
      );
    }
    return const _ScanSupplier(
      supplierId: '',
      name: 'Selected Supplier',
      location: '',
      distance: '',
      barcodeValue: '',
    );
  }

  final String supplierId;
  final String name;
  final String location;
  final String distance;
  final String barcodeValue;

  static String _readValue(
    Map<dynamic, dynamic> map,
    String camelKey,
    String pascalKey, {
    String fallback = '',
  }) {
    final value = map[camelKey] ?? map[pascalKey];
    return value?.toString() ?? fallback;
  }
}
