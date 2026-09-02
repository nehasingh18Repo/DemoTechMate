/// Resolves which notification beep to play for an FCM / local alert.
///
/// Android raw resource names (no extension):
/// - pending_sound
/// - assigned_sound
/// - completed_sound
/// - wifi_installation_sound
///
/// iOS bundle file names include the `.mp3` extension.
enum NotificationSoundKind {
  pending,
  assigned,
  completed,
  wifiInstallation,
  systemDefault,
}

class NotificationSound {
  NotificationSound._();

  static const String pendingFile = 'pending_sound';
  static const String assignedFile = 'assigned_sound';
  static const String completedFile = 'completed_sound';
  static const String wifiInstallationFile = 'wifi_installation_sound';

  /// Android notification channel ids (sound is locked to the channel).
  ///
  /// FCM default channel (HIGH) so Android can show an immediate banner.
  /// Status beeps use pending / assigned / completed / wifi `_v4` channels.
  static const String defaultChannelId = 'techx_jobs_fcm_visible_v4';
  static const String legacyDefaultChannelId = 'techx_jobs_heads_up';
  static const String silentRelayChannelId = 'techx_jobs_fcm_relay';
  static const String pendingChannelId = 'techx_jobs_pending_v4';
  static const String assignedChannelId = 'techx_jobs_assigned_v4';
  static const String completedChannelId = 'techx_jobs_completed_v4';
  static const String wifiChannelId = 'techx_jobs_wifi_installation_v4';

  static const List<String> legacyStatusChannelIds = [
    'techx_jobs_pending',
    'techx_jobs_assigned',
    'techx_jobs_completed',
    'techx_jobs_wifi_installation',
    'techx_jobs_pending_v2',
    'techx_jobs_assigned_v2',
    'techx_jobs_completed_v2',
    'techx_jobs_wifi_installation_v2',
    'techx_jobs_pending_v3',
    'techx_jobs_assigned_v3',
    'techx_jobs_completed_v3',
    'techx_jobs_wifi_installation_v3',
    silentRelayChannelId,
  ];

  /// Picks sound from FCM data fields.
  ///
  /// Priority:
  /// 1. Explicit `sound` key (when it matches a known file)
  /// 2. WiFi Installation type / service
  /// 3. Job status (Accepted / Assigned / En Route / On Site / Complete / …)
  /// 4. Missing / unknown / default status → Pending sound
  static NotificationSoundKind resolve({
    String? status,
    String? type,
    String? sound,
  }) {
    final explicit = _fromSoundName(sound);
    if (explicit != null) {
      return explicit;
    }

    if (_isWifiInstallation(type) || _isWifiInstallation(status)) {
      return NotificationSoundKind.wifiInstallation;
    }

    final normalizedStatus = _normalize(status);
    if (normalizedStatus == null ||
        normalizedStatus == 'DEFAULT' ||
        normalizedStatus == 'DEFAULT_STATUS') {
      return NotificationSoundKind.pending;
    }

    if (normalizedStatus == 'ASSIGNED' ||
        normalizedStatus == 'ACCEPTED' ||
        normalizedStatus == 'EN_ROUTE' ||
        normalizedStatus == 'ON_SITE' ||
        normalizedStatus == 'PAUSE' ||
        normalizedStatus == 'PAUSED' ||
        normalizedStatus == 'DISPATCHED' ||
        normalizedStatus == 'IN_PROGRESS' ||
        normalizedStatus == 'PENDING') {
      return NotificationSoundKind.assigned;
    }
    if (normalizedStatus == 'COMPLETE' ||
        normalizedStatus == 'COMPLETED' ||
        normalizedStatus == 'DONE') {
      return NotificationSoundKind.completed;
    }
    if (normalizedStatus == 'NON_COMPLETE' ||
        normalizedStatus == 'NONCOMPLETE') {
      return NotificationSoundKind.pending;
    }

    // Unknown status → same as Pending.
    return NotificationSoundKind.pending;
  }

  static String channelId(NotificationSoundKind kind) {
    switch (kind) {
      case NotificationSoundKind.pending:
        return pendingChannelId;
      case NotificationSoundKind.assigned:
        return assignedChannelId;
      case NotificationSoundKind.completed:
        return completedChannelId;
      case NotificationSoundKind.wifiInstallation:
        return wifiChannelId;
      case NotificationSoundKind.systemDefault:
        return defaultChannelId;
    }
  }

  static String channelName(NotificationSoundKind kind) {
    switch (kind) {
      case NotificationSoundKind.pending:
        return 'Pending Job Alerts';
      case NotificationSoundKind.assigned:
        return 'Assigned Job Alerts';
      case NotificationSoundKind.completed:
        return 'Completed Job Alerts';
      case NotificationSoundKind.wifiInstallation:
        return 'WiFi Installation Alerts';
      case NotificationSoundKind.systemDefault:
        return 'Job Alerts';
    }
  }

  /// Android `res/raw` resource name (no extension), or null for default.
  static String? androidRawName(NotificationSoundKind kind) {
    switch (kind) {
      case NotificationSoundKind.pending:
        return pendingFile;
      case NotificationSoundKind.assigned:
        return assignedFile;
      case NotificationSoundKind.completed:
        return completedFile;
      case NotificationSoundKind.wifiInstallation:
        return wifiInstallationFile;
      case NotificationSoundKind.systemDefault:
        return null;
    }
  }

  /// iOS notification sound file name (with extension), or null for default.
  static String? iosSoundFile(NotificationSoundKind kind) {
    final raw = androidRawName(kind);
    return raw == null ? null : '$raw.mp3';
  }

  static NotificationSoundKind? _fromSoundName(String? sound) {
    final normalized = _normalize(sound);
    if (normalized == null) {
      return null;
    }

    // Strip common extensions / path noise.
    final name = normalized
        .replaceAll('.MP3', '')
        .replaceAll('.WAV', '')
        .replaceAll('.CAF', '');

    if (name == 'PENDING_SOUND' || name == 'PENDING') {
      return NotificationSoundKind.pending;
    }
    if (name == 'ASSIGNED_SOUND' || name == 'ASSIGNED') {
      return NotificationSoundKind.assigned;
    }
    if (name == 'COMPLETED_SOUND' || name == 'COMPLETED') {
      return NotificationSoundKind.completed;
    }
    if (name == 'WIFI_INSTALLATION_SOUND' ||
        name == 'WIFI_INSTALLATION' ||
        name == 'WIFI_SOUND') {
      return NotificationSoundKind.wifiInstallation;
    }
    if (name == 'DEFAULT' || name == 'DEFAULT_SOUND') {
      // Default maps to Pending beep.
      return NotificationSoundKind.pending;
    }
    return null;
  }

  static bool _isWifiInstallation(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return false;
    }
    return normalized.contains('WIFI') && normalized.contains('INSTALL');
  }

  static String? _normalize(String? value) {
    if (value == null) {
      return null;
    }
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    return text
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .replaceAll('/', '_');
  }
}
