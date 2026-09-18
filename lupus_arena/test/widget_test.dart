import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test Lupus Arena App widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Lupus Arena'),
          ),
        ),
      ),
    );
    expect(find.text('Lupus Arena'), findsOneWidget);
  });
}
