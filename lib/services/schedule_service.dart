import '../models/user_model.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_model.dart';
import 'users_service.dart';

class ScheduleService {
  static const String _keyPrefix = 'user_schedule_';

  /// Notificador global reactivo para que cualquier cambio de horario se actualice al instante en la UI
  static final ValueNotifier<Map<String, ScheduleModel>> schedulesNotifier =
      ValueNotifier<Map<String, ScheduleModel>>({});

  /// Carga inicial de horarios guardados
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    final Map<String, ScheduleModel> map = {};

    for (final k in keys) {
      final jsonStr = prefs.getString(k);
      if (jsonStr != null) {
        try {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          final schedule = ScheduleModel.fromJson(decoded);
          map[schedule.userId] = schedule;
        } catch (_) {}
      }
    }

    schedulesNotifier.value = map;
  }

  /// Obtiene el horario asignado a un usuario (leyendo del servidor o memoria)
  static ScheduleModel getSchedule(String userId, {UserModel? user, String? position}) {
    // 1. Si se pasó el usuario y tiene horario personalizado configurado en PostgreSQL:
    if (user != null && user.customScheduleEnabled && user.customCheckIn != null) {
      final inParts = user.customCheckIn!.split(':');
      final outParts = (user.customCheckOut ?? '17:00').split(':');
      var inH = int.tryParse(inParts.isNotEmpty ? inParts[0] : '8') ?? 8;
      final inM = int.tryParse(inParts.length > 1 ? inParts[1] : '0') ?? 0;
      var outH = int.tryParse(outParts.isNotEmpty ? outParts[0] : '17') ?? 17;
      final outM = int.tryParse(outParts.length > 1 ? outParts[1] : '0') ?? 0;

      // Normalizar 12h ambiguo a horario laboral 24h
      inH = ScheduleModel.normalizeHour(inH, isCheckOut: false);
      outH = ScheduleModel.normalizeHour(outH, isCheckOut: true);

      return ScheduleModel(
        userId: userId,
        type: ScheduleType.personalizado,
        checkInHour: inH,
        checkInMinute: inM,
        checkOutHour: outH,
        checkOutMinute: outM,
        toleranceMinutes: user.customToleranceMinutes,
      );
    }

    // 2. Si ya está cargado en el notificador reactivo:
    if (schedulesNotifier.value.containsKey(userId)) {
      return schedulesNotifier.value[userId]!;
    }

    return ScheduleModel.defaultGeneral(userId);
  }

  /// Guarda el horario del usuario localmente y en la base de datos real del servidor en formato 24h
  static Future<void> saveSchedule(ScheduleModel schedule) async {
    final normInH = schedule.type == ScheduleType.personalizado
        ? ScheduleModel.normalizeHour(schedule.checkInHour, isCheckOut: false)
        : schedule.checkInHour;
    final normOutH = schedule.type == ScheduleType.personalizado
        ? ScheduleModel.normalizeHour(schedule.checkOutHour, isCheckOut: true)
        : schedule.checkOutHour;

    final normalizedSchedule = ScheduleModel(
      userId: schedule.userId,
      type: schedule.type,
      checkInHour: normInH,
      checkInMinute: schedule.checkInMinute,
      checkOutHour: normOutH,
      checkOutMinute: schedule.checkOutMinute,
      toleranceMinutes: schedule.toleranceMinutes,
      customNotes: schedule.customNotes,
      updatedAt: schedule.updatedAt ?? DateTime.now(),
      updatedByName: schedule.updatedByName,
    );

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(normalizedSchedule.toJson());
    await prefs.setString('$_keyPrefix${schedule.userId}', jsonStr);

    // Actualizar notificador reactivo
    final updated = Map<String, ScheduleModel>.from(schedulesNotifier.value);
    updated[schedule.userId] = normalizedSchedule;
    schedulesNotifier.value = updated;

    // Sincronizar con el backend en la base de datos real de PostgreSQL en 24h
    final isCustom = normalizedSchedule.type == ScheduleType.personalizado;
    final checkInStr = '${normInH.toString().padLeft(2, '0')}:${normalizedSchedule.checkInMinute.toString().padLeft(2, '0')}';
    final checkOutStr = '${normOutH.toString().padLeft(2, '0')}:${normalizedSchedule.checkOutMinute.toString().padLeft(2, '0')}';

    try {
      await UsersService.updateUser(
        schedule.userId,
        {
          'custom_schedule_enabled': isCustom,
          'custom_check_in': checkInStr,
          'custom_check_out': checkOutStr,
          'custom_tolerance_minutes': normalizedSchedule.toleranceMinutes,
        },
      );
    } catch (_) {
      // Si falla la red se mantendrá guardado localmente de forma segura
    }
  }
}
