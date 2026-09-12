import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

void main() {
  // Fail loud at startup if the env config file wasn't passed.
  AppConfig.current;

  runApp(const ProviderScope(child: ElcarinoApp()));
}
