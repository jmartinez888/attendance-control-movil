import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/qr_model.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../services/attendance_service.dart';
import '../../services/users_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../widgets/qr_countdown_timer.dart';
import '../../widgets/app_button.dart';

enum QrMode {
  attendance,
  supervisorAssignment,
  roleAssignment,
}

class QrDisplayScreen extends StatefulWidget {
  final QrMode mode;
  final String? targetRole;
  final String? targetEventId;
  final String? customTitle;
  final String? customSubtitle;
  final int? availableSlots;
  final int? maxSupervisors;

  const QrDisplayScreen({
    super.key,
    this.mode = QrMode.attendance,
    this.targetRole,
    this.targetEventId,
    this.customTitle,
    this.customSubtitle,
    this.availableSlots,
    this.maxSupervisors,
  });

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  QrGeneratedResponse? _qrData;
  bool _isLoading = true;
  bool _isGeneratingNew = false;
  bool _justRotated = false;
  String? _errorMessage;
  Timer? _pollingTimer;
  Timer? _rotationResetTimer;
  bool _isProjectorMode = false;
  int? _availableSlots;
  int? _maxSupervisors;

  @override
  void initState() {
    super.initState();
    _availableSlots = widget.availableSlots;
    _maxSupervisors = widget.maxSupervisors;
    if (widget.mode == QrMode.attendance && AttendanceService.lastActiveQr != null) {
      _qrData = AttendanceService.lastActiveQr;
      _isLoading = false;
    }
    StorageService.currentUserNotifier.addListener(_onUserRoleChanged);
    _loadQr(forceNew: false);
    _startPolling();
  }

  @override
  void dispose() {
    StorageService.currentUserNotifier.removeListener(_onUserRoleChanged);
    _pollingTimer?.cancel();
    _rotationResetTimer?.cancel();
    super.dispose();
  }

