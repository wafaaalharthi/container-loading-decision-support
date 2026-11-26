import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.open();
  final state = AppState();
  await state.load();
  runApp(SeniorProjectApp(state: state));
}
