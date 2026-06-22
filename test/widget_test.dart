import 'package:flutter_test/flutter_test.dart';
import 'package:waste_glass_collection_app/main.dart';

void main() {
  testWidgets('shows trip screen as initial screen', (tester) async {
    await tester.pumpWidget(const WasteGlassCollectionApp());

    expect(find.text('Waste Glass Collection'), findsOneWidget);
    expect(find.text("Today's Route"), findsOneWidget);
    expect(find.text('Start Collection'), findsOneWidget);
  });

  testWidgets('navigates to scan screen', (tester) async {
    await tester.pumpWidget(const WasteGlassCollectionApp());

    await tester.tap(find.text('Start Collection'));
    await tester.pumpAndSettle();

    expect(find.text('Scan & Collect'), findsOneWidget);
    expect(find.text('Confirm Collection'), findsOneWidget);
  });
}
