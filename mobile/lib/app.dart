import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'notifications/presentation/notification_tap_gate.dart';

class ElcarinoApp extends ConsumerWidget {
  const ElcarinoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Elcarino',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // dark mode is required — docs/07 §4.1
      routerConfig: router,
      // `builder`'s context is a descendant of the Router/ScaffoldMessenger
      // MaterialApp sets up internally, so NotificationTapGate can use it
      // for both go_router navigation and SnackBars (Phase 1 item 9).
      builder: (context, child) =>
          NotificationTapGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
