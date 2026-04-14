import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bt_controller.dart';
import 'scan_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BtController(),
      child: const StepperApp(),
    ),
  );
}

class StepperApp extends StatelessWidget {
  const StepperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StepperControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      ),
      home: const ScanScreen(),
    );
  }
}
