enum ScheduleType {
  institucional,
  personalizado;

  String get displayName {
    switch (this) {
      case ScheduleType.institucional:
        return 'Horario Institucional (08:00 AM - 05:00 PM)';
      case ScheduleType.personalizado:
        return 'Horario Personalizado';
    }
  }

  String get categoryName {
    switch (this) {
      case ScheduleType.institucional:
        return 'Institucional';
      case ScheduleType.personalizado:
        return 'Personalizado';
    }
  }

  String get shiftName {
    switch (this) {
      case ScheduleType.institucional:
        return 'Regular';
      case ScheduleType.personalizado:
        return 'Especial';
    }
  }
}

class ScheduleEvaluation {
  final String shiftLabel;
  final bool isPunctual;
  final int minutesLate;
  final String shiftType;

  const ScheduleEvaluation({
    required this.shiftLabel,
    required this.isPunctual,
    this.minutesLate = 0,
    required this.shiftType,
  });
}

class ScheduleModel {
  final String userId;
  final ScheduleType type;
  final int checkInHour; // 0-23 (por defecto 8 AM)
  final int checkInMinute; // 0-59 (por defecto 0)
  final int checkOutHour; // 0-23 (por defecto 17 / 5 PM)
  final int checkOutMinute; // 0-59 (por defecto 0)
  final int toleranceMinutes; // Por defecto 30 min (hasta las 08:30 AM)
  final String? customNotes;
  final DateTime? updatedAt;
  final String? updatedByName;

  const ScheduleModel({
    required this.userId,
    this.type = ScheduleType.institucional,
    this.checkInHour = 8,
    this.checkInMinute = 0,
    this.checkOutHour = 17,
    this.checkOutMinute = 0,
    this.toleranceMinutes = 30,
    this.customNotes,
    this.updatedAt,
    this.updatedByName,
  });

  /// Normaliza horas ambiguas del formato 12h a horario institucional 24h
  static int normalizeHour(int hour, {bool isCheckOut = false}) {
    if (!isCheckOut && hour >= 1 && hour <= 6) {
      return hour + 12; // Entrada de 1:00 a 6:00 pm -> 13:00 a 18:00
    }
    if (isCheckOut && hour >= 1 && hour <= 11) {
      return hour + 12; // Salida de 1:00 a 11:00 pm -> 13:00 a 23:00
    }
    return hour;
  }

  /// Crea un horario predeterminado según el tipo
  factory ScheduleModel.defaultForType({
    required String userId,
    required ScheduleType type,
    String? updatedByName,
  }) {
    return ScheduleModel(
      userId: userId,
      type: type,
      checkInHour: 8,
      checkInMinute: 0,
      checkOutHour: 17,
      checkOutMinute: 0,
      toleranceMinutes: 30,
      updatedAt: DateTime.now(),
      updatedByName: updatedByName,
    );
  }

  /// Horario institucional estándar único
  factory ScheduleModel.defaultGeneral(String userId) {
    return ScheduleModel.defaultForType(userId: userId, type: ScheduleType.institucional);
  }

