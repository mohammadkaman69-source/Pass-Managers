import 'package:flutter/material.dart';

import 'security_session.dart';
import '../screens/home_page_v4.dart';
import '../screens/login_page.dart';

class SecurityGuard extends StatefulWidget {
  final Widget child;

  const SecurityGuard({
    super.key,
    required this.child,
  });

  @override
  State<SecurityGuard> createState() => _SecurityGuardState();
}

class _SecurityGuardState extends State<SecurityGuard> {
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkSecurity();
  }

  void _onLoginSuccess() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePageV4()),
      (route) => false,
    );
  }

  void _checkSecurity() {
    if (_redirecting) {
      return;
    }

    final session = SecuritySession.instance;

    if (session.isUnlocked) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _redirecting) {
        return;
      }

      final currentRoute = ModalRoute.of(context);

      if (currentRoute == null) {
        return;
      }

      _redirecting = true;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(onLoginSuccess: _onLoginSuccess),
        ),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SecuritySession.instance;

    if (!session.isUnlocked) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return widget.child;
  }
}
