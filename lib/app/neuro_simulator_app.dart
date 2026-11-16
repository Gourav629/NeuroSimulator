
import 'package:flutter/material.dart';

import '../services/app_store.dart';
import 'app_gate.dart';

class NeuroSimulatorApp extends StatelessWidget {
  const NeuroSimulatorApp({
    super.key,
    required this.store,
  });

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neuro Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58D6B0),
          brightness: Brightness.dark,
          surface: const Color(0xFF151D27),
        ),
        scaffoldBackgroundColor: const Color(0xFF0C121A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C121A),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151D27),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF293542),
            ),
          ),
        ),
      ),
      home: AppGate(store: store),
    );
  }
}
