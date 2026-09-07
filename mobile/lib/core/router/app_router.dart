import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../placeholder_home.dart';

/// App router. Phase 0 has a single placeholder route. Real routes (onboarding,
/// main tab shell, feature screens) land feature-by-feature in Phase 1, per the
/// navigation map in `docs/07-ui-ux-design.md` §2.2.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const PlaceholderHome()),
    ],
  );
});
