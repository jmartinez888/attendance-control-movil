import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../models/attendance_model.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/event_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/leaf_logo.dart';
import '../events/create_event_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/events_list_screen.dart';
import '../qr/qr_display_screen.dart';
import '../qr/qr_scanner_screen.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToProfile;

  const DashboardTab({
    super.key,
    this.onNavigateToHistory,
    this.onNavigateToProfile,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<AttendanceModel> _todayRecords = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Cargar caché inmediato en memoria para 0 ms lag
    final cached = AttendanceService.getCachedTodayRecords();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _todayRecords = cached;
      });
    }

    // 2. Refrescar con backend
    _fetchTodayAttendance();
    EventService.getEvents();
  }

  Future<void> _fetchTodayAttendance() async {
    if (!mounted) return;
    try {
      final records = await AttendanceService.getTodayRecords();
      if (mounted) {
        setState(() {
          _todayRecords = records;
        });
      }
    } catch (_) {}
  }

  void _handleGenerarQr(BuildContext context, UserModel user) {
    if (user.canManageAttendanceQr) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const QrDisplayScreen(mode: QrMode.attendance),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 36),
          ),
          title: const Text(
            'Acceso Restringido',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: const Text(
            'La función Generar QR con cifrado SHA-256 está reservada exclusivamente para el Administrador y los Supervisores autorizados para la toma de asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleEscanearQr(BuildContext context) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(target: ScanTarget.attendance),
      ),
    );
    if (res == true && mounted) {
      await _fetchTodayAttendance();
      await EventService.getEvents();
    }
  }

  String _maskDni(String? dni) {
    if (dni == null || dni.trim().isEmpty) return '7492****';
    final clean = dni.trim();
    if (clean.length > 4) {
      return '${clean.substring(0, 4)}****';
    }
    return clean;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final hourStr = displayHour.toString().padLeft(2, '0');
    final minStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr $period';
  }

  String _getCurrentShiftLabel() {
    final now = DateTime.now();
    if (now.hour < 13) {
      return 'Turno Mañana';
    } else {
      return 'Turno Tarde';
    }
  }

  String _getMonthAbbr(int month) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  String _formatEventDateAndDuration(EventModel event) {
    final now = DateTime.now();
    final isToday = event.startDate.year == now.year &&
        event.startDate.month == now.month &&
        event.startDate.day == now.day;

    final hourStr = _formatTime(event.startDate);
    final prefix = isToday ? 'Hoy' : '${event.startDate.day} ${_getMonthAbbr(event.startDate.month)}';

    final duration = event.endDate.difference(event.startDate);
    String durStr = '';
    if (duration.inMinutes > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (hours > 0 && mins > 0) {
        durStr = ' (Duración: ${hours}h ${mins}m)';
      } else if (hours > 0) {
        durStr = ' (Duración: ${hours}h)';
      } else {
        durStr = ' (Duración: ${mins}m)';
      }
    }
    return '$prefix, $hourStr$durStr';
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, rawUser, _) {
        final user = rawUser ?? StorageService.currentUser;
        if (user == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }

        // Determinar registros de Entrada y Salida del día
        AttendanceModel? entry;
        AttendanceModel? exit;

        for (final r in _todayRecords) {
          if (r.type == AttendanceType.CHECK_IN) {
            if (entry == null || r.timestamp.isBefore(entry.timestamp)) {
              entry = r;
            }
          } else if (r.type == AttendanceType.CHECK_OUT) {
            if (exit == null || r.timestamp.isAfter(exit.timestamp)) {
              exit = r;
            }
          }
        }

        return SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFF10B981),
            backgroundColor: const Color(0xFF131D21),
            onRefresh: () async {
              await AuthService.getProfile();
              await _fetchTodayAttendance();
              await EventService.getEvents();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Responsive.constrained(
                context,
                maxTabletWidth: 680,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // 1. TOP APP BAR (HEADER SUPERIOR)
                    // ==========================================
                    _buildTopHeader(context, user),

                    const SizedBox(height: 18),

                    // ==========================================
                    // 2. CARD DE BIENVENIDA / PERFIL
                    // ==========================================
                    _buildWelcomeProfileCard(context, user),

                    const SizedBox(height: 18),

                    // ==========================================
                    // 3. CARD JORNADA DE HOY
                    // ==========================================
                    _buildJornadaDeHoyCard(context, user, entry, exit),

                    const SizedBox(height: 22),

                    // ==========================================
                    // 4. SECCIÓN CONTROL DE ASISTENCIA
                    // ==========================================
                    _buildAttendanceControlSection(context, user),

                    const SizedBox(height: 22),

                    // ==========================================
                    // 5. SECCIÓN EVENTOS INSTITUCIONALES
                    // ==========================================
                    _buildEventsSection(context, user),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // COMPONENTES UI - VISTAS EXACTAS A LAS IMÁGENES
  // ===========================================================================

  Widget _buildTopHeader(BuildContext context, UserModel user) {
    return Row(
      children: [
        // Squircle con Leaf Logo + Nombre IIAP OFICIAL
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF142226),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F333B)),
          ),
          child: const LeafLogo(size: 22),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'IIAP',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.1,
              ),
            ),
            Text(
              'OFICIAL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
                letterSpacing: 1.2,
                height: 1.2,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Badge ● EN LÍNEA
        ValueListenableBuilder<bool>(
          valueListenable: ConnectivityService.isOnlineNotifier,
          builder: (context, isOnline, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF0D2821) : const Color(0xFF2E1515),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOnline ? const Color(0xFF165942) : const Color(0xFF5A2020),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isOnline ? 'EN LÍNEA' : 'OFFLINE',
                    style: TextStyle(
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(width: 10),

        // Botón Notificaciones
        IconButton(
          onPressed: () {
            NotificationService.checkAndTriggerCheckoutReminder();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notificaciones sincronizadas. Sin alertas pendientes.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF131D21),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          splashRadius: 20,
        ),

        const SizedBox(width: 6),

        // Avatar de usuario circular que lleva al Perfil
        InkWell(
          onTap: () {
            widget.onNavigateToProfile?.call();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF34D399),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                  ? Image.network(
                      user.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Color(0xFF0F172A),
                        size: 21,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Color(0xFF0F172A),
                      size: 21,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeProfileCard(BuildContext context, UserModel user) {
    // Extraer primer nombre
    final nameParts = user.fullName.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : 'Usuario';

    // Cargo y Dependencia
    final cargo = user.office.isNotEmpty
        ? user.office
        : (user.position?.isNotEmpty == true ? user.position! : 'Servidor Público');
    final dependencia = user.area.isNotEmpty
        ? user.area
        : (user.department?.isNotEmpty == true ? user.department! : 'Sede Central IIAP');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF131D21),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F323A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto / Avatar ovalado horizontal con dot verde de status
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 98,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35), // Oval horizontal
                  border: Border.all(color: const Color(0xFF28404B), width: 1.5),
                  color: const Color(0xFF0D1619),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                      ? Image.network(
                          user.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultOvalAvatar(user),
                        )
                      : _buildDefaultOvalAvatar(user),
                ),
              ),
              // Dot verde activo en la esquina inferior derecha
              Positioned(
                bottom: 2,
                right: 3,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF131D21), width: 2.2),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Información del usuario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hola,',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        firstName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 9.5, color: Colors.black),
                    ),
                    const Spacer(),
                    // Badge ícono de campana / recordatorio
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A30),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF263C45)),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        size: 14,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$cargo • $dependencia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8FA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3224),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF176044)),
                      ),
                      child: Text(
                        user.isAdmin
                            ? 'ADMIN ACTIVO'
                            : (user.isSupervisor ? 'SUPERVISOR ACTIVO' : 'USUARIO ACTIVO'),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  DNI ${_maskDni(user.documentNumber)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8FA3AF),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultOvalAvatar(UserModel user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF162E2A), Color(0xFF0C191B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_rounded, color: Color(0xFF34D399), size: 30),
            const SizedBox(height: 2),
            Text(
              _getInitials(user.fullName),
              style: const TextStyle(
                color: Color(0xFF6EE7B7),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJornadaDeHoyCard(
    BuildContext context,
    UserModel user,
    AttendanceModel? entry,
    AttendanceModel? exit,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D21),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F323A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado: ⏰ Jornada de Hoy  -  Turno Mañana • En curso
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, color: Color(0xFF10B981), size: 17),
                  SizedBox(width: 8),
                  Text(
                    'Jornada de Hoy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF18262B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF263C45)),
                ),
                child: Text(
                  '${_getCurrentShiftLabel()} • En curso',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dos columnas: Entrada (Izquierda) y Salida (Derecha)
          Row(
            children: [
              // Columna Entrada
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E171A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1B2B31)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Entrada',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: entry != null
                                  ? (entry.status == AttendanceStatus.LATE
                                      ? const Color(0xFF38290E)
                                      : const Color(0xFF0E382B))
                                  : const Color(0xFF222E33),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry != null
                                  ? (entry.status == AttendanceStatus.LATE ? 'Tarde' : 'A tiempo')
                                  : 'Pendiente',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: entry != null
                                    ? (entry.status == AttendanceStatus.LATE
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF10B981))
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry != null ? _formatTime(entry.timestamp) : '--:-- AM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: entry != null ? Colors.white : const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            entry != null ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 11.5,
                            color: entry != null ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entry?.observation?.isNotEmpty == true
                                  ? entry!.observation!
                                  : 'Molinete Principal #02',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8FA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Columna Salida
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E171A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1B2B31)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Salida',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: exit != null
                                  ? const Color(0xFF0E382B)
                                  : const Color(0xFF38290E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exit != null ? 'Completado' : 'Pendiente',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: exit != null
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exit != null ? _formatTime(exit.timestamp) : '--:-- PM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: exit != null ? Colors.white : const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11.5,
                            color: exit != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              exit != null ? 'Jornada Finalizada' : 'Previsto: 04:30 PM',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8FA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceControlSection(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header de sección: CONTROL DE ASISTENCIA  -  🔒 SHA-256
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CONTROL DE ASISTENCIA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2821),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF176044)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 11.5, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'SHA-256',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Tarjeta Principal de Escaneo
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF131D21),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF1F323A), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Squircle QR + Badge Cámara Lista
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2D24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF176044), width: 1.2),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF10B981),
                          size: 26,
                        ),
                      ),
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF131D21), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E231D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF165942)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF10B981), size: 6.5),
                        SizedBox(width: 5),
                        Text(
                          'Cámara Lista',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Text(
                'Escanear QR Institucional',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Registra tu ingreso o salida escaneando el código QR oficial proyectado en tu sede física, auditorio o estación de evento.',
                style: TextStyle(
                  color: Color(0xFF8FA3AF),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 18),

              // Botón Verde Prominente: [ 📷 Iniciar Escáner Oficial ➔ ]
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34D399), // Verde esmeralda brillante
                    foregroundColor: const Color(0xFF091417),
                    elevation: 4,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _handleEscanearQr(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 20, color: Color(0xFF091417)),
                      Text(
                        'Iniciar Escáner Oficial',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: Color(0xFF091417),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFF091417)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ==========================================================
        // HERRAMIENTAS EXCLUSIVAS DE SUPERVISIÓN Y ADMINISTRACIÓN
        // ==========================================================
        if (user.canManageAttendanceQr) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1B2E36)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      user.isAdmin ? 'Módulo de Administración IIAP' : 'Módulo de Supervisor Autorizado',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF176044)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _handleGenerarQr(context, user),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: const Text(
                          'Proyectar QR',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (user.isAdmin) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA78BFA),
                            side: const BorderSide(color: Color(0xFF5B21B6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _handleEscanearAsistenciaFacial(context),
                          icon: const Icon(Icons.face_retouching_natural_rounded, size: 18),
                          label: const Text(
                            'Facial IA',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEventsSection(BuildContext context, UserModel user) {
    return ValueListenableBuilder<List<EventModel>>(
      valueListenable: EventService.eventsNotifier,
      builder: (context, events, _) {
        final activeOrUpcoming =
            events.where((e) => e.endDate.isAfter(DateTime.now()) || e.isActiveNow).toList();
        final featuredEvent = activeOrUpcoming.isNotEmpty
            ? activeOrUpcoming.first
            : (events.isNotEmpty ? events.first : null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header de sección: 📅 EVENTOS INSTITUCIONALES  -  Ver todos >
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_note_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'EVENTOS INSTITUCIONALES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EventsListScreen()),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver todos',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF10B981)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Card del Evento Destacado
            if (featuredEvent != null) ...[
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: featuredEvent),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D21),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: featuredEvent.isActiveNow
                          ? const Color(0xFF10B981).withValues(alpha: 0.7)
                          : const Color(0xFF1F323A),
                      width: featuredEvent.isActiveNow ? 1.5 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges: [ REUNIÓN ]  [ Próximo ]  -  Prioridad Alta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E382E),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF165942)),
                                ),
                                child: Text(
                                  featuredEvent.type.displayName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: featuredEvent.isActiveNow
                                      ? const Color(0xFF0F3224)
                                      : const Color(0xFF38290E),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: featuredEvent.isActiveNow
                                        ? const Color(0xFF176044)
                                        : const Color(0xFF6B450B),
                                  ),
                                ),
                                child: Text(
                                  featuredEvent.isActiveNow ? 'En curso' : 'Próximo',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: featuredEvent.isActiveNow
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Prioridad Alta',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFBBF24),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Título del evento
                      Text(
                        featuredEvent.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Descripción
                      if (featuredEvent.description.isNotEmpty) ...[
                        Text(
                          featuredEvent.description,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF8FA3AF),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Ubicación
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              featuredEvent.location,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFCBD5E1),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Horario y Duración
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatEventDateAndDuration(featuredEvent),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFCBD5E1),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Fila inferior: Avatares solapados + X registrados oficialmente  -  Ver detalle ➔
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildAttendeeAvatars(featuredEvent.attendees),
                              const SizedBox(width: 8),
                              Text(
                                '${featuredEvent.attendees.length} registrados oficialmente',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver detalle',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 14),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D21),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1F323A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.event_available_rounded, size: 24, color: Color(0xFF10B981)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay eventos programados en este momento.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF8FA3AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (user.canManageEvents) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF176044)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final created = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                  );
                  if (created == true) {
                    EventService.getEvents();
                  }
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                label: const Text(
                  'Crear Nuevo Evento Institucional',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAttendeeAvatars(List<EventAttendeeModel> attendees) {
    if (attendees.isEmpty) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2A30),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF263C45)),
        ),
        child: const Icon(Icons.people_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
      );
    }

    final displayList = attendees.take(2).toList();
    final remaining = attendees.length - displayList.length;

    final colors = [
      const Color(0xFF5EEAD4), // Teal
      const Color(0xFF6EE7B7), // Mint
    ];

    return SizedBox(
      height: 24,
      width: (displayList.length * 16.0) + (remaining > 0 ? 24.0 : 8.0),
      child: Stack(
        children: [
          for (int i = 0; i < displayList.length; i++)
            Positioned(
              left: i * 14.0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF131D21), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(displayList[i].userName),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayList.length * 14.0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF263C45),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF131D21), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MÓDULO BIOMÉTRICO FACIAL (INSIGHTFACE) PARA ADMINISTRADORES
  // ===========================================================================

  void _handleEscanearAsistenciaFacial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.face_retouching_natural_rounded,
                        color: Color(0xFF7C3AED),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control Biométrico Facial',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'InsightFace ArcFace (buffalo_l) + OpenCV',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF7C3AED)),
                      tooltip: 'Configurar IP del Servidor Facial',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showFacialServiceConfigDialog(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Tomar Foto con este Dispositivo (iPad / Móvil)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                      'Usa la cámara frontal/trasera para capturar el rostro y validarlo con InsightFace',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturePhotoAndScanFacial();
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.desktop_windows_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Escanear en Estación PC (Webcam en vivo)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                      'Activa la cámara física conectada al computador para escaneo continuo con OpenCV',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showWebcamHUDDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWebcamHUDDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF7C3AED)),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Iniciando cámara con InsightFace...\nPor favor ubica tu rostro frente al visor.',
                style: TextStyle(fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final res = await AttendanceService.scanAttendanceWebcam();
      if (!mounted) return;
      Navigator.of(context).pop();

      if (res['success'] == true && res['matched'] == true) {
        final detectedName = res['user']?['name']?.toString() ??
            res['user']?['full_name']?.toString() ??
            'Colaborador Reconocido';
        _showFacialSuccessDialog(
          userName: detectedName,
          similarity: (res['similarity_percent'] ?? 85.0).toDouble(),
          timestamp: DateTime.now().toString(),
        );
        _fetchTodayAttendance();
      } else {
        _showFacialErrorDialog(
          res['message'] ?? 'No se identificó ningún rostro con la coincidencia requerida.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showFacialErrorDialog('Error al conectar con la cámara: $e');
    }
  }

  Future<void> _capturePhotoAndScanFacial() async {
    final nav = Navigator.of(context);
    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (photo == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF7C3AED)),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Procesando vector con InsightFace...',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      );

      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);

      final res = await AttendanceService.scanAttendanceImage(base64Image);
      if (!mounted) return;
      nav.pop();

      if (res['success'] == true && res['matched'] == true) {
        final detectedName = res['user']?['name']?.toString() ??
            res['user']?['full_name']?.toString() ??
            'Colaborador Reconocido';
        _showFacialSuccessDialog(
          userName: detectedName,
          similarity: (res['similarity_percent'] ?? 85.0).toDouble(),
          timestamp: DateTime.now().toString(),
        );
        _fetchTodayAttendance();
      } else {
        _showFacialErrorDialog(
          res['message'] ?? 'Rostro no coincide con ningún colaborador registrado.',
        );
      }
    } catch (e) {
      if (mounted) {
        nav.pop();
        _showFacialErrorDialog('Error al capturar imagen: $e');
      }
    }
  }

  void _showFacialSuccessDialog({
    required String userName,
    required double similarity,
    required String timestamp,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFD1FAE5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 44),
        ),
        title: const Text(
          '¡Asistencia Registrada!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Coincidencia Biométrica: ${similarity.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'La asistencia fue validada con InsightFace y registrada en el sistema.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFacialErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFFFEE2E2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
        ),
        title: const Text(
          'Aviso de Escaneo Facial',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showFacialServiceConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiConfig.facialServiceBaseUrl);
    String? statusMessage;
    bool isChecking = false;
    bool? isOnline;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF7C3AED)),
                  SizedBox(width: 10),
                  Text('Configuración Facial', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dirección IP del Servicio Facial (Python / FastAPI):',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.214:8000',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (isChecking)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                    else if (statusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isOnline == true ? Colors.green : Colors.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isOnline == true ? Colors.green : Colors.red),
                        ),
                        child: Row(
                          children: [
                            Icon(isOnline == true ? Icons.check_circle_rounded : Icons.error_rounded,
                                color: isOnline == true ? Colors.green : Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOnline == true ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: isChecking
                          ? null
                          : () async {
                              setDialogState(() {
                                isChecking = true;
                                statusMessage = null;
                              });
                              try {
                                final testUrl = Uri.parse('${controller.text.trim()}/api/status');
                                final res = await http.get(testUrl).timeout(const Duration(seconds: 5));
                                if (res.statusCode == 200) {
                                  final data = jsonDecode(res.body);
                                  setDialogState(() {
                                    isChecking = false;
                                    isOnline = true;
                                    statusMessage =
                                        'Conexión exitosa. Enrolados: ${data['enrolled_users_count'] ?? 1}';
                                  });
                                } else {
                                  setDialogState(() {
                                    isChecking = false;
                                    isOnline = false;
                                    statusMessage = 'El servidor respondió con código ${res.statusCode}';
                                  });
                                }
                              } catch (e) {
                                setDialogState(() {
                                  isChecking = false;
                                  isOnline = false;
                                  statusMessage =
                                      'No se pudo conectar ($e).\nVerifica la IP y que Windows Firewall permita el puerto 8000.';
                                });
                              }
                            },
                      icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                      label: const Text('Probar Conexión', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size.fromHeight(38),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await ApiConfig.setCustomFacialBaseUrl(controller.text.trim());
                    if (context.mounted) Navigator.pop(dlgCtx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
