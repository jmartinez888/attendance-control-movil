class QrGeneratedResponse {
  final bool success;
  final String message;
  final String qrCode;
  final String type;
  final DateTime expiresAt;
  final int remainingSeconds;
  final int? currentSupervisorsCount;
  final int? maxSupervisors;
  final int? availableSlots;

  QrGeneratedResponse({
    required this.success,
    required this.message,
    required this.qrCode,
    required this.type,
    required this.expiresAt,
    required this.remainingSeconds,
    this.currentSupervisorsCount,
    this.maxSupervisors,
    this.availableSlots,
  });

  factory QrGeneratedResponse.fromJson(Map<String, dynamic> json) {
    return QrGeneratedResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? json['qr_token']?.toString() ?? '',
      type: json['type']?.toString() ?? 'ATTENDANCE',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())?.toLocal() ?? DateTime.now().add(const Duration(minutes: 5))
          : DateTime.now().add(const Duration(minutes: 5)),
      remainingSeconds: json['remaining_seconds'] is int
          ? json['remaining_seconds'] as int
          : int.tryParse(json['remaining_seconds']?.toString() ?? '300') ?? 300,
      currentSupervisorsCount: json['current_supervisors_count'] is int ? json['current_supervisors_count'] as int : null,
      maxSupervisors: json['max_supervisors'] is int ? json['max_supervisors'] as int : null,
      availableSlots: json['available_slots'] is int ? json['available_slots'] as int : null,
    );
  }
}

class AttendanceScanResult {
  final bool success;
  final String message;
  final String? typeLabel;
  final String? formattedTime;
  final String? formattedDate;
  final String? markedByName;
  final String? nextQrCode;

  AttendanceScanResult({
    required this.success,
    required this.message,
    this.typeLabel,
    this.formattedTime,
    this.formattedDate,
    this.markedByName,
    this.nextQrCode,
  });

  factory AttendanceScanResult.fromJson(Map<String, dynamic> json) {
    final att = json['attendance'] is Map ? json['attendance'] as Map<String, dynamic> : null;
    final nextQr = json['next_qr'] is Map ? json['next_qr'] as Map<String, dynamic> : null;

    return AttendanceScanResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      typeLabel: att?['type_label']?.toString() ?? att?['type']?.toString(),
      formattedTime: att?['formatted_time']?.toString(),
      formattedDate: att?['formatted_date']?.toString(),
      markedByName: att?['marked_by']?.toString(),
      nextQrCode: nextQr?['qr_code']?.toString(),
    );
  }
}
