import 'package:flutter/material.dart';

void main() {
  runApp(const PassManagersApp());
}

class PassManagersApp extends StatelessWidget {
  const PassManagersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pass Managers',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pass Managers'),
        ),
        body: const Center(
          child: Text(
            'Pass Managers Build Test OK',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
