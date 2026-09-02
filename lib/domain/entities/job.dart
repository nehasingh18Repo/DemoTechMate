import 'package:equatable/equatable.dart';

class Job extends Equatable {
  const Job({
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
    required this.assignedBy,
    required this.technicianName,
    this.version = 1,
  });

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
  final String assignedBy;
  final String technicianName;
  final int version;

  Job copyWith({String? status, int? version}) {
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
      status: status ?? this.status,
      brand: brand,
      speed: speed,
      assignedBy: assignedBy,
      technicianName: technicianName,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        index,
        total,
        phone,
        address,
        serviceType,
        orderNumber,
        techServiceAction,
        jobId,
        jobTimeframe,
        dueDate,
        circuitId,
        dispatchJobType,
        migratingFrom,
        dispatchTask,
        status,
        brand,
        speed,
        assignedBy,
        technicianName,
        version,
      ];
}
