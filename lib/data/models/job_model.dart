import 'package:brightspeed_fiber_app/core/utils/job_status_mapper.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';

class JobModel {
  const JobModel({
    required this.id,
    required this.name,
    required this.description,
    required this.index,
    required this.total,
    required this.phone,
    required this.address,
    required this.serviceType,
    required this.orderNumber,
    required this.techServiceAction,
    required this.jobId,
    required this.jobTimeframe,
    required this.dueDate,
    required this.circuitId,
    required this.dispatchJobType,
    required this.migratingFrom,
    required this.dispatchTask,
    required this.status,
    required this.brand,
    required this.speed,
    required this.technicianName,
    required this.assignedByName,
    required this.version,
  });

  /// Numeric id used in PATCH /api/jobs/{jobId}.
  final int id;
  final String name;
  final String description;
  final int index;
  final int total;
  final String phone;
  final String address;
  final String serviceType;
  final String orderNumber;
  final String techServiceAction;
  final String jobId;
  final String jobTimeframe;
  final String dueDate;
  final String circuitId;
  final String dispatchJobType;
  final String migratingFrom;
  final String dispatchTask;
  final String status;
  final String brand;
  final String speed;
  final String technicianName;
  final String assignedByName;
  final int version;

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final parsedId = parseApiJobId(json);
    final displayJobId = parseDisplayJobId(json);

    return JobModel(
      id: parsedId,
      name: _str(json['name'] ?? json['title']),
      description: _str(json['description']),
      index: (json['index'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      phone: _str(json['phone']),
      address: _str(json['address']),
      serviceType: _str(json['serviceType']),
      orderNumber: _str(json['orderNumber'] ?? json['orderId']),
      techServiceAction: _str(json['techServiceAction']),
      jobId: displayJobId,
      jobTimeframe: _str(json['jobTimeframe'] ?? json['timeFrame']),
      dueDate: _str(json['dueDate']),
      circuitId: _str(json['circuitId']),
      dispatchJobType: _str(json['dispatchJobType']),
      migratingFrom: _str(json['migratingFrom']),
      dispatchTask: _str(json['dispatchTask']),
      status: _str(json['status']),
      brand: _str(json['brand']),
      speed: _str(json['speed']),
      technicianName: _str(json['technicianName']),
      assignedByName: _str(json['assignedByName'] ?? json['assignedBy']),
      version: _version(json['version']),
    );
  }

  /// Numeric id used as the DB/outbox key and in PATCH /api/jobs/{jobId}.
  ///
  /// Prefer a parseable numeric [jobId] from the API. When [jobId] is a display
  /// string (e.g. WOT3004127), fall back to numeric [id] / [job_id].
  static int parseApiJobId(Map<String, dynamic> json) {
    final fromJobId = _parseNumeric(json['jobId']);
    final fromId = _parseNumeric(json['id']);
    final fromSnake = _parseNumeric(json['job_id']);

    if (fromJobId > 0 && (fromId == 0 || _isNumericValue(json['jobId']))) {
      return fromJobId;
    }
    if (fromId > 0) {
      return fromId;
    }
    if (fromSnake > 0) {
      return fromSnake;
    }
    return 0;
  }

  /// Human-readable job id shown on the card (may differ from [parseApiJobId]).
  static String parseDisplayJobId(Map<String, dynamic> json) {
    final display = _str(json['displayJobId']);
    if (display.isNotEmpty) {
      return display;
    }
    final rawJobId = json['jobId'];
    if (rawJobId != null && !_isNumericValue(rawJobId)) {
      return _str(rawJobId);
    }
    final apiId = parseApiJobId(json);
    if (apiId > 0) {
      return apiId.toString();
    }
    return _str(json['id']);
  }

  static bool _isNumericValue(dynamic value) {
    return switch (value) {
      final num _ => true,
      final String s => int.tryParse(s.trim()) != null,
      _ => false,
    };
  }

  /// Assigns Job: 1/N, 2/N, ... based on list order.
  static List<JobModel> withCardNumbers(List<JobModel> jobs) {
    final total = jobs.length;
    return [
      for (var i = 0; i < jobs.length; i++)
        jobs[i]._withNumbers(index: i + 1, total: total),
    ];
  }

  JobModel _withNumbers({required int index, required int total}) {
    return JobModel(
      id: id,
      name: name,
      description: description,
      index: index,
      total: total,
      phone: phone,
      address: address,
      serviceType: serviceType,
      orderNumber: orderNumber,
      techServiceAction: techServiceAction,
      jobId: jobId,
      jobTimeframe: jobTimeframe,
      dueDate: dueDate,
      circuitId: circuitId,
      dispatchJobType: dispatchJobType,
      migratingFrom: migratingFrom,
      dispatchTask: dispatchTask,
      status: status,
      brand: brand,
      speed: speed,
      technicianName: technicianName,
      assignedByName: assignedByName,
      version: version,
    );
  }

  static String _str(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text == 'null') return '';
    return text;
  }

  static int _parseNumeric(dynamic value) {
    return switch (value) {
      final num n => n.toInt(),
      final String s => int.tryParse(s.trim()) ?? 0,
      _ => 0,
    };
  }

  static int _int(dynamic value) {
    return _parseNumeric(value);
  }

  /// Jobs API `version`. Missing / invalid values default to 1.
  static int _version(dynamic value) {
    final parsed = _int(value);
    return parsed < 1 ? 1 : parsed;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': id,
      'displayJobId': jobId,
      'name': name,
      'description': description,
      'index': index,
      'total': total,
      'phone': phone,
      'address': address,
      'serviceType': serviceType,
      'orderNumber': orderNumber,
      'techServiceAction': techServiceAction,
      'jobTimeframe': jobTimeframe,
      'dueDate': dueDate,
      'circuitId': circuitId,
      'dispatchJobType': dispatchJobType,
      'migratingFrom': migratingFrom,
      'dispatchTask': dispatchTask,
      'status': status,
      'brand': brand,
      'speed': speed,
      'technicianName': technicianName,
      'assignedByName': assignedByName,
      'version': version,
    };
  }

  Job toEntity() {
    return Job(
      id: id,
      name: name,
      description: description,
      index: index,
      total: total,
      phone: phone,
      address: address,
      serviceType: serviceType,
      orderNumber: orderNumber,
      techServiceAction: techServiceAction,
      jobId: jobId,
      jobTimeframe: jobTimeframe,
      dueDate: dueDate,
      circuitId: circuitId,
      dispatchJobType: dispatchJobType,
      migratingFrom: migratingFrom,
      dispatchTask: dispatchTask,
      status: JobStatusMapper.toDisplay(status),
      brand: brand,
      speed: speed,
      assignedBy: assignedByName,
      technicianName: technicianName,
      version: version,
    );
  }
}
