// Basic smoke test for ASHA Saathi AI app.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AshaSaathiApp()),
    );
    // Just verify the app builds and renders a widget tree.
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
