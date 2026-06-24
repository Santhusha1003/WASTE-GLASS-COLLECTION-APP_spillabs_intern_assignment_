import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_glass_collection_app/screens/scan_screen.dart';

void main() {
  testWidgets('scan screen has no manual barcode override', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanScreen()));

    expect(find.text('Scan & Collect'), findsOneWidget);
    expect(find.text('Scan Barcode'), findsOneWidget);
    expect(find.text('Confirm Collection'), findsOneWidget);
    expect(find.text('Enter Supplier ID Manually'), findsNothing);
    expect(find.text('Use Expected Barcode'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
