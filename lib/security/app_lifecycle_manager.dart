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

  bool _wasInBackground = false;

  void start() {
    if (_isRegistered) {
      return;
    }

    WidgetsBinding.instance
        .addObserver(this);

    _isRegistered = true;
  }

  void stop() {
    if (!_isRegistered) {
      return;
    }

    WidgetsBinding.instance
        .removeObserver(this);

    _isRegistered = false;
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_securitySession.isUnlocked) {
          _securitySession.lock();
          _wasInBackground = true;
        }
        break;

      case AppLifecycleState.resumed:
        if (_wasInBackground) {
          _wasInBackground = false;

          onLock();
        }
        break;

      case AppLifecycleState.hidden:
        if (_securitySession.isUnlocked) {
          _securitySession.lock();
          _wasInBackground = true;
        }
        break;
    }
  }
}
