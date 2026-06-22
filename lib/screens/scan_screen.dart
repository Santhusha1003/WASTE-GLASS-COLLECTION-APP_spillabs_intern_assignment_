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
  static const List<_ScanSupplier> _suppliers = [
    _ScanSupplier(
      id: 'SUP001',
      name: 'ABC Glass Supplier',
      location: 'Kandy Road',
      distance: '2.4 km away',
    ),
    _ScanSupplier(
      id: 'SUP002',
      name: 'XYZ Glass Center',
      location: 'Matale Road',
      distance: '3.7 km away',
    ),
    _ScanSupplier(
      id: 'SUP003',
      name: 'Green Glass Hub',
      location: 'Dambulla',
      distance: '4.1 km away',
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _clearGlassController = TextEditingController();
  final _coloredGlassController = TextEditingController();
  bool isSupplierVerified = false;
  bool _isSaving = false;
  int _currentSupplierIndex = 0;
  int _offlineSavedCount = 0;
  String scannedSupplierId = '';
  String _condition = 'Good';

  _ScanSupplier get _currentSupplier => _suppliers[_currentSupplierIndex];

  @override
  void initState() {
    super.initState();
    _loadOfflineSavedCount();
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
      isSupplierVerified = normalizedValue == _currentSupplier.id;
    });

    if (!isSupplierVerified) {
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
        supplierId: _currentSupplier.id,
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
      if (_currentSupplierIndex < _suppliers.length - 1) {
        _moveToNextStop();
      } else {
        Navigator.pushNamed(context, '/report');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Could not save collection offline', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _moveToNextStop() {
    setState(() {
      _currentSupplierIndex += 1;
      isSupplierVerified = false;
      scannedSupplierId = '';
      _condition = 'Good';
      _clearGlassController.clear();
      _coloredGlassController.clear();
    });
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
                const SizedBox(height: 12),
                _VerificationStatus(
                  isSupplierVerified: isSupplierVerified,
                  scannedSupplierId: scannedSupplierId,
                  expectedSupplierId: _currentSupplier.id,
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
                  validator: _requiredNumber,
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
                  validator: _requiredNumber,
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
                  onChanged: isSupplierVerified
                      ? (value) {
                          if (value != null) {
                            setState(() => _condition = value);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: _isSaving ? 'Saving...' : 'Confirm Collection',
                  icon: Icons.check_circle_outline,
                  onPressed: isSupplierVerified ? _confirmCollection : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredNumber(String? value) {
    final number = double.tryParse(value ?? '');
    if (number == null || number < 0) {
      return 'Enter a valid quantity';
    }
    return null;
  }
}

class _VerificationStatus extends StatelessWidget {
  const _VerificationStatus({
    required this.isSupplierVerified,
    required this.scannedSupplierId,
    required this.expectedSupplierId,
  });

  final bool isSupplierVerified;
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
                ? 'Supplier verified: $scannedSupplierId'
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
      formats: const [BarcodeFormat.code128],
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

    final value = capture.barcodes.firstOrNull?.rawValue;
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
                  'Scan Code 128 supplier barcode: SUP001, SUP002, or SUP003',
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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.route_outlined, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Text(supplier.distance),
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
              Text('Expected barcode: ${supplier.id}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanSupplier {
  const _ScanSupplier({
    required this.id,
    required this.name,
    required this.location,
    required this.distance,
  });

  final String id;
  final String name;
  final String location;
  final String distance;
}
