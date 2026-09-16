import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/main.dart';
import 'package:lupus_arena/services/locale_provider.dart';

void main() {
  testWidgets('Smoke test Lupus Arena App startup', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: LupusArenaApp(localeProvider: LocaleProvider.instance),
      ),
    );
  });
}
