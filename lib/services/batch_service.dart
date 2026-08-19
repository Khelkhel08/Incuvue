import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/incubator_model.dart';

class BatchService {
  final FirebaseFirestore _firestore;
  static const String incubatorId = 'incubator_1';

  BatchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _batches =>
      _firestore.collection('incubation_batches');

  DocumentReference<Map<String, dynamic>> get _incubatorRef =>
      _firestore.collection('incubators').doc(incubatorId);

  static String toIsoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String friendlyError(Object error) {
    if (error is StateError && error.message == 'not-signed-in') {
      return 'Please log in again to start incubation.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Unable to start incubation. Please check your account connection and try again.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Unable to reach the incubator service. Check your connection and try again.';
        case 'not-found':
          return 'Incubator data was not found. Please try again.';
        default:
          return 'Unable to start incubation. Please try again.';
      }
    }
    return 'Unable to start incubation. Please try again.';
  }

  Future<String> startIncubation({
    required IncubatorData data,
    required int currentDay,
    int? incubationStartDay,
    int? incubationEndDay,
    int? lockdownStartDay,
    int? lockdownEndDay,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('AUTH USER: ${user?.email}');
    debugPrint('AUTH UID: ${user?.uid}');

    if (user == null) {
      throw StateError('not-signed-in');
    }
    if (data.isActive) {
      throw StateError('An incubation is already active.');
    }

    final startDay = incubationStartDay ??
        (data.incubationStartDay > 0 ? data.incubationStartDay : 1);
    final incubationEnd = incubationEndDay ??
        (data.incubationEndDay > 0 ? data.incubationEndDay : 18);
    final lockdownStart = lockdownStartDay ??
        (data.lockdownStartDay > 0 ? data.lockdownStartDay : incubationEnd);
    final lockdownEnd = lockdownEndDay ??
        (data.lockdownEndDay > 0 ? data.lockdownEndDay : 21);
    final nextNumber = data.lastBatchNumber + 1;
    final year = DateTime.now().year;
    final batchNumber = 'BATCH-$year-${nextNumber.toString().padLeft(3, '0')}';
    final now = FieldValue.serverTimestamp();

    await _incubatorRef.set({
      'isActive': true,
      'currentDay': currentDay,
      'incubationStartDay': startDay,
      'incubationEndDay': incubationEnd,
      'lockdownStartDay': lockdownStart,
      'lockdownEndDay': lockdownEnd,
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
      'lastBatchNumber': nextNumber,
      'currentBatchNumber': batchNumber,
      'currentTrayNumber': '1',
      'startDate': toIsoDate(DateTime.now()),
      'updatedAt': now,
    }, SetOptions(merge: true));

    try {
      final batchRef = await _batches.add({
        'batchNumber': batchNumber,
        'incubatorId': incubatorId,
        'currentDay': currentDay,
        'incubationStartDay': startDay,
        'incubationEndDay': incubationEnd,
        'lockdownStartDay': lockdownStart,
        'lockdownEndDay': lockdownEnd,
        'totalEggs': data.totalEggs,
        'status': 'active',
        'trayNumber': '1',
        'createdAt': now,
        'confirmedAt': now,
      });
      await _incubatorRef.set({
        'currentBatchId': batchRef.id,
      }, SetOptions(merge: true));
      await _firestore.collection('egg_trays').doc('${batchNumber}_tray1').set({
        'batchNumber': batchNumber,
        'incubatorId': incubatorId,
        'trayNumber': '1',
        'totalEggs': data.totalEggs,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Optional batch history write skipped: $error');
    }

    return batchNumber;
  }

  Future<void> cancelIncubation(IncubatorData data) async {
    final now = FieldValue.serverTimestamp();
    await _incubatorRef.set({
      'isActive': false,
      'turningActive': false,
      'eggTurner': false,
      'heaterEnabled': false,
      'fanEnabled': false,
      'fanCircEnabled': false,
      'fanVentEnabled': false,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final batchId = data.currentBatchId;
    if (batchId.isEmpty) return;
    try {
      await _batches.doc(batchId).set({
        'status': 'cancelled',
        'cancelledAt': now,
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Optional cancel history write skipped: $error');
    }
  }

  Future<void> completeIncubation(IncubatorData data) async {
    final now = FieldValue.serverTimestamp();
    await _incubatorRef.set({
      'isActive': false,
      'turningActive': false,
      'eggTurner': false,
      'heaterEnabled': false,
      'fanEnabled': false,
      'fanCircEnabled': false,
      'fanVentEnabled': false,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final batchId = data.currentBatchId;
    if (batchId.isEmpty) return;
    try {
      await _batches.doc(batchId).set({
        'status': 'completed',
        'completedAt': now,
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Optional complete history write skipped: $error');
    }
  }
}
