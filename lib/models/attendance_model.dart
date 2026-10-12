// ignore_for_file: constant_identifier_names

enum AttendanceType {
  CHECK_IN,
  CHECK_OUT;

  static AttendanceType fromString(String? type) {
    if (type?.toUpperCase() == 'CHECK_OUT') {
      return AttendanceType.CHECK_OUT;
    }
    return AttendanceType.CHECK_IN;
  }

  String get label => this == AttendanceType.CHECK_IN ? 'ENTRADA' : 'SALIDA';
}

enum AttendanceStatus {
  ON_TIME,
  LATE,
  RECORDED;

  static AttendanceStatus fromString(String? status) {
    final s = status?.toUpperCase();
    if (s == 'LATE') {
      return AttendanceStatus.LATE;
    }
    if (s == 'RECORDED') {
      return AttendanceStatus.RECORDED;
    }
    return AttendanceStatus.ON_TIME;
  }

  String get label {
    switch (this) {
      case AttendanceStatus.ON_TIME:
        return 'A tiempo';
      case AttendanceStatus.LATE:
        return 'Tarde';
      case AttendanceStatus.RECORDED:
        return 'Registrado';
    }
  }
}

enum AttendanceShift {
  MORNING,
  AFTERNOON;

  static AttendanceShift fromString(String? shift) {
    if (shift?.toUpperCase() == 'AFTERNOON') {
      return AttendanceShift.AFTERNOON;
    }
    return AttendanceShift.MORNING;
  }

  String get label => this == AttendanceShift.MORNING ? 'Mañana' : 'Tarde';
  String get fullLabel => this == AttendanceShift.MORNING ? 'Turno Mañana' : 'Turno Tarde';
}

class AttendanceModel {
  final String id;
  final String userId;
  final DateTime timestamp;
  final AttendanceType type;
  final AttendanceStatus status;
  final AttendanceShift shift;
  final String? workDate;
  final String? scannedQrHash;
  final String? markedById;
  final String? userName;
  final String? userEmail;
  final String? userDocument;
  final String? markedByName;
  final double? latitude;
  final double? longitude;
  final String? deviceId;
  final bool isManual;
  final String? observation;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.type,
    required this.status,
    this.shift = AttendanceShift.MORNING,
    this.workDate,
    this.scannedQrHash,
    this.markedById,
    this.userName,
    this.userEmail,
    this.userDocument,
    this.markedByName,
    this.latitude,
    this.longitude,
    this.deviceId,
    this.isManual = false,
    this.observation,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map ? json['user'] as Map<String, dynamic> : null;
    final markedByMap = json['marked_by'] is Map ? json['marked_by'] as Map<String, dynamic> : null;

    final parsedTimestamp = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? userMap?['id']?.toString() ?? '',
      timestamp: parsedTimestamp,
      type: AttendanceType.fromString(json['type']?.toString()),
      status: AttendanceStatus.fromString(json['status']?.toString()),
      shift: AttendanceShift.fromString(json['shift']?.toString()),
      workDate: json['work_date']?.toString(),
      scannedQrHash: json['scanned_qr_hash']?.toString(),
      markedById: json['marked_by_id']?.toString() ?? markedByMap?['id']?.toString(),
      userName: json['user_name']?.toString() ?? userMap?['full_name']?.toString(),
      userEmail: json['user_email']?.toString() ?? userMap?['email']?.toString(),
      userDocument: userMap?['document_number']?.toString(),
      markedByName: json['marked_by_name']?.toString() ?? markedByMap?['full_name']?.toString(),
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      deviceId: json['device_id']?.toString(),
      isManual: json['is_manual'] == true,
      observation: json['observation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'status': status.name,
      'shift': shift.name,
      if (workDate != null) 'work_date': workDate,
      if (scannedQrHash != null) 'scanned_qr_hash': scannedQrHash,
      if (markedById != null) 'marked_by_id': markedById,
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
      if (userDocument != null) 'document_number': userDocument,
      if (markedByName != null) 'marked_by_name': markedByName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (deviceId != null) 'device_id': deviceId,
      'is_manual': isManual,
      if (observation != null) 'observation': observation,
    };
  }
}

/// Representa una jornada de asistencia consolidada por Fecha y Turno (Entrada + Salida + Estado)
class ShiftJourneyRecord {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userDocument;
  final String workDate;
  final AttendanceShift shift;
  final AttendanceModel? checkIn;
  final AttendanceModel? checkOut;

  ShiftJourneyRecord({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userDocument,
    required this.workDate,
    required this.shift,
    this.checkIn,
    this.checkOut,
  });

  bool get hasCheckIn => checkIn != null;
  bool get hasCheckOut => checkOut != null;
  bool get isCompleted => hasCheckIn && hasCheckOut;
  bool get isPendingCheckOut => hasCheckIn && !hasCheckOut;

  /// Agrupa registros planos en jornadas por (user_id, fecha, turno)
  static List<ShiftJourneyRecord> groupFromRecords(List<AttendanceModel> records) {
    final Map<String, ShiftJourneyRecord> map = {};
    final sorted = List<AttendanceModel>.from(records)..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final r in sorted) {
      final dateStr = r.workDate ?? r.timestamp.toIso8601String().substring(0, 10);
      final key = '${r.userId}_${dateStr}_${r.shift.name}';

      final existing = map[key];
      if (existing == null) {
        map[key] = ShiftJourneyRecord(
          id: r.id,
          userId: r.userId,
          userName: r.userName,
          userEmail: r.userEmail,
          userDocument: r.userDocument,
          workDate: dateStr,
          shift: r.shift,
          checkIn: r.type == AttendanceType.CHECK_IN ? r : null,
          checkOut: r.type == AttendanceType.CHECK_OUT ? r : null,
        );
      } else {
        map[key] = ShiftJourneyRecord(
          id: existing.id,
          userId: existing.userId,
          userName: existing.userName ?? r.userName,
          userEmail: existing.userEmail ?? r.userEmail,
          userDocument: existing.userDocument ?? r.userDocument,
          workDate: existing.workDate,
          shift: existing.shift,
          checkIn: existing.checkIn ?? (r.type == AttendanceType.CHECK_IN ? r : null),
          checkOut: existing.checkOut ?? (r.type == AttendanceType.CHECK_OUT ? r : null),
        );
      }
    }

    final result = map.values.toList();
    result.sort((a, b) {
      final timeA = a.checkIn?.timestamp ?? a.checkOut?.timestamp ?? DateTime(2000);
      final timeB = b.checkIn?.timestamp ?? b.checkOut?.timestamp ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });
    return result;
  }
}
