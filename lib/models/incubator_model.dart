import 'package:cloud_firestore/cloud_firestore.dart';

class VisionDetection {
  final String className;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  const VisionDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory VisionDetection.fromMap(Map<String, dynamic> map) {
    return VisionDetection(
      className: map['class']?.toString() ?? 'Unknown',
      confidence: _toDouble(map['confidence']),
      x: _toDouble(map['x']),
      y: _toDouble(map['y']),
      width: _toDouble(map['width']),
      height: _toDouble(map['height']),
    );
  }
}

class VisionData {
  final int totalEggs;
  final int crackedEggs;
  final int normalEggs;
  final bool cameraOnline;
  final int imageWidth;
  final int imageHeight;
  final double confidenceThreshold;
  final DateTime? analyzedAt;
  final List<VisionDetection> detections;
  final String imageBase64;

  const VisionData({
    this.totalEggs = 0,
    this.crackedEggs = 0,
    this.normalEggs = 0,
    this.cameraOnline = false,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.confidenceThreshold = 0.5,
    this.analyzedAt,
    this.detections = const [],
    this.imageBase64 = '',
  });

  factory VisionData.fromMap(Map<String, dynamic> map) {
    final rawDetections = map['detections'];
    final detections = <VisionDetection>[];

    if (rawDetections is List) {
      for (final item in rawDetections) {
        if (item is Map) {
          detections.add(
            VisionDetection.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return VisionData(
      totalEggs: _toInt(map['totalEggs']),
      crackedEggs: _toInt(map['crackedEggs']),
      normalEggs: _toInt(map['normalEggs']),
      cameraOnline: map['cameraOnline'] == true,
      imageWidth: _toInt(map['imageWidth']),
      imageHeight: _toInt(map['imageHeight']),
      confidenceThreshold: _toDouble(
        map['confidenceThreshold'],
        fallback: 0.5,
      ),
      analyzedAt: _toDateTime(map['analyzedAt']),
      detections: detections,
      imageBase64: map['imageBase64']?.toString() ?? '',
    );
  }
}

class IncubatorData {
  final double temperature;
  final double humidity;
  final double targetTemperature;
  final double targetHumidity;
  final bool heater;
  final bool fan;
  final bool fanCirc;
  final bool fanVent;
  final bool heaterEnabled;
  final bool fanEnabled;
  final bool fanCircEnabled;
  final bool fanVentEnabled;
  final bool eggTurner;
  final double waterLevel;
  final double turningInterval;
  final int turningIntervalMinutes;
  final int turningIntervalSeconds;
  final bool turningActive;
  final bool cameraOnline;
  final bool isActive;
  final bool deviceOnline;
  final String controlMode;
  final String? startDate;
  final int totalEggs;
  final int hatchCount;
  final int incubationEndDay;
  final int lockdownEndDay;
  final int incubationStartDay;
  final int lockdownStartDay;
  final int currentDay;
  final int lastBatchNumber;
  final VisionData vision;
  final String currentBatchId;
  final String currentBatchNumber;
  final String currentTrayNumber;

  const IncubatorData({
    required this.temperature,
    required this.humidity,
    this.targetTemperature = 37.5,
    this.targetHumidity = 55,
    required this.heater,
    required this.fan,
    this.fanCirc = false,
    this.fanVent = false,
    this.heaterEnabled = true,
    this.fanEnabled = true,
    this.fanCircEnabled = true,
    this.fanVentEnabled = true,
    required this.eggTurner,
    required this.waterLevel,
    required this.turningInterval,
    this.turningIntervalMinutes = 0,
    this.turningIntervalSeconds = 0,
    required this.turningActive,
    required this.cameraOnline,
    required this.isActive,
    this.deviceOnline = false,
    this.controlMode = 'auto',
    this.startDate,
    required this.totalEggs,
    required this.hatchCount,
    required this.vision,
    this.incubationEndDay = 18,
    this.lockdownEndDay = 21,
    this.incubationStartDay = 1,
    this.lockdownStartDay = 18,
    this.currentDay = 0,
    this.lastBatchNumber = 0,
    this.currentBatchId = '',
    this.currentBatchNumber = '',
    this.currentTrayNumber = '1',
  });

  factory IncubatorData.fromMap(Map<String, dynamic> map) {
    final rawVision = map['vision'];

    final visionMap = rawVision is Map
        ? Map<String, dynamic>.from(rawVision)
        : <String, dynamic>{};

    final vision = VisionData.fromMap(visionMap);

    return IncubatorData(
      temperature: _toDouble(map['temperature'], fallback: 37.5),
      humidity: _toDouble(map['humidity'], fallback: 50),
      targetTemperature: _toDouble(
        map['targetTemperature'],
        fallback: 37.5,
      ),
      targetHumidity: _toDouble(
        map['targetHumidity'],
        fallback: 55,
      ),
      heater: map['heater'] == true,
      fan: map['fan'] == true,
      fanCirc: map['fanCirc'] == true,
      fanVent: map['fanVent'] == true,
      heaterEnabled: map.containsKey('heaterEnabled')
          ? map['heaterEnabled'] == true
          : true,
      fanEnabled: map.containsKey('fanEnabled')
          ? map['fanEnabled'] == true
          : true,
      fanCircEnabled: map.containsKey('fanCircEnabled')
          ? map['fanCircEnabled'] == true
          : (map.containsKey('fanEnabled')
              ? map['fanEnabled'] == true
              : true),
      fanVentEnabled: map.containsKey('fanVentEnabled')
          ? map['fanVentEnabled'] == true
          : (map.containsKey('fanEnabled')
              ? map['fanEnabled'] == true
              : true),
      eggTurner: map['eggTurner'] == true,
      waterLevel: _toDouble(map['waterLevel']),
      turningInterval: _toDouble(
        map['turningInterval'],
        fallback: 4,
      ),
      turningIntervalMinutes: _toInt(map['turningIntervalMinutes']),
      turningIntervalSeconds: _toInt(map['turningIntervalSeconds']),
      turningActive: map['turningActive'] == true,
      cameraOnline: visionMap.containsKey('cameraOnline')
          ? vision.cameraOnline
          : map['cameraOnline'] == true,
      isActive: map['isActive'] == true,
      deviceOnline: map['deviceOnline'] == true,
      controlMode: map['controlMode']?.toString() == 'manual' ? 'manual' : 'auto',
      startDate: map['startDate']?.toString(),
      totalEggs: _toInt(map['totalEggs']),
      hatchCount: _toInt(map['hatchCount']),
      incubationEndDay: _toInt(
        map['incubationEndDay'],
        fallback: 18,
      ),
      lockdownEndDay: _toInt(
        map['lockdownEndDay'],
        fallback: 21,
      ),
      incubationStartDay: _toInt(
        map['incubationStartDay'],
        fallback: 1,
      ),
      lockdownStartDay: _toInt(
        map['lockdownStartDay'],
        fallback: _toInt(map['incubationEndDay'], fallback: 18),
      ),
      currentDay: _toInt(map['currentDay']),
      lastBatchNumber: _toInt(map['lastBatchNumber']),
      vision: vision,
      currentBatchId: map['currentBatchId']?.toString() ?? '',
      currentBatchNumber: map['currentBatchNumber']?.toString() ?? '',
      currentTrayNumber: map['currentTrayNumber']?.toString() ?? '1',
    );
  }

  /// Friendly label such as "Batch 1". Firestore still stores BATCH-2026-001.
  String get displayBatchName {
    if (currentBatchNumber.isEmpty && lastBatchNumber <= 0) {
      return '';
    }

    final match = RegExp(r'(\d+)\s*$').firstMatch(currentBatchNumber);
    if (match != null) {
      final number = int.tryParse(match.group(1)!) ?? 0;
      if (number > 0) return 'Batch $number';
    }

    if (lastBatchNumber > 0) return 'Batch $lastBatchNumber';
    return 'Batch 1';
  }

  bool get isManualMode => controlMode == 'manual';

  int get turningTotalSeconds {
    if (turningIntervalSeconds > 0) return turningIntervalSeconds;
    if (turningIntervalMinutes > 0) return turningIntervalMinutes * 60;
    final fromHours = (turningInterval * 3600).round();
    return fromHours > 0 ? fromHours : 14400;
  }

  String get turningIntervalLabel {
    final total = turningTotalSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final parts = <String>[];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s');
    return parts.join(' ');
  }
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}