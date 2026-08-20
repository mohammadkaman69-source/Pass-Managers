import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'login_page.dart';

/// Cold-start splash. Uses splash_background, splash_logo, and optional
/// logo animation. Pure UI — does not touch security or data layers.
class SplashPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const SplashPage({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
    // Always leave splash after a short delay so the app never sticks here.
    _fallbackTimer = Timer(const Duration(milliseconds: 2800), _goToLogin);
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        'assets/animation/nexvault_logo_animation.mp4',
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.setLooping(false);
      controller.setVolume(0);
      await controller.play();
      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
      controller.addListener(() {
        final v = _videoController;
        if (v != null &&
            v.value.isInitialized &&
            v.value.position >= v.value.duration &&
            v.value.duration > Duration.zero) {
          _goToLogin();
        }
      });
    } catch (_) {
      // Animation optional — static splash logo is enough.
    }
  }

  void _goToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onLoginSuccess: widget.onLoginSuccess,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Splash background
          Image.asset(
            'assets/splash/splash_background.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF0B1220),
            ),
          ),
          // Center: video if ready, else static splash logo
          Center(
            child: _videoReady && _videoController != null
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio == 0
                        ? 1
                        : _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : Image.asset(
                    'assets/splash/splash_logo.png',
                    height: 160,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/logo/nexvault_logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.lock_outline,
                        size: 72,
                        color: Colors.white70,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
