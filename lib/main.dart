
import 'package:flutter/widgets.dart';

import 'app/neuro_simulator_app.dart';
import 'services/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = AppStore();
  await store.open();

  runApp(NeuroSimulatorApp(store: store));
}
