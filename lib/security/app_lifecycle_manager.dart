import 'package:flutter/widgets.dart';

import 'security_session.dart';

class AppLifecycleManager
    with WidgetsBindingObserver {
  AppLifecycleManager({
    SecuritySession? securitySession,
  }) : _securitySession =
            securitySession ?? SecuritySession.instance;

  final SecuritySession _securitySession;

  bool _isRegistered = false;

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
    if (state == AppLifecycleState
            .paused ||
        state == AppLifecycleState
            .detached) {
      _securitySession.lock();
    }
  }
}
