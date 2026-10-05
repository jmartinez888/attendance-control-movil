import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/supervisors_tab.dart';
import 'tabs/profile_tab.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../utils/responsive.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Set<int> _activatedTabs = {0};
  Timer? _syncTimer;
  bool _isSyncing = false;

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _activatedTabs.add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSyncTimer();
    NotificationService.checkAndTriggerCheckoutReminder();

    // Sesión persistente offline-first:
    // El usuario ya ve y usa la app de inmediato con sus datos locales.
    // En segundo plano verificamos y refrescamos el token con el backend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateSessionInBackground();
    });
  }

  Future<void> _validateSessionInBackground() async {
    try {
      final isValid = await AuthService.validateSessionInBackground();
      if (!isValid && mounted) {
        // Solo si el backend rechazó la sesión explícitamente (401 definitivo) y no hay re-login:
        _syncTimer?.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu sesión ha expirado o tus credenciales cambiaron. Por favor ingresa de nuevo.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // Ignorar errores transitorios de red para no botar al usuario offline
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSyncTimer();
      _syncProfile();
      _validateSessionInBackground();
      NotificationService.checkAndTriggerCheckoutReminder();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _syncTimer?.cancel();
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    // Intervalo saludable de 45 segundos para sincronizar rol y estado sin saturar
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _syncProfile();
    });
  }

  Future<void> _syncProfile() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      NotificationService.checkAndTriggerCheckoutReminder();
      final oldUser = StorageService.currentUser;
      final newUser = await AuthService.getProfile();
      if (!mounted) return;

      final wasSupervisor = oldUser?.isSupervisor == true;
      final isNowSupervisor = newUser.isSupervisor == true;
      final wasAdmin = oldUser?.isAdmin == true;
      final isNowAdmin = newUser.isAdmin == true;

      // 1. Detectar revocación de cargo de supervisor en tiempo real
      if (wasSupervisor && !isNowSupervisor && !isNowAdmin) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu cargo de supervisor ha concluido. Has pasado automáticamente a tu usuario normal (Personal).',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (!wasSupervisor && !wasAdmin && isNowSupervisor) {
        // 2. Detectar asignación de supervisor en segundo plano
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¡Ahora eres Supervisor! Se han habilitado tus permisos para generar QR.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // Silencioso: la sesión se mantiene intacta bajo cualquier circunstancia
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: StorageService.currentUserNotifier,
      builder: (context, user, _) {
        final currentUser = user ?? StorageService.currentUser;
        final isAdmin = currentUser?.isAdmin == true;
        final canManageStaff = currentUser?.canManageAttendanceQr == true;

        final List<Widget> pages = [
          DashboardTab(onNavigateToHistory: () => _selectTab(1)),
          _activatedTabs.contains(1) ? const AttendanceTab() : const SizedBox.shrink(),
          if (canManageStaff)
            _activatedTabs.contains(2) ? const SupervisorsTab() : const SizedBox.shrink(),
          _activatedTabs.contains(canManageStaff ? 3 : 2) ? const ProfileTab() : const SizedBox.shrink(),
        ];

        final List<NavigationDestination> destinations = [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.access_time_rounded),
            selectedIcon: Icon(Icons.access_time_filled_rounded),
            label: 'Asistencias',
          ),
          if (canManageStaff)
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups_rounded),
              label: isAdmin ? 'Personal' : 'Horarios',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ];

        // Asegurar que el índice no sobrepase si cambia el rol
        final safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;
        final isDesktop = Responsive.isDesktop(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // VISTA ESCRITORIO (Windows, macOS, Web, Pantallas anchas): Sidebar lateral NavigationRail
        if (isDesktop) {
          final isWide = Responsive.isWideScreen(context);
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: isWide ? 210 : 72,
                  color: ThemeService.cardBg(context),
                  child: Column(
                    children: [
                      Expanded(
                        child: NavigationRail(
                          selectedIndex: safeIndex,
                          onDestinationSelected: _selectTab,
                          backgroundColor: Colors.transparent,
                          indicatorColor: ThemeService.containerColor(context),
                          extended: isWide,
                          minWidth: 72,
                          minExtendedWidth: 210,
                          elevation: 0,
                          leading: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: ThemeService.primaryColor(context).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.fingerprint_rounded,
                                    color: ThemeService.primaryColor(context),
                                    size: 26,
                                  ),
                                ),
                                if (isWide) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'IIAP Asistencia',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          currentUser?.fullName ?? '',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          destinations: destinations.map((d) {
                            return NavigationRailDestination(
                              icon: d.icon,
                              selectedIcon: d.selectedIcon ?? d.icon,
                              label: Text(
                                d.label,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            );
                          }).toList(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20, top: 8),
                        child: Center(
                          child: Tooltip(
                            message: 'Ver mi Perfil (${currentUser?.fullName ?? ""})',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                _selectTab(pages.length - 1);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: ThemeService.primaryColor(context),
                                  backgroundImage: (currentUser?.photoUrl != null &&
                                          currentUser!.photoUrl!.isNotEmpty)
                                      ? NetworkImage(currentUser.photoUrl!)
                                      : null,
                                  child: (currentUser?.photoUrl == null ||
                                          currentUser!.photoUrl!.isEmpty)
                                      ? Text(
                                          (currentUser?.fullName.isNotEmpty == true
                                                  ? currentUser!.fullName[0]
                                                  : 'U')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: safeIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          );
        }

        // VISTA MÓVIL (Celulares): BottomNavigationBar estándar
        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: _selectTab,
            backgroundColor: ThemeService.cardBg(context),
            indicatorColor: ThemeService.containerColor(context),
            elevation: 2,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
