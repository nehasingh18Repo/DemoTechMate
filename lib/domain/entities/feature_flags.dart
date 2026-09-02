import 'package:equatable/equatable.dart';

/// Feature flags driven by `featureName` + `enabledFlag`.
/// `enabledFlag: true`  → show UI
/// `enabledFlag: false` → hide UI
class FeatureFlags extends Equatable {
  const FeatureFlags({
    this.job = true,
    this.circuitView = true,
    this.myInventory = true,
    this.timesheet = true,
    this.hotReads = true,
    this.map = true,
    this.filterJobs = true,
    this.altJob = true,
    this.selfAssign = true,
    this.refresh = true,
    this.search = true,
    this.jobNotes = true,
    this.jobCv = true,
    this.jobDetails = true,
    this.jobStatus = true,
    this.jobCDD = true,
    this.jobTruckInventory = true,
    this.jobPhone = true,
    this.jobLoction = true,
    this.dashboardTab = true,
    this.jobsTab = true,
  });

  /// All features visible (safe fallback when config fails to load).
  static const allEnabled = FeatureFlags();

  final bool job;
  final bool circuitView;
  final bool myInventory;
  final bool timesheet;
  final bool hotReads;

  final bool map;
  final bool filterJobs;
  final bool altJob;
  final bool selfAssign;
  final bool refresh;
  final bool search;

  final bool jobNotes;
  final bool jobCv;
  final bool jobDetails;
  final bool jobStatus;
  final bool jobCDD;
  final bool jobTruckInventory;
  final bool jobPhone;
  final bool jobLoction;

  final bool dashboardTab;
  final bool jobsTab;

  @override
  List<Object?> get props => [
        job,
        circuitView,
        myInventory,
        timesheet,
        hotReads,
        map,
        filterJobs,
        altJob,
        selfAssign,
        refresh,
        search,
        jobNotes,
        jobCv,
        jobDetails,
        jobStatus,
        jobCDD,
        jobTruckInventory,
        jobPhone,
        jobLoction,
        dashboardTab,
        jobsTab,
      ];

  /// Maps API / JSON `featureName` values to internal camelCase keys.
  static String? normalizeFeatureName(String? rawName) {
    if (rawName == null) {
      return null;
    }
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final compact = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    switch (compact) {
      case 'job':
      case 'job_dashboard':
      case 'jobdashboard':
        return 'job';
      case 'circuit_view':
      case 'circuitview':
        return 'circuitView';
      case 'my_inventory':
      case 'myinventory':
        return 'myInventory';
      case 'timesheet':
      case 'time_sheet':
        return 'timesheet';
      case 'hotreads':
      case 'hot_reads':
        return 'hotReads';
      case 'map':
        return 'map';
      case 'filterjobs':
      case 'filter_jobs':
        return 'filterJobs';
      case 'altjob':
      case 'alt_job':
        return 'altJob';
      case 'selfassign':
      case 'self_assign':
        return 'selfAssign';
      case 'refresh':
        return 'refresh';
      case 'search':
        return 'search';
      case 'jobnotes':
      case 'job_notes':
        return 'jobNotes';
      case 'jobcv':
      case 'job_cv':
        return 'jobCv';
      case 'jobdetails':
      case 'job_details':
        return 'jobDetails';
      case 'jobstatus':
      case 'job_status':
        return 'jobStatus';
      case 'jobcdd':
      case 'job_cdd':
        return 'jobCDD';
      case 'jobtruckinventory':
      case 'job_truck_inventory':
        return 'jobTruckInventory';
      case 'jobphone':
      case 'job_phone':
        return 'jobPhone';
      case 'jobloction':
      case 'job_loction':
      case 'joblocation':
      case 'job_location':
        return 'jobLoction';
      case 'dashboardtab':
      case 'dashboard_tab':
      case 'dashboard':
      case 'beta_dashboard':
      case 'betadashboard':
        return 'dashboardTab';
      case 'jobstab':
      case 'jobs_tab':
      case 'jobs':
        return 'jobsTab';
      default:
        if (_internalKeys.contains(trimmed)) {
          return trimmed;
        }
        return null;
    }
  }

