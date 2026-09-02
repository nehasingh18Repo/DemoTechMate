/// Maps between API status codes and user-facing labels.
///
/// Canonical job statuses:
/// ACCEPTED, ASSIGNED, EN_ROUTE, ON_SITE, COMPLETE, PAUSE, NON_COMPLETE
class JobStatusMapper {
  JobStatusMapper._();

  /// Labels shown in the status picker (same order as API enum).
  static const List<String> pickerLabels = [
    'Accepted',
    'Assigned',
    'En Route',
    'On Site',
    'Complete',
    'Pause',
    'Non Complete',
  ];

  /// API values sent in PATCH /api/jobs/{jobId}.
  static const List<String> apiValues = [
    'ACCEPTED',
    'ASSIGNED',
    'EN_ROUTE',
    'ON_SITE',
    'COMPLETE',
    'PAUSE',
    'NON_COMPLETE',
  ];

  static String toDisplay(String? apiStatus) {
    if (apiStatus == null || apiStatus.trim().isEmpty) {
      return 'NA';
    }
    final normalized = apiStatus.trim().toUpperCase().replaceAll(' ', '_');
    const map = {
      'ACCEPTED': 'Accepted',
      'ASSIGNED': 'Assigned',
      'EN_ROUTE': 'En Route',
      'ON_SITE': 'On Site',
      'COMPLETE': 'Complete',
      'COMPLETED': 'Complete', // legacy alias
      'PAUSE': 'Pause',
      'PAUSED': 'Pause', // legacy alias
      'NON_COMPLETE': 'Non Complete',
      'NONCOMPLETE': 'Non Complete',
      // Older app values → closest new status
      'PENDING': 'Assigned',
      'IN_PROGRESS': 'On Site',
      'DONE': 'Complete',
      'CANCELLED': 'Non Complete',
      'CANCELED': 'Non Complete',
    };
    return map[normalized] ?? _titleCaseFromApi(normalized);
  }

  static String toApi(String displayLabel) {
    final normalized = displayLabel.trim().toLowerCase();
    const map = {
      'accepted': 'ACCEPTED',
      'assigned': 'ASSIGNED',
      'en route': 'EN_ROUTE',
      'en_route': 'EN_ROUTE',
      'on site': 'ON_SITE',
      'on_site': 'ON_SITE',
      'complete': 'COMPLETE',
      'completed': 'COMPLETE',
      'pause': 'PAUSE',
      'paused': 'PAUSE',
      'non complete': 'NON_COMPLETE',
      'non_complete': 'NON_COMPLETE',
      // Older UI labels
      'pending': 'ASSIGNED',
      'in progress': 'ON_SITE',
      'done': 'COMPLETE',
      'cancelled': 'NON_COMPLETE',
      'canceled': 'NON_COMPLETE',
    };
    return map[normalized] ??
        displayLabel.trim().toUpperCase().replaceAll(' ', '_');
  }

  static String _titleCaseFromApi(String normalized) {
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
