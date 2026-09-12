// Phase 0 smoke test. Run with the env config passed:
//   flutter test --dart-define-from-file=config/dev.json
import 'package:datingapp/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the Phase 0 placeholder screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ElcarinoApp()));
    await tester.pumpAndSettle();

    expect(find.text('Elcarino'), findsOneWidget);
    expect(find.textContaining('Phase 0 scaffold'), findsOneWidget);
  });
}
