import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'security/app_lifecycle_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const PassManagers(),
  );
}

class PassManagers extends StatefulWidget {
  const PassManagers({
    super.key,
  });

  @override
  State<PassManagers> createState() =>
      _PassManagersState();
}

class _PassManagersState
    extends State<PassManagers> {
  late final AppLifecycleManager
      _lifecycleManager;

  bool _isLocked = true;

  @override
  void initState() {
    super.initState();

    _lifecycleManager =
        AppLifecycleManager(
      onLock: _lockApp,
    );

    _lifecycleManager.start();
  }

  @override
  void dispose() {
    _lifecycleManager.stop();
    super.dispose();
  }

  void _lockApp() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLocked = true;
    });
  }

  void _unlockApp() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pass Managers',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: _isLocked
          ? LoginPage(
              onLoginSuccess: _unlockApp,
            )
          : const HomePage(),
    );
  }
}
