import 'package:flutter/widgets.dart';

import 'security_session.dart';

class AppLifecycleManager
    with WidgetsBindingObserver {
  AppLifecycleManager({
    required this.onLock,
    SecuritySession? securitySession,
  }) : _securitySession =
            securitySession ??
                SecuritySession.instance;

  final VoidCallback onLock;

  final SecuritySession _securitySession;

  bool _isRegistered = false;

  bool _lockedForBackground = false;

  void start() {
    if (_isRegistered) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);

    _isRegistered = true;
  }

  void stop() {
    if (!_isRegistered) {
      return;
    }

    WidgetsBinding.instance.removeObserver(this);

    _isRegistered = false;
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lockForBackground();
    }
  }

  void _lockForBackground() {
    if (_lockedForBackground) {
      return;
    }

    _lockedForBackground = true;

    // پاک کردن کلید رمزنگاری از حافظه
    if (_securitySession.isUnlocked) {
      _securitySession.lock();
    }

    // درخواست بازگشت کامل برنامه به Login
    onLock();
  }

  void markResumed() {
    _lockedForBackground = false;
  }
}
