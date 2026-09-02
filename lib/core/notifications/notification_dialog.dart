import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_coordinator.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_inbox_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_payload.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/domain/entities/stored_notification.dart';
import 'package:intl/intl.dart';

/// Shared notification popup — single item or high-priority ListView.
class NotificationDialog {
  NotificationDialog._();

  static Future<void> show(
    BuildContext context,
    NotificationPayload payload,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(payload.title),
          content: Text(payload.body),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                NotificationCoordinator.dismissDialog();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
              ),
              onPressed: () {
                NotificationCoordinator.confirmOpenJobs(payload);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// ListView of unread high-priority notifications (original tray-tap UX).
  /// Tap a row or OK → mark viewed, close, navigate to Jobs.
  static Future<void> showHighPriorityList(
    BuildContext context,
    List<StoredNotification> items, {
    NotificationInboxService? inboxService,
  }) {
    final inbox = inboxService ?? NotificationInboxService();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            items.length == 1
                ? 'High Priority Alert'
                : 'High Priority Alerts (${items.length})',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    item.createdAtMs,
                  );

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.body),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'dd MMM yyyy, hh:mm a',
                            ).format(date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () async {
                      await inbox.markHighPriorityListRead(items);
                      final payload = NotificationPayload.fromStored(item);
                      NotificationCoordinator.confirmOpenJobs(payload);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await inbox.markHighPriorityListRead(items);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                NotificationCoordinator.dismissDialog();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
              ),
              onPressed: () async {
                await inbox.markHighPriorityListRead(items);
                NotificationCoordinator.confirmOpenJobs();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
