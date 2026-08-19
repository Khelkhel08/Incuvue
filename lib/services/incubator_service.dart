import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/incubator_model.dart';

class IncubatorService {
  final FirebaseFirestore _firestore;
  static const String _incubatorId = 'incubator_1';

  IncubatorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<IncubatorData> watchIncubator() {
    return _firestore
        .collection('incubators')
        .doc(_incubatorId)
        .snapshots()
        .map((snap) => IncubatorData.fromMap(snap.data() ?? {}));
  }

  Future<void> updateField(String field, dynamic value) {
    return _firestore.collection('incubators').doc(_incubatorId).update({field: value});
  }

  Future<void> updateFields(Map<String, dynamic> fields) {
    return _firestore.collection('incubators').doc(_incubatorId).update(fields);
  }

  Future<void> startBatch() {
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return updateFields({
      'startDate': dateStr,
      'isActive': true,
      'turningActive': true,
      'heaterEnabled': true,
      'fanEnabled': true,
      'fanCircEnabled': true,
      'fanVentEnabled': true,
      'eggTurner': true,
      'targetTemperature': 37.5,
      'targetHumidity': 55,
      'hatchCount': 0,
      'controlMode': 'auto',
    });
  }

  Future<void> setControlMode(String mode) {
    if (mode == 'auto') {
      return updateFields({
        'controlMode': 'auto',
        'heaterEnabled': true,
        'fanEnabled': true,
        'fanCircEnabled': true,
        'fanVentEnabled': true,
        'eggTurner': true,
        'turningActive': true,
      });
    }
    return updateField('controlMode', 'manual');
  }

  Future<void> closeBatch() {
    return updateFields({
      'totalEggs': 0,
      'startDate': '',
      'hatchCount': 0,
      'isActive': false,
      'turningActive': false,
      'eggTurner': false,
      'heaterEnabled': false,
      'fanEnabled': false,
      'fanCircEnabled': false,
      'fanVentEnabled': false,
      'turningInterval': 4,
      'cameraOnline': false,
    });
  }
}
