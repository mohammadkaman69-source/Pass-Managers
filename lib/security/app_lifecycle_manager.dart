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

  /// وقتی انتخابگر فایل سیستم باز است، قفل پس‌زمینه موقتاً خاموش می‌شود.
  static int _suppressBackgroundLock = 0;

  static void beginExternalUi() {
    _suppressBackgroundLock++;
  }

  static void endExternalUi() {
    if (_suppressBackgroundLock > 0) {
      _suppressBackgroundLock--;
    }
  }

  static bool get isExternalUiActive =>
      _suppressBackgroundLock > 0;

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
    if (_suppressBackgroundLock > 0) {
      // انتخابگر فایل / ذخیره سیستم — قفل نکن
      return;
    }

    if (_lockedForBackground) {
      return;
    }

    _lockedForBackground = true;

    if (_securitySession.isUnlocked) {
      _securitySession.lock();
    }

    onLock();
  }

  void markResumed() {
    _lockedForBackground = false;
  }
}
