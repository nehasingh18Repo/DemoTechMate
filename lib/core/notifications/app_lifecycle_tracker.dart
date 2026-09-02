import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:brightspeed_fiber_app/core/notifications/pending_alert_gate.dart';

/// Tracks [AppLifecycleState] so FCM can treat inactive / paused like
/// background for status-specific notification sounds.
class AppLifecycleTracker with WidgetsBindingObserver {
  AppLifecycleTracker._();

  static final AppLifecycleTracker instance = AppLifecycleTracker._();

  AppLifecycleState _state = AppLifecycleState.resumed;
  bool _observing = false;
  VoidCallback? _onResumed;

  AppLifecycleState get state => _state;

  /// True when the UI is fully interactive (normal foreground).
  bool get isActiveForeground => _state == AppLifecycleState.resumed;

  /// True when the process is visible or transitioning but not interactive
  /// (notification shade, app switcher, incoming call UI, etc.).
  bool get isInactiveOrBackground =>
      _state == AppLifecycleState.inactive ||
      _state == AppLifecycleState.paused ||
      _state == AppLifecycleState.hidden ||
      _state == AppLifecycleState.detached;

  void start({VoidCallback? onResumed}) {
    _onResumed = onResumed;
    if (_observing) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _state = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _observing = true;
    if (kDebugMode) {
      debugPrint('AppLifecycleTracker started: $_state');
    }
  }

  void stop() {
    if (!_observing) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    _onResumed = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _state;
    _state = state;
    if (kDebugMode) {
      debugPrint('AppLifecycle: $previous → $state');
    }

    // Persist when the user leaves the app so the 5-minute alert gate works.
    final leftApp = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (leftApp &&
        (previous == AppLifecycleState.resumed ||
            previous == AppLifecycleState.inactive)) {
      PendingAlertGate.markWentToBackground();
    }

    if (state == AppLifecycleState.resumed &&
        previous != AppLifecycleState.resumed) {
      _onResumed?.call();
    }
  }
}
