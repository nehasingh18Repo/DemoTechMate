/// Urgency priority from FCM `data.priority` (high / medium / low).
enum NotificationPriority {
  high,
  medium,
  low;

  bool get isHigh => this == NotificationPriority.high;
  bool get needsPopup => isHigh;
  bool get needsBackgroundTaskUpdate =>
      this == NotificationPriority.medium || this == NotificationPriority.low;

  String get storageValue {
    switch (this) {
      case NotificationPriority.high:
        return 'high';
      case NotificationPriority.medium:
        return 'medium';
      case NotificationPriority.low:
        return 'low';
    }
  }

  static NotificationPriority fromRaw(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      // Missing priority → high so existing pushes still show the popup.
      return NotificationPriority.high;
    }
    if (normalized == 'high' ||
        normalized == 'urgent' ||
        normalized == '1' ||
        normalized == 'p0') {
      return NotificationPriority.high;
    }
    if (normalized == 'medium' ||
        normalized == 'med' ||
        normalized == 'normal' ||
        normalized == '2' ||
        normalized == 'p1') {
      return NotificationPriority.medium;
    }
    if (normalized == 'low' ||
        normalized == '3' ||
        normalized == 'p2') {
      return NotificationPriority.low;
    }
    return NotificationPriority.high;
  }

  static NotificationPriority fromStorage(String? value) => fromRaw(value);
}
