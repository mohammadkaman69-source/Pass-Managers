import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'security/app_lifecycle_manager.dart';
import 'services/app_navigator.dart';

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
    final navigator =
        appNavigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    // تمام صفحات قبلی را حذف می‌کنیم.
    // یعنی HomePage / TreePage / TablePage
    // دیگر روی Stack باقی نمی‌مانند.

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onLoginSuccess: _unlockApp,
        ),
      ),
      (route) => false,
    );

    _lifecycleManager.markResumed();
  }

  void _unlockApp() {
    final navigator =
        appNavigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    // LoginPage فعلی کاملاً حذف می‌شود
    // و HomePage از نو ساخته می‌شود.

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Pass Managers',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: LoginPage(
        onLoginSuccess: _unlockApp,
      ),
    );
  }
}
