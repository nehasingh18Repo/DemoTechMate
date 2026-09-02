import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/navigation/app_navigator_key.dart';
import 'package:brightspeed_fiber_app/core/notifications/app_lifecycle_tracker.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_coordinator.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_dialog.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_inbox_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';

/// Listens for pending FCM payloads / high-priority lists and shows dialogs
/// once a navigator Overlay is available and the app is active.
class NotificationDialogHost extends StatefulWidget {
  const NotificationDialogHost({
    super.key,
    required this.child,
    this.inboxService,
  });

  final Widget child;
  final NotificationInboxService? inboxService;

  @override
  State<NotificationDialogHost> createState() => _NotificationDialogHostState();
}

class _NotificationDialogHostState extends State<NotificationDialogHost>
    with WidgetsBindingObserver {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationCoordinator.pendingDialog.addListener(_onPendingChanged);
    NotificationCoordinator.pendingHighPriorityList
        .addListener(_onPendingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingChanged());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationCoordinator.pendingDialog.removeListener(_onPendingChanged);
    NotificationCoordinator.pendingHighPriorityList
        .removeListener(_onPendingChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check inbox on resume only for true manual opens (not tray taps).
      final inbox = widget.inboxService;
      if (inbox != null &&
          !inbox.openedFromNotificationTap &&
          !NotificationCoordinator.isDialogVisible) {
        inbox.presentUnreadHighPriorityOnManualOpen().then((_) => _onPendingChanged());
      } else {
        _onPendingChanged();
      }
    }
  }

  void _onPendingChanged() {
    if (_showing) {
      return;
    }
    if (AppLifecycleTracker.instance.isInactiveOrBackground) {
      return;
    }

    final highList = NotificationCoordinator.pendingHighPriorityList.value;
    if (highList != null && highList.isNotEmpty) {
      _showHighList(highList);
      return;
    }

    final payload = NotificationCoordinator.pendingDialog.value;
    if (payload != null) {
      _showSingle(payload);
    }
  }

  Future<void> _showHighList(List<StoredNotification> items) async {
    _showing = true;
    for (var attempt = 0; attempt < 10; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } else {
        await Future<void>.delayed(Duration.zero);
        await WidgetsBinding.instance.endOfFrame;
      }

      if (AppLifecycleTracker.instance.isInactiveOrBackground) {
        NotificationCoordinator.dismissDialog();
        _showing = false;
        return;
      }

      final navContext = appNavigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        final navigator = Navigator.maybeOf(navContext, rootNavigator: true);
        if (navigator != null && navigator.mounted) {
          await NotificationDialog.showHighPriorityList(
            navContext,
            items,
            inboxService: widget.inboxService,
          );
          _showing = false;
          return;
        }
      }
    }
    // Failed to present — clear the pending flag so a later resume can retry.
    NotificationCoordinator.dismissDialog();
    _showing = false;
  }

  Future<void> _showSingle(NotificationPayload payload) async {
    _showing = true;
    for (var attempt = 0; attempt < 10; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } else {
        await Future<void>.delayed(Duration.zero);
        await WidgetsBinding.instance.endOfFrame;
      }

      if (AppLifecycleTracker.instance.isInactiveOrBackground) {
        NotificationCoordinator.dismissDialog();
        _showing = false;
        return;
      }

      final navContext = appNavigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        final navigator = Navigator.maybeOf(navContext, rootNavigator: true);
        if (navigator != null && navigator.mounted) {
          await NotificationDialog.show(navContext, payload);
          _showing = false;
          return;
        }
      }
    }
    NotificationCoordinator.dismissDialog();
    _showing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
