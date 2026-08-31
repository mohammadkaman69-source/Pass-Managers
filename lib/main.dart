import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_page_v4.dart';
import 'screens/login_page.dart';
import 'screens/splash_page.dart';
import 'security/app_lifecycle_manager.dart';
import 'services/app_language.dart';
import 'services/app_navigator.dart';
import 'services/app_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();

  try {
    await AppStorageService.instance.ensureAllFolders();
  } catch (_) {
    // پوشه بعداً هنگام ذخیره ساخته می‌شود
  }

  runApp(const PassManagers());
}

class PassManagers extends StatefulWidget {
  const PassManagers({super.key});

  @override
  State<PassManagers> createState() => _PassManagersState();
}

class _PassManagersState extends State<PassManagers> {
  late final AppLifecycleManager _lifecycleManager;

  @override
  void initState() {
    super.initState();
    AppLanguage.instance.addListener(_onLanguageChanged);
    _lifecycleManager = AppLifecycleManager(onLock: _lockApp);
    _lifecycleManager.start();
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_onLanguageChanged);
    _lifecycleManager.stop();
    super.dispose();
  }

  void _lockApp() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage(onLoginSuccess: _unlockApp)),
      (route) => false,
    );
    _lifecycleManager.markResumed();
  }

  void _unlockApp() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePageV4()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'NexVault',
      locale: AppLanguage.instance.locale,
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: SplashPage(onLoginSuccess: _unlockApp),
    );
  }
}
