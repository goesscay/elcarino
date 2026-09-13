import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'notifications/data/push_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail loud at startup if the env config file wasn't passed.
  AppConfig.current;

  // Before runApp so every later Firebase call can assume this already
  // ran, rather than racing it — see the function's own doc comment.
  await initializeFirebaseIfConfigured();

  runApp(const ProviderScope(child: ElcarinoApp()));
}
