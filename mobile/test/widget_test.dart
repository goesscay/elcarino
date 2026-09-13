// Phase 0 smoke test, now exercising the real boot path added in Phase 1's
// Onboarding feature: Splash -> AuthController resolves "not signed in" ->
// Welcome. Run with the env config passed:
//   flutter test --dart-define-from-file=config/dev.json
import 'package:datingapp/app.dart';
import 'package:datingapp/core/auth/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_token_storage.dart';

void main() {
  testWidgets('an unauthenticated user boots to the Welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStorageProvider.overrideWithValue(FakeTokenStorage())],
        child: const ElcarinoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