  void _onUserRoleChanged() {
    final user = StorageService.currentUser;
    // Si al usuario se le revoca el cargo mientras tiene abierta la pantalla de QR, salir de inmediato
    if (user != null && widget.mode == QrMode.attendance && !user.canManageAttendanceQr) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _startPolling() {
    // Sondeo balanceado cada 3.5 segundos para rotación al escaneo sin saturar la red
    if (widget.mode == QrMode.attendance) {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) => _checkForRotatedQr());
    }
  }

  Future<void> _checkForRotatedQr() async {
    if (!mounted || _isLoading || _isGeneratingNew || _qrData == null) return;
    try {
      final active = await AttendanceService.getActiveAttendanceQr();
      if (mounted && active.qrCode != _qrData?.qrCode) {
        HapticFeedback.heavyImpact();
        _rotationResetTimer?.cancel();

        setState(() {
          _qrData = active;
          _justRotated = true;
        });

        _rotationResetTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _justRotated = false);
          }
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Código QR renovado! Un colaborador acaba de registrar su asistencia.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 403) {
        try {
          await AuthService.getProfile();
        } catch (_) {}
      }
    } catch (_) {
      // Ignorar errores silenciosos en sondeo de fondo
    }
  }

  Future<void> _loadQr({bool forceNew = false}) async {
    if (!mounted) return;
    setState(() {
      if (forceNew) {
        _isGeneratingNew = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      QrGeneratedResponse response;
      if (widget.mode == QrMode.attendance) {
        response = forceNew
            ? await AttendanceService.generateAttendanceQr()
            : await AttendanceService.getActiveAttendanceQr();
      } else if (widget.mode == QrMode.roleAssignment) {
        final res = await AttendanceService.generateAssignmentQr(
          targetRole: widget.targetRole ?? 'ADMIN',
          targetEventId: widget.targetEventId,
        );
        response = QrGeneratedResponse.fromJson(res);
      } else {
        response = await AttendanceService.generateSupervisorQr();
      }

      // Consultar cupos de supervisores en tiempo real si corresponde
      if (widget.mode == QrMode.supervisorAssignment || widget.targetRole == 'SUPERVISOR') {
        try {
          final supData = await UsersService.getSupervisors();
          if (supData.isNotEmpty) {
            final list = supData['supervisors'] is List ? (supData['supervisors'] as List) : [];
            final totalCount = (supData['total'] is int)
                ? supData['total'] as int
                : (supData['current_count'] is int ? supData['current_count'] as int : list.length);
            final maxSup = (supData['max_limit'] is int)
                ? supData['max_limit'] as int
                : (supData['max_supervisors'] is int ? supData['max_supervisors'] as int : 3);
            final avail = (supData['available_slots'] is int)
                ? supData['available_slots'] as int
                : (maxSup - totalCount).clamp(0, maxSup);
            if (mounted) {
              setState(() {
                _availableSlots = avail;
                _maxSupervisors = maxSup;
              });
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _qrData = response;
          _isLoading = false;
          _isGeneratingNew = false;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 403) {
        try {
          await AuthService.getProfile();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
          _isGeneratingNew = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar código QR: $e';
          _isLoading = false;
          _isGeneratingNew = false;
        });
      }
    }
  }

  void _copyHashToClipboard() {
    if (_qrData == null) return;
    Clipboard.setData(ClipboardData(text: _qrData!.qrCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hash SHA-256 copiado:\n${_qrData!.qrCode.substring(0, 24)}...',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = StorageService.currentUser;

    final isAttendance = widget.mode == QrMode.attendance;
    final String title;
    final String subtitle;
    if (widget.customTitle != null) {
      title = widget.customTitle!;
      subtitle = widget.customSubtitle ?? 'Escanear para confirmar designación';
    } else if (widget.mode == QrMode.roleAssignment) {
      final roleText = widget.targetRole != null ? UserRole.fromString(widget.targetRole).displayName : 'Designación';
      title = 'Designar $roleText';
      subtitle = widget.customSubtitle ?? 'El usuario debe escanear este QR con su app';
    } else if (isAttendance) {
      title = 'Generador de Código QR';
      subtitle = 'Válido por 5 minutos • Renovación por escaneo';
    } else {
      title = 'Designar Supervisor';
      subtitle = 'Válido por 10 minutos • Límite institucional';
    }

    if (_isProjectorMode) {
      return _buildProjectorView(context, title, subtitle);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 780;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: 'Modo Proyector / Pantalla Completa',
            onPressed: () {
              setState(() => _isProjectorMode = true);
            },
          ),
          IconButton(
            icon: _isGeneratingNew
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Generar nuevo QR SHA',
            onPressed: (_isLoading || _isGeneratingNew) ? null : () => _loadQr(forceNew: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : (screenWidth < 360 ? 14 : 20),
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 960 : 440,
              ),
              child: isWide
                  ? _buildTwoColumnLayout(context, isDark, isAttendance, title, subtitle, currentUser)
                  : _buildSingleColumnLayout(context, isDark, isAttendance, title, subtitle, currentUser),
            ),
          ),
        ),
      ),
    );
  }

  /// Vista de 1 columna: Celulares Android y iPhones
  Widget _buildSingleColumnLayout(
    BuildContext context,
    bool isDark,
    bool isAttendance,
    String title,
    String subtitle,
    UserModel? currentUser,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildHeaderBanner(isDark, isAttendance, subtitle),
        if (!isAttendance) ...[
          const SizedBox(height: 14),
          _buildQuotaBanner(isDark),
        ],
        const SizedBox(height: 18),
        _buildRotatedBadge(),
        _buildQrCard(context, isDark),
        const SizedBox(height: 18),
        if (_qrData != null && !_isLoading && _errorMessage == null) ...[
          _buildTimerCard(isDark),
          const SizedBox(height: 12),
          _buildIssuerBadge(isDark, currentUser),
          const SizedBox(height: 18),
          _buildRegenerateButton(),
        ],
      ],
    );
  }

  /// Vista de 2 columnas: Tablets Android, iPads, Laptops y Monitores
  Widget _buildTwoColumnLayout(
    BuildContext context,
    bool isDark,
    bool isAttendance,
    String title,
    String subtitle,
    UserModel? currentUser,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Columna Izquierda: Información, Temporizador, Controles
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderBanner(isDark, isAttendance, subtitle),
              if (!isAttendance) ...[
                const SizedBox(height: 14),
                _buildQuotaBanner(isDark),
              ],
              const SizedBox(height: 18),
              if (_qrData != null && !_isLoading && _errorMessage == null) ...[
                _buildTimerCard(isDark),
                const SizedBox(height: 14),
                _buildIssuerBadge(isDark, currentUser),
                const SizedBox(height: 18),
                _buildRegenerateButton(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => setState(() => _isProjectorMode = true),
                  icon: const Icon(Icons.tv_rounded, size: 20),
                  label: const Text(
                    'Proyectar en Pantalla Gigante',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Columna Derecha: Código QR Ampliado
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildRotatedBadge(),
              _buildQrCard(context, isDark),
            ],
          ),
        ),
      ],
    );
  }

  /// Tarjeta de Cupos / Disponibilidad de Roles
  Widget _buildQuotaBanner(bool isDark) {
    if (widget.mode == QrMode.attendance) return const SizedBox.shrink();

    final isSupervisor = widget.mode == QrMode.supervisorAssignment || widget.targetRole == 'SUPERVISOR';

    if (isSupervisor) {
      final avail = _availableSlots ?? 2;
      final max = _maxSupervisors ?? 3;
      final hasSlots = avail > 0;
      final color = hasSlots ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shield_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cupos de Supervisores',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color),
                        ),
                        child: Text(
                          '$avail de $max',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasSlots
                        ? 'Disponibles: $avail de $max'
                        : 'Sin cupos disponibles (0 de $max)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Para Admin de Eventos / UO y Gestor de Eventos / UO (Sin límite)
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.4 : 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.all_inclusive_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cupos para este Rol',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2563EB)),
                      ),
                      child: const Text(
                        'Sin límite',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'No tiene límite de designaciones para esta sede',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner superior descriptivo
  Widget _buildHeaderBanner(bool isDark, bool isAttendance, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF16A34A),
              size: 28,
            ),
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
                        isAttendance
                            ? 'Toma de Asistencia'
                            : (widget.mode == QrMode.roleAssignment ? 'Designación de Rol' : 'Designación'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'SHA-256',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Badge animado de rotación
  Widget _buildRotatedBadge() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _justRotated
          ? Container(
              key: const ValueKey('rotated_badge'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.autorenew_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '¡NUEVO QR GENERADO TRAS ESCANEO!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  /// Tarjeta del código QR
  Widget _buildQrCard(BuildContext context, bool isDark) {
    final qrSize = Responsive.qrDisplaySize(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _justRotated ? const Color(0xFF16A34A) : Colors.transparent,
          width: _justRotated ? 3.5 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: _justRotated
                ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: _justRotated ? 24 : 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _isLoading
          ? SizedBox(
              height: qrSize + 20,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Generando código QR con SHA-256...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          : _errorMessage != null
              ? SizedBox(
                  height: 250,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          text: 'Reintentar',
                          height: 40,
                          width: 130,
                          onPressed: () => _loadQr(forceNew: true),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: QrImageView(
                        key: ValueKey(_qrData!.qrCode),
                        data: _qrData!.qrCode,
                        version: QrVersions.auto,
                        size: qrSize,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF475569)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'SHA: ${_qrData!.qrCode.length >= 18 ? "${_qrData!.qrCode.substring(0, 18)}..." : _qrData!.qrCode}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _copyHashToClipboard,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Tarjeta de temporizador
  Widget _buildTimerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: QrCountdownTimer(
        expiresAt: _qrData!.expiresAt,
        onExpired: () => _loadQr(forceNew: true),
      ),
    );
  }

  /// Badge de emisor
  Widget _buildIssuerBadge(bool isDark, UserModel? currentUser) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            currentUser?.isAdmin == true
                ? Icons.admin_panel_settings_rounded
                : Icons.security_rounded,
            size: 16,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Emisor: ${currentUser?.fullName ?? "Supervisor"} (${currentUser?.role.displayName ?? "Supervisor"})',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón de regeneración
  Widget _buildRegenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isGeneratingNew ? null : () => _loadQr(forceNew: true),
        icon: _isGeneratingNew
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.autorenew_rounded, size: 20),
        label: Text(
          _isGeneratingNew ? 'Generando nuevo SHA...' : 'Generar Nuevo QR (SHA)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  /// Vista de Pantalla Completa / Proyector (Monitores, Proyectores, iPads en Atril)
  Widget _buildProjectorView(BuildContext context, String title, String subtitle) {
    final projectorQrSize = Responsive.qrDisplaySize(context, isProjectorMode: true);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Institucional de Proyección
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Color(0xFF22C55E), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SHA-256',
                              style: TextStyle(
                                color: Color(0xFF22C55E),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // QR Gigante de Alta Nitidez
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: _qrData != null
                          ? QrImageView(
                              key: ValueKey('proj_${_qrData!.qrCode}'),
                              data: _qrData!.qrCode,
                              version: QrVersions.auto,
                              size: projectorQrSize,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF0F172A),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),

                    // Temporizador en modo proyector
                    if (_qrData != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: QrCountdownTimer(
                          expiresAt: _qrData!.expiresAt,
                          onExpired: () => _loadQr(forceNew: true),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Botón Salir de Modo Proyector
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                tooltip: 'Salir de Pantalla Completa',
                onPressed: () => setState(() => _isProjectorMode = false),
                child: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
