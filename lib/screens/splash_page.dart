import 'dart:async';

import 'package:flutter/material.dart';

import 'login_page.dart';

/// Cold-start splash — high-res logo with smooth scale/fade.
/// Avoids low-bitrate MP4 which caused pixelated edges.
class SplashPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const SplashPage({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _navigated = false;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // کوتاه بعد از انیمیشن به لاگین برو
    _exitTimer = Timer(const Duration(milliseconds: 2200), _goToLogin);
  }

  void _goToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _exitTimer?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => LoginPage(
          onLoginSuccess: widget.onLoginSuccess,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoHeight = (size.shortestSide * 0.28).clamp(120.0, 200.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1220),
              Color(0xFF111827),
              Color(0xFF0B1220),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // پس‌زمینه اختیاری اگر موجود باشد
            Image.asset(
              'assets/splash/splash_background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.35),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fade.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/splash/splash_logo.png',
                  height: logoHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/logo/nexvault_logo.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.lock_outline_rounded,
                      size: logoHeight * 0.55,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
