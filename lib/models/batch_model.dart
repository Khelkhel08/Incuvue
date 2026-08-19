import 'package:cloud_firestore/cloud_firestore.dart';

class IncubationSchedule {
  final DateTime startDay;
  final DateTime incubationEndDay;
  final DateTime lockdownStartDay;
  final DateTime lockdownEndDay;
  final int incubationEndDayNumber;
  final int lockdownEndDayNumber;
  final bool usingCustomSettings;

  const IncubationSchedule({
    required this.startDay,
    required this.incubationEndDay,
    required this.lockdownStartDay,
    required this.lockdownEndDay,
    required this.incubationEndDayNumber,
    required this.lockdownEndDayNumber,
    required this.usingCustomSettings,
  });
}

class IncubationBatch {
  final String id;
  final String batchNumber;
  final String incubatorId;
  final String startDate;
  final String incubationEndDate;
  final String lockdownStartDate;
  final String lockdownEndDate;
  final int totalEggs;
  final String status;
  final String trayNumber;

  const IncubationBatch({
    required this.id,
    required this.batchNumber,
    required this.incubatorId,
    required this.startDate,
    required this.incubationEndDate,
    required this.lockdownStartDate,
    required this.lockdownEndDate,
    required this.totalEggs,
    required this.status,
    this.trayNumber = '1',
  });

  factory IncubationBatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return IncubationBatch(
      id: doc.id,
      batchNumber: map['batchNumber']?.toString() ?? '',
      incubatorId: map['incubatorId']?.toString() ?? 'incubator_1',
      startDate: map['startDate']?.toString() ?? '',
      incubationEndDate: map['incubationEndDate']?.toString() ?? '',
      lockdownStartDate: map['lockdownStartDate']?.toString() ?? '',
      lockdownEndDate: map['lockdownEndDate']?.toString() ?? '',
      totalEggs: (map['totalEggs'] is num) ? (map['totalEggs'] as num).toInt() : 0,
      status: map['status']?.toString() ?? 'pending',
      trayNumber: map['trayNumber']?.toString() ?? '1',
    );
  }
}
