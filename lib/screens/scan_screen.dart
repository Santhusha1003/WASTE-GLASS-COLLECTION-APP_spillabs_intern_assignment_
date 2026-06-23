import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../database/local_database.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_button.dart';

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
  bool _isDevModeVerified = false;
  bool _isSaving = false;
  bool _didReadRouteArguments = false;
  int _offlineSavedCount = 0;
  String scannedSupplierId = '';
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

    if (_didReadRouteArguments) {
      return;
    }

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
      if (!mounted) {
        return;
      }

      setState(() {
        _offlineSavedCount = collections.length;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _offlineSavedCount = 0;
      });
    }
  }

  Future<void> _openScanner() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const _BarcodeScannerPage()),
    );

    if (!mounted || scannedValue == null) {
      return;
    }

    final normalizedValue = scannedValue.trim().toUpperCase();
    setState(() {
      scannedSupplierId = normalizedValue;
      isSupplierVerified =
          normalizedValue == _currentSupplier.expectedBarcode.toUpperCase();
      _isDevModeVerified = false;
    });

    if (isSupplierVerified) {
      _showSnackBar('Supplier Verified');
    } else {
      _showSnackBar('Wrong Supplier Barcode', isError: true);
    }
  }

  Future<void> _confirmCollection() async {
    if (!isSupplierVerified || _isSaving) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await LocalDatabase.instance.insertCollection(
        supplierId: _currentSupplier.supplierId,
        clearKg: double.parse(_clearGlassController.text.trim()),
        coloredKg: double.parse(_coloredGlassController.text.trim()),
        condition: _condition,
        timestamp: DateTime.now().toIso8601String(),
      );

      await _loadOfflineSavedCount();

      if (!mounted) {
        return;
      }

      _showSnackBar('Collection saved offline');
      Navigator.pushNamedAndRemoveUntil(context, '/report', (route) => false);
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to save collection', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // TODO: Remove DEV MODE before final submission
  void _skipBarcodeVerificationForDevMode() {
    setState(() {
      scannedSupplierId = _currentSupplier.supplierId;
      isSupplierVerified = true;
      _isDevModeVerified = true;
    });

    _showSnackBar('Supplier Verified (DEV MODE)');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.warningRed
            : AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan & Collect')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NextSupplierPanel(supplier: _currentSupplier),
                const SizedBox(height: 18),
                Container(
                  height: 220,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 58,
                        color: AppColors.primaryGreen,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Scan Supplier Barcode',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CustomButton(
                  label: 'Scan Barcode',
                  icon: Icons.document_scanner_outlined,
                  onPressed: _openScanner,
                ),
                const SizedBox(height: 10),
                CustomButton(
                  label: 'Skip Barcode Verification (DEV MODE)',
                  icon: Icons.bug_report_outlined,
                  onPressed: _skipBarcodeVerificationForDevMode,
                ),
                const SizedBox(height: 12),
                _VerificationStatus(
                  isSupplierVerified: isSupplierVerified,
                  isDevModeVerified: _isDevModeVerified,
                  scannedSupplierId: scannedSupplierId,
                  expectedSupplierId: _currentSupplier.expectedBarcode,
                ),
                const SizedBox(height: 12),
                Text(
                  'Offline Saved Collections: $_offlineSavedCount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Collection Form',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  enabled: isSupplierVerified,
                  controller: _clearGlassController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Clear Glass (kg)',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  validator: (value) =>
                      _requiredNumber(value, 'Clear Glass is required'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  enabled: isSupplierVerified,
                  controller: _coloredGlassController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coloured Glass (kg)',
                    prefixIcon: Icon(Icons.scale),
                  ),
                  validator: (value) =>
                      _requiredNumber(value, 'Coloured Glass is required'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _condition,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    prefixIcon: Icon(Icons.fact_check_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Good', child: Text('Good')),
                    DropdownMenuItem(value: 'Average', child: Text('Average')),
                    DropdownMenuItem(value: 'Poor', child: Text('Poor')),
                  ],
                  validator: _requiredCondition,
                  onChanged: isSupplierVerified
                      ? (value) {
                          if (value != null) {
                            setState(() => _condition = value);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 24),
                _buildConfirmButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final isEnabled = isSupplierVerified && !_isSaving;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: isEnabled ? _confirmCollection : null,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(_isSaving ? 'Saving...' : 'Confirm Collection'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  String? _requiredNumber(String? value, String emptyMessage) {
    final trimmedValue = value?.trim() ?? '';
    if (trimmedValue.isEmpty) {
      return emptyMessage;
    }

    final number = double.tryParse(trimmedValue);
    if (number == null || number < 0) {
      return 'Enter a valid quantity';
    }
    return null;
  }

  String? _requiredCondition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Select a condition';
    }
    return null;
  }
}

class _VerificationStatus extends StatelessWidget {
  const _VerificationStatus({
    required this.isSupplierVerified,
    required this.isDevModeVerified,
    required this.scannedSupplierId,
    required this.expectedSupplierId,
  });

  final bool isSupplierVerified;
  final bool isDevModeVerified;
  final String scannedSupplierId;
  final String expectedSupplierId;

  @override
  Widget build(BuildContext context) {
    if (scannedSupplierId.isEmpty) {
      return const Text(
        'Scan the expected supplier barcode to unlock the collection form.',
        style: TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Row(
      children: [
        Icon(
          isSupplierVerified ? Icons.verified : Icons.error_outline,
          color: isSupplierVerified
              ? AppColors.primaryGreen
              : AppColors.warningRed,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isSupplierVerified
                ? isDevModeVerified
                      ? 'Supplier Verified (DEV MODE)'
                      : 'Supplier Verified'
                : 'Scanned: $scannedSupplierId, expected: $expectedSupplierId',
            style: TextStyle(
              color: isSupplierVerified
                  ? AppColors.primaryGreen
                  : AppColors.warningRed,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

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
    if (_hasScanned) {
      return;
    }

    String? value;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        value = rawValue;
        break;
      }
    }

    if (value == null || value.trim().isEmpty) {
      return;
    }

    _hasScanned = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Supplier Barcode')),
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

class _NextSupplierPanel extends StatelessWidget {
  const _NextSupplierPanel({required this.supplier});

  final _ScanSupplier supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            'Next Supplier',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            supplier.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(supplier.location)),
            ],
          ),
          if (supplier.distance.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.route_outlined, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                Text(supplier.distance),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Text('Supplier ID: ${supplier.supplierId}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_outlined,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 6),
              Text('Expected barcode: ${supplier.expectedBarcode}'),
            ],
          ),
        ],
      ),
    );
  }
}

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

  String get expectedBarcode {
    if (barcodeValue.trim().isNotEmpty) {
      return barcodeValue.trim();
    }

    return supplierId.trim();
  }

  static String _readValue(
    Map<dynamic, dynamic> map,
    String camelCaseKey,
    String pascalCaseKey, {
    String fallback = '',
  }) {
    final value = map[camelCaseKey] ?? map[pascalCaseKey];
    return value?.toString() ?? fallback;
  }
}