  static String _formatTime24(int hour, int minute) {
    final hStr = hour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  static String _formatTime12(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hStr = h.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  String get checkInTimeFormatted => _formatTime24(checkInHour, checkInMinute);
  String get checkOutTimeFormatted => _formatTime24(checkOutHour, checkOutMinute);

  String get checkInTimeFormatted12h => _formatTime12(checkInHour, checkInMinute);
  String get checkOutTimeFormatted12h => _formatTime12(checkOutHour, checkOutMinute);

  String get timeRangeFormatted => '$checkInTimeFormatted - $checkOutTimeFormatted';
  String get timeRangeFormatted12h => '$checkInTimeFormatted12h - $checkOutTimeFormatted12h';

  /// Hora límite de tolerancia formateada en 12h (ej. '08:30 AM' o '03:00 PM')
  String get toleranceLimitFormatted {
    final effectiveInH = (type == ScheduleType.personalizado && checkInHour >= 1 && checkInHour <= 6)
        ? checkInHour + 12
        : checkInHour;
    final totalTolMins = effectiveInH * 60 + checkInMinute + toleranceMinutes;
    final tolH = (totalTolMins ~/ 60) % 24;
    final tolM = totalTolMins % 60;
    return _formatTime12(tolH, tolM);
  }

  /// Etiqueta completa ej: "Horario Institucional (08:00 AM - 05:00 PM)" o "Horario Personalizado (02:30 PM - 07:00 PM)"
  String get fullLabel {
    if (type == ScheduleType.personalizado) {
      return 'Horario Personalizado ($timeRangeFormatted12h)';
    }
    return 'Horario Institucional (08:00 AM - 05:00 PM)';
  }

  /// Etiqueta corta ej: "02:30 PM - 07:00 PM • Personalizado"
  String get shortLabel {
    return '$timeRangeFormatted12h • ${type.categoryName}';
  }

  /// Evalúa la puntualidad de la marca de asistencia considerando la hora normalizada a 24h
  ScheduleEvaluation evaluateAttendance(DateTime timestamp, bool isCheckIn) {
    if (!isCheckIn) {
      return ScheduleEvaluation(
        shiftLabel: fullLabel,
        isPunctual: true,
        minutesLate: 0,
        shiftType: type.name,
      );
    }

    final local = timestamp.toLocal();
    final actualMinutes = local.hour * 60 + local.minute;

    final effectiveInH = (type == ScheduleType.personalizado && checkInHour >= 1 && checkInHour <= 6)
        ? checkInHour + 12
        : checkInHour;
    final entryLimitMinutes = effectiveInH * 60 + checkInMinute + toleranceMinutes;

    final punctual = actualMinutes <= entryLimitMinutes;

    return ScheduleEvaluation(
      shiftLabel: fullLabel,
      isPunctual: punctual,
      minutesLate: 0,
      shiftType: type.name,
    );
  }

  /// Evalúa si una marca de entrada fue a tiempo
  bool isPunctual(DateTime checkInDateTime) {
    final local = checkInDateTime.toLocal();
    final effectiveInH = (type == ScheduleType.personalizado && checkInHour >= 1 && checkInHour <= 6)
        ? checkInHour + 12
        : checkInHour;
    final entryLimitMinutes = effectiveInH * 60 + checkInMinute + toleranceMinutes;
    final actualMinutes = local.hour * 60 + local.minute;
    return actualMinutes <= entryLimitMinutes;
  }

  int minutesLate(DateTime checkInDateTime) => 0;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type.name,
      'check_in_hour': checkInHour,
      'check_in_minute': checkInMinute,
      'check_out_hour': checkOutHour,
      'check_out_minute': checkOutMinute,
      'tolerance_minutes': toleranceMinutes,
      'custom_notes': customNotes,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by_name': updatedByName,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    ScheduleType parsedType;
    try {
      final t = json['type']?.toString().toLowerCase();
      if (t == 'personalizado') {
        parsedType = ScheduleType.personalizado;
      } else {
        parsedType = ScheduleType.institucional;
      }
    } catch (_) {
      parsedType = ScheduleType.institucional;
    }

    int rawInH = (json['check_in_hour'] as num?)?.toInt() ?? 8;
    int rawInM = (json['check_in_minute'] as num?)?.toInt() ?? 0;
    int rawOutH = (json['check_out_hour'] as num?)?.toInt() ?? 17;
    int rawOutM = (json['check_out_minute'] as num?)?.toInt() ?? 0;

    if (parsedType == ScheduleType.personalizado) {
      rawInH = normalizeHour(rawInH, isCheckOut: false);
      rawOutH = normalizeHour(rawOutH, isCheckOut: true);
    }

    return ScheduleModel(
      userId: json['user_id']?.toString() ?? '',
      type: parsedType,
      checkInHour: rawInH,
      checkInMinute: rawInM,
      checkOutHour: rawOutH,
      checkOutMinute: rawOutM,
      toleranceMinutes: (json['tolerance_minutes'] as num?)?.toInt() ?? 30,
      customNotes: json['custom_notes']?.toString(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedByName: json['updated_by_name']?.toString(),
    );
  }

  /// Cadena compacta legible para sincronizar con el backend
  String toCompactPositionString() {
    return 'Horario Institucional (08:00 AM - 05:00 PM)';
  }

  /// Reconstruye el horario institucional
  static ScheduleModel? tryParseFromPosition(String userId, String? position) {
    return ScheduleModel.defaultGeneral(userId);
  }
}
