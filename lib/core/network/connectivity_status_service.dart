import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for the app's online/offline state in the UI.
///
/// Location sync keeps its own connectivity check for queue flushing; this
/// notifier only drives the status chip and banner so both always agree.
class ConnectivityStatusService extends ChangeNotifier {
  ConnectivityStatusService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Assume online until the first check completes, so the banner does not
  /// flash "offline" on a cold start.
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  bool get isOffline => !_isOnline;

  Future<void> start() async {
    await _sub?.cancel();

    _sub = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('Connectivity: stream error $error');
        }
      },
    );

    await refresh();
  }

  Future<void> refresh() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Connectivity: check failed $error');
      }
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final online =
        results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

    if (online == _isOnline) {
      return;
    }

    _isOnline = online;

    if (kDebugMode) {
      debugPrint('Connectivity: app is ${online ? 'ONLINE' : 'OFFLINE'}');
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
