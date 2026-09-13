import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/main.dart';

void main() {
  testWidgets('Smoke test Lupus Arena App startup', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LupusArenaApp(),
      ),
    );
    expect(find.text('LUPUS ARENA'), findsOneWidget);
  });
}