  static const _internalKeys = {
    'job',
    'circuitView',
    'myInventory',
    'timesheet',
    'hotReads',
    'map',
    'filterJobs',
    'altJob',
    'selfAssign',
    'refresh',
    'search',
    'jobNotes',
    'jobCv',
    'jobDetails',
    'jobStatus',
    'jobCDD',
    'jobTruckInventory',
    'jobPhone',
    'jobLoction',
    'dashboardTab',
    'jobsTab',
  };

  static bool? _parseEnabledFlag(dynamic enabled) {
    if (enabled is bool) {
      return enabled;
    }
    if (enabled == null) {
      return null;
    }
    final asString = enabled.toString().trim().toLowerCase();
    if (asString == 'true' || asString == '1' || asString == 'yes') {
      return true;
    }
    if (asString == 'false' || asString == '0' || asString == 'no') {
      return false;
    }
    return null;
  }

  static Map<String, bool> _parseRows(List<dynamic> items) {
    final map = <String, bool>{};

    for (final item in items) {
      if (item is! Map) {
        continue;
      }
      final row = Map<String, dynamic>.from(item);

      final key = normalizeFeatureName(row['featureName']?.toString());
      if (key == null) {
        continue;
      }

      final enabled = _parseEnabledFlag(row['enabledFlag']);
      if (enabled != null) {
        map[key] = enabled;
      }
    }

    return map;
  }

  /// Parses list items using only `featureName` + `enabledFlag`:
  /// - enabledFlag true  → show UI
  /// - enabledFlag false → hide UI
  ///
  /// `userId` / `userName` in JSON are ignored.
  factory FeatureFlags.fromFeatureList(List<dynamic> items) {
    return FeatureFlags.fromFlagMap(_parseRows(items));
  }

  /// Legacy map format: `{ "features": { "job": true, ... } }`
  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    final features = json['features'];
    final Map<String, dynamic> raw = features is Map
        ? Map<String, dynamic>.from(features)
        : json;

    final map = <String, bool>{};
    raw.forEach((key, value) {
      final normalized = normalizeFeatureName(key) ?? key;
      final enabled = _parseEnabledFlag(value);
      if (enabled != null) {
        map[normalized] = enabled;
      }
    });
    return FeatureFlags.fromFlagMap(map);
  }

  factory FeatureFlags.fromFlagMap(Map<String, bool> map) {
    bool flag(String key) {
      // Explicit value from JSON wins. Missing key stays visible (true).
      return map[key] ?? true;
    }

    return FeatureFlags(
      job: flag('job'),
      circuitView: flag('circuitView'),
      myInventory: flag('myInventory'),
      timesheet: flag('timesheet'),
      hotReads: flag('hotReads'),
      map: flag('map'),
      filterJobs: flag('filterJobs'),
      altJob: flag('altJob'),
      selfAssign: flag('selfAssign'),
      refresh: flag('refresh'),
      search: flag('search'),
      jobNotes: flag('jobNotes'),
      jobCv: flag('jobCv'),
      jobDetails: flag('jobDetails'),
      jobStatus: flag('jobStatus'),
      jobCDD: flag('jobCDD'),
      jobTruckInventory: flag('jobTruckInventory'),
      jobPhone: flag('jobPhone'),
      jobLoction: flag('jobLoction'),
      dashboardTab: flag('dashboardTab'),
      jobsTab: flag('jobsTab'),
    );
  }

  bool isEnabled(String key) {
    switch (key) {
      case 'job':
        return job;
      case 'circuitView':
        return circuitView;
      case 'myInventory':
        return myInventory;
      case 'timesheet':
        return timesheet;
      case 'hotReads':
        return hotReads;
      case 'map':
        return map;
      case 'filterJobs':
        return filterJobs;
      case 'altJob':
        return altJob;
      case 'selfAssign':
        return selfAssign;
      case 'refresh':
        return refresh;
      case 'search':
        return search;
      case 'jobNotes':
        return jobNotes;
      case 'jobCv':
        return jobCv;
      case 'jobDetails':
        return jobDetails;
      case 'jobStatus':
        return jobStatus;
      case 'jobCDD':
        return jobCDD;
      case 'jobTruckInventory':
        return jobTruckInventory;
      case 'jobPhone':
        return jobPhone;
      case 'jobLoction':
        return jobLoction;
      case 'dashboardTab':
        return dashboardTab;
      case 'jobsTab':
        return jobsTab;
      default:
        return true;
    }
  }
}
