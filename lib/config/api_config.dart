import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _customHostKey = 'custom_backend_host';
  static const String _customFacialHostKey = 'custom_facial_host';

  // Obtiene la URL base adecuada según el entorno de ejecución
  static String get defaultBaseUrl {
    return 'https://dev-api-control.iiap.gob.pe/api';
  }

  static const String localWifiUrl = 'http://192.168.1.108:3000/api';
  static const String androidEmulatorUrl = 'http://10.0.2.2:3000/api';
  static const String defaultFacialBaseUrl = 'http://192.168.1.214:8000';

  static String _currentBaseUrl = defaultBaseUrl;
  static String _currentFacialBaseUrl = defaultFacialBaseUrl;

  static String get baseUrl => _currentBaseUrl;
  static String get facialServiceBaseUrl => _currentFacialBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_customHostKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _currentBaseUrl = saved.trim();
    } else {
      _currentBaseUrl = defaultBaseUrl;
    }

    final savedFacial = prefs.getString(_customFacialHostKey);
    if (savedFacial != null && savedFacial.trim().isNotEmpty) {
      _currentFacialBaseUrl = savedFacial.trim();
    } else {
      _currentFacialBaseUrl = defaultFacialBaseUrl;
    }
  }

  static Future<void> setCustomBaseUrl(String url) async {
    final trimmed = url.trim();
    _currentBaseUrl = trimmed.isEmpty ? defaultBaseUrl : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_customHostKey);
    } else {
      await prefs.setString(_customHostKey, trimmed);
    }
  }

  static Future<void> setCustomFacialBaseUrl(String url) async {
    final trimmed = url.trim();
    _currentFacialBaseUrl = trimmed.isEmpty ? defaultFacialBaseUrl : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_customFacialHostKey);
    } else {
      await prefs.setString(_customFacialHostKey, trimmed);
    }
  }

  // Rutas de la API
  static String get authRegister => '$baseUrl/auth/register';
  static String get authLogin => '$baseUrl/auth/login';
  static String get authMe => '$baseUrl/auth/me';
  static String get authForgotPassword => '$baseUrl/auth/forgot-password';
  static String get authResetPassword => '$baseUrl/auth/reset-password';
  static String get authGoogle => '$baseUrl/auth/google';
  static const String googleServerClientId = '546116812966-hr7pd2htl3e2na61skqmihg7jkbdf9m8.apps.googleusercontent.com';
  static const String googleIosClientId = '546116812966-aijkt8hrbhaue2uaj2d5cbem1nlspa9v.apps.googleusercontent.com';

  static String get usersMe => '$baseUrl/users/me';
  static String get usersAll => '$baseUrl/users';
  static String get usersSupervisors => '$baseUrl/users/supervisors';
  static String userById(String id) => '$baseUrl/users/$id';
  static String userRevokeSupervisor(String id) => '$baseUrl/users/supervisors/$id';
  static String userRole(String id) => '$baseUrl/users/$id/role';
  static String get uploadPhotoBase64 => '$baseUrl/users/me/photo-base64';

  static String get attendanceGenerateQr => '$baseUrl/attendance/generate-qr';
  static String get attendanceActiveQr => '$baseUrl/attendance/active-qr';
  static String get attendanceGenerateSupervisorQr => '$baseUrl/attendance/generate-supervisor-qr';
  static String get attendanceScanQr => '$baseUrl/attendance/scan-qr';
  static String get attendanceScanSupervisorQr => '$baseUrl/attendance/scan-supervisor-qr';
  static String get attendanceMyRecords => '$baseUrl/attendance/my-records';
  static String get attendanceToday => '$baseUrl/attendance/today';
  static String get attendanceAll => '$baseUrl/attendance/all';
  static String get attendancePendingCheckouts => '$baseUrl/attendance/pending-checkouts';
  static String get attendanceWeeklyReset => '$baseUrl/attendance/weekly-reset';
  static String get attendanceCorrectJourney => '$baseUrl/attendance/correct-journey';
  static String attendanceById(String id) => '$baseUrl/attendance/$id';

  static String get attendanceGenerateAssignmentQr => '$baseUrl/attendance/generate-assignment-qr';
  static String get attendanceScanAssignmentQr => '$baseUrl/attendance/scan-assignment-qr';
  static String get attendanceFacialRecord => '$baseUrl/attendance/facial-record';

  // Rutas del Servicio Biometrico Facial (Python - InsightFace & OpenCV)
  static String get facialScanWebcam => '$facialServiceBaseUrl/api/scan/webcam';
  static String get facialScanImage => '$facialServiceBaseUrl/api/scan/image';
  static String get facialStatus => '$facialServiceBaseUrl/api/status';

  // Rutas de Eventos
  static String get eventsAll => '$baseUrl/events';
  static String eventById(String id) => '$baseUrl/events/$id';
  static String eventRegisterAttendance(String id) => '$baseUrl/events/$id/attendance';
  static String eventGenerateQr(String id) => '$baseUrl/events/$id/qr';
  static String eventAttendees(String id) => '$baseUrl/events/$id/attendees';
  static String eventDeleteAttendee(String eventId, String attendeeId) => '$baseUrl/events/$eventId/attendees/$attendeeId';
  static String eventManagers(String id) => '$baseUrl/events/$id/managers';
  static String eventRemoveManager(String eventId, String userId) => '$baseUrl/events/$eventId/managers/$userId';

  /// URL web pública para que cualquier persona sin la app escanee con la cámara de su celular
  static String eventPublicRegistrationUrl(String eventId) {
    // Si la URL base es https://dev-api-control.iiap.gob.pe/api
    // Genera https://dev-api-control.iiap.gob.pe/events/registro?id=...
    final domain = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$domain/registro.html?id=$eventId';
  }
}


