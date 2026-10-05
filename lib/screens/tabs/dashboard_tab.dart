import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../services/attendance_service.dart';
import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../qr/qr_display_screen.dart';
import '../qr/qr_scanner_screen.dart';
import '../events/events_list_screen.dart';
import '../events/create_event_screen.dart';
import '../events/event_detail_screen.dart';
import '../../services/event_service.dart';
import '../../models/event_model.dart';
import '../../services/theme_service.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/leaf_logo.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;

  const DashboardTab({
    super.key,
    this.onNavigateToHistory,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    EventService.getEvents();
  }

  void _handleGenerarQr(BuildContext context, UserModel user) {
    if (user.canManageAttendanceQr) {
      // Admin o alguno de los 3 Supervisores
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const QrDisplayScreen(mode: QrMode.attendance),
        ),
      );
    } else {
      // Usuario regular (Empleado)
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
            'La función Generar QR con cifrado SHA-256 está reservada exclusivamente para el Administrador y los 3 Supervisores autorizados para la toma de asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeService.primaryColor(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
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
    if (res == true) {
      EventService.getEvents();
    }
  }

  String _getRoleShortName(UserRole role) {
    switch (role) {
      case UserRole.SUPERADMIN:
        return 'SUPERADMIN';
      case UserRole.ADMIN:
        return 'ADMIN';
      case UserRole.ADMIN_EVENTO:
        return 'ADMIN EVENTO';
      case UserRole.GESTOR_EVENTO:
        return 'GESTOR EVENTO';
      case UserRole.SUPERVISOR:
        return 'SUPERVISOR';
      case UserRole.USER:
        return 'USER';
    }
  }

  String _getUserSubtitle(UserModel user) {
    if (user.isSuperAdmin) return 'Super Administrador';
    if (user.isAdmin) return 'Admin IIAP';
    if (user.isAdminEvento) return 'Admin Evento / UO';
    if (user.isGestorEvento) return 'Gestor Evento / UO';
    if (user.isSupervisor) return 'Supervisor';
    return 'Usuario';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, rawUser, _) {
        final user = rawUser ?? StorageService.currentUser;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final roleColor = (user.isAdmin || user.isSuperAdmin)
            ? const Color(0xFFDC2626)
            : (user.isSupervisor || user.isAdminEvento ? const Color(0xFFD97706) : const Color(0xFF16A34A));

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await AuthService.getProfile();
              await EventService.getEvents();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Responsive.constrained(
                context,
                maxTabletWidth: 920,
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de Bienvenida y Rol
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: ThemeService.bannerGradient(context),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeService.primaryColor(context).withValues(alpha: isDark ? 0.2 : 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: roleColor.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.isAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : (user.isSupervisor ? Icons.security_rounded : Icons.person_rounded),
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _getRoleShortName(user.role),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ValueListenableBuilder<bool>(
                            valueListenable: ConnectivityService.isOnlineNotifier,
                            builder: (context, isOnline, _) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOnline
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : const Color(0xFFEF4444).withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: isOnline ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                                      size: 7,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOnline ? 'En línea' : 'Desconectado',
                                      style: TextStyle(
                                        color: isOnline ? Colors.white : const Color(0xFFFEE2E2),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const LeafLogo(size: 38),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hola, ${user.fullName}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getUserSubtitle(user),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Sección de Botones Principales: Generar QR y Escanear QR
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Control de Asistencia',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'SHA-256',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ACCIONES CONDICIONALES POR ROL:
                // - Administrador: SOLO botón "Generar QR"
                // - Supervisores: AMBOS botones ("Generar QR" y "Escanear QR" para marcar su propia asistencia)
                // - Personal regular: SOLO botón "Escanear QR"
                if (user.isSupervisor && Responsive.isTablet(context)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          title: 'Generar QR de Asistencia',
                          subtitle: 'Emisión con cifrado SHA-256 (Rotación automática)',
                          icon: Icons.qr_code_2_rounded,
                          color: const Color(0xFF16A34A),
                          badgeText: 'SHA-256',
                          badgeColor: const Color(0xFF16A34A),
                          isLocked: false,
                          onTap: () => _handleGenerarQr(context, user),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          title: 'Escanear QR',
                          subtitle: 'Registra tu asistencia escaneando el QR institucional',
                          icon: Icons.qr_code_scanner_rounded,
                          color: const Color(0xFF2563EB),
                          badgeText: 'CÁMARA',
                          badgeColor: const Color(0xFF2563EB),
                          isLocked: false,
                          onTap: () => _handleEscanearQr(context),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  if (user.canManageAttendanceQr) ...[
                    _buildActionCard(
                      context,
                      title: 'Generar QR de Asistencia',
                      subtitle: 'Emisión institucional con cifrado SHA-256 (Rotación automática)',
                      icon: Icons.qr_code_2_rounded,
                      color: const Color(0xFF16A34A),
                      badgeText: 'SHA-256',
                      badgeColor: const Color(0xFF16A34A),
                      isLocked: false,
                      onTap: () => _handleGenerarQr(context, user),
                    ),
                    if (user.isSupervisor) const SizedBox(height: 12),
                    if (user.isAdmin) ...[
                      const SizedBox(height: 12),
                      _buildActionCard(
                        context,
                        title: 'Escanear Asistencia',
                        subtitle: 'Reconocimiento biométrico facial con cámara (InsightFace)',
                        icon: Icons.face_retouching_natural_rounded,
                        color: const Color(0xFF7C3AED),
                        badgeText: 'BIOMETRÍA',
                        badgeColor: const Color(0xFF7C3AED),
                        isLocked: false,
                        onTap: () => _handleEscanearAsistenciaFacial(context),
                      ),
                    ],
                  ],
                  if (!user.isAdmin) ...[
                    _buildActionCard(
                      context,
                      title: 'Escanear QR',
                      subtitle: 'Registra tu asistencia escaneando el código QR institucional',
                      icon: Icons.qr_code_scanner_rounded,
                      color: const Color(0xFF2563EB),
                      badgeText: 'CÁMARA',
                      badgeColor: const Color(0xFF2563EB),
                      isLocked: false,
                      onTap: () => _handleEscanearQr(context),
                    ),
                  ],
                ],

                const SizedBox(height: 22),

                // Sección Eventos Institucionales
                _buildEventsSection(context, user),

                const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    required Color badgeColor,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeService.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ThemeService.cardBorder(context),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLocked ? Icons.lock_outline_rounded : Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canCreate = user.canManageAttendanceQr;

    return ValueListenableBuilder<List<EventModel>>(
      valueListenable: EventService.eventsNotifier,
      builder: (context, events, _) {
        final activeOrUpcoming = events.where((e) => e.endDate.isAfter(DateTime.now()) || e.isActiveNow).toList();
        final featuredEvent = activeOrUpcoming.isNotEmpty ? activeOrUpcoming.first : (events.isNotEmpty ? events.first : null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Eventos Institucionales',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (activeOrUpcoming.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: ThemeService.primaryColor(context).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${activeOrUpcoming.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ThemeService.primaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EventsListScreen()),
                    );
                  },
                  child: const Text('Ver Todos', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (featuredEvent != null) ...[
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: featuredEvent),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeService.cardBg(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: featuredEvent.isActiveNow
                          ? const Color(0xFF16A34A).withValues(alpha: 0.6)
                          : ThemeService.cardBorder(context),
                      width: featuredEvent.isActiveNow ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ThemeService.primaryColor(context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_note_rounded, size: 12, color: ThemeService.primaryColor(context)),
                                const SizedBox(width: 4),
                                Text(
                                  featuredEvent.type.displayName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeService.primaryColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: featuredEvent.isActiveNow
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                  : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: featuredEvent.isActiveNow ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  featuredEvent.isActiveNow ? 'En curso' : 'Próximo',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: featuredEvent.isActiveNow ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        featuredEvent.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: ThemeService.subtextColor(context)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              featuredEvent.location,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: ThemeService.subtextColor(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${featuredEvent.attendees.length} registrados',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: ThemeService.primaryColor(context),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver detalle',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeService.subtextColor(context),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 15, color: ThemeService.subtextColor(context)),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeService.cardBg(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeService.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available_rounded, size: 26, color: ThemeService.primaryColor(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay eventos programados en este momento.',
                        style: TextStyle(fontSize: 12.5, color: ThemeService.subtextColor(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (canCreate) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                    color: ThemeService.primaryColor(context).withValues(alpha: 0.5),
                  ),
                ),
                onPressed: () async {
                  final created = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                  );
                  if (created == true) {
                    EventService.getEvents();
                  }
                },
                icon: Icon(Icons.add_circle_outline_rounded, size: 18, color: ThemeService.primaryColor(context)),
                label: Text(
                  'Crear Nuevo Evento Institucional',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: ThemeService.primaryColor(context),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

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
                  title: const Text('Tomar Foto con este Dispositivo (iPad / Móvil)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Usa la cámara frontal/trasera del iPad para capturar el rostro y validarlo con InsightFace', style: TextStyle(fontSize: 12)),
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
                  title: const Text('Escanear en Estación PC (Webcam en vivo)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Activa la cámara física conectada al computador para escaneo continuo con OpenCV', style: TextStyle(fontSize: 12)),
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
                      const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
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
                                    statusMessage = 'Conexión exitosa. Enrolados: ${data['enrolled_users_count'] ?? 1}';
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
                                  statusMessage = 'No se pudo conectar ($e).\nVerifica la IP y que Windows Firewall permita el puerto 8000.';
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
