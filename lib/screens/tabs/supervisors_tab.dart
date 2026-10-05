import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../models/user_model.dart';
import '../../models/schedule_model.dart';
import '../../services/users_service.dart';
import '../../services/storage_service.dart';
import '../../services/schedule_service.dart';
import '../../services/attendance_service.dart';
import '../../services/api_client.dart';
import '../qr/qr_display_screen.dart';
import '../../services/theme_service.dart';

class SupervisorsTab extends StatefulWidget {
  const SupervisorsTab({super.key});

  @override
  State<SupervisorsTab> createState() => _SupervisorsTabState();
}

class _SupervisorsTabState extends State<SupervisorsTab> {
  bool _isLoading = true;
  int _activeSupervisorsCount = 0;
  int _maxSupervisors = 3;
  int _availableSlots = 3;
  List<UserModel> _allUsers = [];
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = StorageService.currentUser;
    final isAdmin = currentUser?.isAdmin == true;

    try {
      final supFuture = isAdmin
          ? UsersService.getSupervisors().catchError((_) => <String, dynamic>{})
          : Future.value(<String, dynamic>{});
      final usersFuture = UsersService.findAll().catchError((_) async {
        try {
          final records = await AttendanceService.getAllRecords();
          final Map<String, UserModel> map = {};
          for (final r in records) {
            if (r.userId.isNotEmpty && !map.containsKey(r.userId)) {
              map[r.userId] = UserModel(
                id: r.userId,
                email: r.userEmail ?? '',
                fullName: r.userName ?? 'Colaborador',
                role: UserRole.USER,
              );
            }
          }
          return map.values.toList();
        } catch (_) {
          return <UserModel>[];
        }
      });

      final results = await Future.wait([supFuture, usersFuture]);
      final supData = results[0] as Map<String, dynamic>;
      final usersData = results[1] as List<UserModel>;

      if (isAdmin && supData.isNotEmpty) {
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

        _activeSupervisorsCount = totalCount;
        _maxSupervisors = maxSup;
        _availableSlots = avail;
      }

      if (mounted) {
        setState(() {
          _allUsers = usersData;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar personal: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeUserRole(UserModel targetUser, UserRole newRole) async {
    try {
      await UsersService.assignRole(targetUser.id, newRole);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rol de ${targetUser.fullName} actualizado a ${newRole.displayName}.'),
          backgroundColor: ThemeService.primaryColor(context),
        ),
      );
      _loadData();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFEF4444)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar rol: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _confirmDeleteUser(UserModel targetUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cuenta'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la cuenta de ${targetUser.fullName} (${targetUser.email})?\n\nEsta acción permitirá que el usuario pueda registrarse nuevamente desde cero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, Eliminar Cuenta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UsersService.deleteUser(targetUser.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta de ${targetUser.fullName} eliminada exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFEF4444)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar cuenta: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _confirmUnbindDevice(UserModel targetUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phonelink_erase_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 8),
            Text('Desvincular Dispositivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Deseas desvincular el celular registrado para ${targetUser.fullName}?\n\n'
          'Esto permitirá que el colaborador pueda registrar su asistencia desde un nuevo teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, Desvincular', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UsersService.unbindDevice(targetUser.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispositivo de ${targetUser.fullName} desvinculado con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFEF4444)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al desvincular dispositivo: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Widget _buildAdminUserActions(UserModel u) {
    final current = StorageService.currentUser;
    final isSuperAdmin = current?.isSuperAdmin == true;
    final isAdmin = current?.isAdmin == true;

    // Si es SuperAdmin, no puede ser modificado por otros
    if (u.isSuperAdmin && !isSuperAdmin) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
      tooltip: 'Opciones de Gestión',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'unbind_device':
            _confirmUnbindDevice(u);
            break;
          case 'set_admin':
            _changeUserRole(u, UserRole.ADMIN);
            break;
          case 'set_admin_evento':
            _changeUserRole(u, UserRole.ADMIN_EVENTO);
            break;
          case 'set_gestor_evento':
            _changeUserRole(u, UserRole.GESTOR_EVENTO);
            break;
          case 'set_supervisor':
            _changeUserRole(u, UserRole.SUPERVISOR);
            break;
          case 'set_user':
            _changeUserRole(u, UserRole.USER);
            break;
          case 'edit_office_area':
            _showEditUserOfficeAreaDialog(u);
            break;
          case 'delete_user':
            _confirmDeleteUser(u);
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem<String>(
          value: 'edit_office_area',
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF2D5E2A)),
              SizedBox(width: 8),
              Text('Editar Oficina y Área', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (isAdmin)
          const PopupMenuItem<String>(
            value: 'unbind_device',
            child: Row(
              children: [
                Icon(Icons.phonelink_erase_rounded, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Desvincular Celular / Equipo', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (isSuperAdmin && u.role != UserRole.ADMIN)
          const PopupMenuItem<String>(
            value: 'set_admin',
            child: Row(
              children: [
                Icon(Icons.military_tech_rounded, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Designar Admin / Presidente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        if (isAdmin && u.role != UserRole.ADMIN_EVENTO)
          const PopupMenuItem<String>(
            value: 'set_admin_evento',
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Designar Admin de Eventos / UO', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (isAdmin && u.role != UserRole.GESTOR_EVENTO)
          const PopupMenuItem<String>(
            value: 'set_gestor_evento',
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, size: 18, color: Color(0xFF0D9488)),
                SizedBox(width: 8),
                Text('Designar Gestor de Eventos / UO', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (isAdmin && u.role != UserRole.SUPERVISOR)
          const PopupMenuItem<String>(
            value: 'set_supervisor',
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text('Designar Supervisor', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (u.role != UserRole.USER)
          const PopupMenuItem<String>(
            value: 'set_user',
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text('Cambiar a Rol Colaborador', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete_user',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Eliminar Cuenta', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditUserOfficeAreaDialog(UserModel targetUser) {
    final officeCtrl = TextEditingController(text: targetUser.office);
    final areaCtrl = TextEditingController(text: targetUser.area);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.apartment_rounded, color: Color(0xFF2D5E2A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Oficina y Área: ${targetUser.fullName}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actualiza la oficina y área asignada a este colaborador:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: officeCtrl,
              decoration: InputDecoration(
                labelText: 'Oficina',
                hintText: 'Ej. Presidencia, Sede Central...',
                prefixIcon: const Icon(Icons.apartment_rounded, size: 20),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: areaCtrl,
              decoration: InputDecoration(
                labelText: 'Área',
                hintText: 'Ej. Tecnologías, Recursos Humanos...',
                prefixIcon: const Icon(Icons.grid_view_rounded, size: 20),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5E2A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newOffice = officeCtrl.text.trim();
              final newArea = areaCtrl.text.trim();
              Navigator.of(ctx).pop();

              try {
                await UsersService.updateUser(targetUser.id, {
                  'position': newOffice,
                  'department': newArea,
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Oficina y Área actualizadas para ${targetUser.fullName}.'),
                    backgroundColor: const Color(0xFF2D5E2A),
                  ),
                );
                _loadData();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al actualizar: $e'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDirectDeleteDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Eliminar por Correo o ID', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa el nombre, correo o ID de la cuenta que deseas eliminar (ej: Jhon):',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'ej. Jhon o jhon@iiap.gob.pe',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final query = controller.text.trim();
              if (query.isEmpty) return;
              Navigator.of(ctx).pop();

              final match = _allUsers.cast<UserModel?>().firstWhere(
                (u) =>
                    u != null &&
                    (u.email.toLowerCase() == query.toLowerCase() ||
                        u.id == query ||
                        u.fullName.toLowerCase().contains(query.toLowerCase())),
                orElse: () => null,
              );

              if (match != null) {
                _confirmDeleteUser(match);
              } else {
                try {
                  await UsersService.deleteUser(query);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cuenta $query eliminada exitosamente.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se encontró cuenta para "$query".'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: const Text('Buscar y Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showDesignateQrModal() {
    final current = StorageService.currentUser;
    final isSuper = current?.isSuperAdmin == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF9333EA), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Designar Rol mediante Código QR',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('El colaborador escaneará este código para ascender de inmediato',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isSuper)
                  _buildRoleQrTile(
                    title: 'Admin / Presidente Institucional',
                    subtitle: 'Control administrativo, designa Admin y Gestores de eventos',
                    icon: Icons.military_tech_rounded,
                    color: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QrDisplayScreen(
                            mode: QrMode.roleAssignment,
                            targetRole: 'ADMIN',
                            customTitle: 'Designar Admin / Presidente',
                            customSubtitle: 'El nuevo Presidente escaneará este código con su app',
                          ),
                        ),
                      );
                    },
                  ),
                _buildRoleQrTile(
                  title: 'Admin de Eventos / Unidad Organizativa',
                  subtitle: 'CRUD total de eventos de su UO y gestión de participantes',
                  icon: Icons.event_available_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QrDisplayScreen(
                          mode: QrMode.roleAssignment,
                          targetRole: 'ADMIN_EVENTO',
                          customTitle: 'Designar Admin de Eventos / UO',
                          customSubtitle: 'Escanear para otorgar administración de eventos de su UO',
                        ),
                      ),
                    );
                  },
                ),
                _buildRoleQrTile(
                  title: 'Gestor de Eventos / UO',
                  subtitle: 'Control operativo de eventos asignados, proyecta QR y asistencia',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFF0D9488),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QrDisplayScreen(
                          mode: QrMode.roleAssignment,
                          targetRole: 'GESTOR_EVENTO',
                          customTitle: 'Designar Gestor de Eventos / UO',
                          customSubtitle: 'Escanear para otorgar rol de Gestor de eventos',
                        ),
                      ),
                    );
                  },
                ),
                _buildRoleQrTile(
                  title: 'Supervisor de Asistencia',
                  subtitle: 'Control y supervisión de marcas de entrada y salida',
                  icon: Icons.verified_user_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QrDisplayScreen(
                          mode: QrMode.supervisorAssignment,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleQrTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              color: color.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openScheduleDialog(UserModel user) {
    final currentSchedule = ScheduleService.getSchedule(user.id, user: user);
    ScheduleType selectedType = currentSchedule.type;
    int checkInH = currentSchedule.checkInHour;
    int checkInM = currentSchedule.checkInMinute;
    int checkOutH = currentSchedule.checkOutHour;
    int checkOutM = currentSchedule.checkOutMinute;
    int tolerance = currentSchedule.toleranceMinutes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          void updatePreset(ScheduleType type) {
            final def = ScheduleModel.defaultForType(userId: user.id, type: type);
            setSheetState(() {
              selectedType = type;
              checkInH = def.checkInHour;
              checkInM = def.checkInMinute;
              checkOutH = def.checkOutHour;
              checkOutM = def.checkOutMinute;
              tolerance = def.toleranceMinutes;
            });
          }

          Future<void> pickCheckInTime() async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(hour: checkInH, minute: checkInM),
            );
            if (picked != null) {
              setSheetState(() {
                checkInH = picked.hour;
                checkInM = picked.minute;
                selectedType = ScheduleType.personalizado;
              });
            }
          }

          Future<void> pickCheckOutTime() async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(hour: checkOutH, minute: checkOutM),
            );
            if (picked != null) {
              setSheetState(() {
                checkOutH = picked.hour;
                checkOutM = picked.minute;
                selectedType = ScheduleType.personalizado;
              });
            }
          }

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: ThemeService.cardBg(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de agarre
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D5E2A).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF2D5E2A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asignar Horario y Turno',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              user.fullName,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sección Modalidad y Turno
                  Text(
                    'MODALIDAD Y TURNO LABORAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Lista de opciones preestablecidas
                  _buildPresetTile(
                    title: 'Horario Institucional Regular',
                    subtitle: 'Entrada 08:00 AM (Tolerancia hasta 08:30 AM) • Salida 05:00 PM',
                    type: ScheduleType.institucional,
                    isSelected: selectedType == ScheduleType.institucional,
                    isDark: isDark,
                    onTap: () => updatePreset(ScheduleType.institucional),
                  ),
                  const SizedBox(height: 8),
                  _buildPresetTile(
                    title: 'Horario Personalizado',
                    subtitle: 'Ajustar horas de entrada y salida libremente',
                    type: ScheduleType.personalizado,
                    isSelected: selectedType == ScheduleType.personalizado,
                    isDark: isDark,
                    onTap: () => updatePreset(ScheduleType.personalizado),
                  ),

                  const SizedBox(height: 18),

                  // Visualización y selección manual de horas
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: pickCheckInTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ThemeService.cardBorder(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hora Entrada', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.login_rounded, size: 16, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${checkInH.toString().padLeft(2, '0')}:${checkInM.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: pickCheckOutTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ThemeService.cardBorder(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hora Salida', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${checkOutH.toString().padLeft(2, '0')}:${checkOutM.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tolerancia de Ingreso
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tolerancia de ingreso:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D5E2A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$tolerance minutos',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D5E2A), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tolerance.toDouble().clamp(0.0, 60.0),
                    min: 0,
                    max: 60,
                    divisions: 12,
                    activeColor: ThemeService.primaryColor(context),
                    onChanged: (val) {
                      setSheetState(() => tolerance = val.toInt());
                    },
                  ),

                  const SizedBox(height: 14),

                  // Botón de Confirmación
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeService.primaryColor(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final updatedSchedule = ScheduleModel(
                          userId: user.id,
                          type: selectedType,
                          checkInHour: checkInH,
                          checkInMinute: checkInM,
                          checkOutHour: checkOutH,
                          checkOutMinute: checkOutM,
                          toleranceMinutes: tolerance,
                          updatedAt: DateTime.now(),
                          updatedByName: StorageService.currentUser?.fullName,
                        );

                        final messenger = ScaffoldMessenger.of(context);
                        await ScheduleService.saveSchedule(updatedSchedule);

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Horario actualizado para ${user.fullName}:\n${updatedSchedule.fullLabel} (Tol: $tolerance min)',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF15803D),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Guardar Horario',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetTile({
    required String title,
    required String subtitle,
    required ScheduleType type,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF14532D).withValues(alpha: 0.4) : const Color(0xFFDCFCE7))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2D5E2A)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFF2D5E2A) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScheduleBadgeBg(ScheduleType type, bool isDark) {
    switch (type) {
      case ScheduleType.institucional:
        return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDBEAFE);
      case ScheduleType.personalizado:
        return isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    }
  }

  Color _getScheduleBadgeTextColor(ScheduleType type, bool isDark) {
    switch (type) {
      case ScheduleType.institucional:
        return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      case ScheduleType.personalizado:
        return isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = StorageService.currentUser;
    final isAdmin = currentUser?.isAdmin == true;

    final filteredUsers = _allUsers.where((u) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return u.fullName.toLowerCase().contains(query) || u.email.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Gestión de Personal y Horarios' : 'Control de Horarios de Personal',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Responsive.constrained(
                    context,
                    maxTabletWidth: 860,
                    child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    children: [
                      // Tarjeta de Cupos de Supervisores (SOLO ADMIN)
                      if (isAdmin) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: ThemeService.cardBg(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ThemeService.cardBorder(context),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9333EA).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.shield_rounded, color: Color(0xFF9333EA), size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Cupos de Supervisores',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            'Disponibles: $_availableSlots de $_maxSupervisors',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _availableSlots > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$_activeSupervisorsCount / $_maxSupervisors',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _availableSlots > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9333EA),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.qr_code_rounded, size: 20),
                                  label: const Text(
                                    'Designar con QR (Admin, Gestores, Supervisores)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: _showDesignateQrModal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Barra de Búsqueda de Personal
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: ThemeService.cardBg(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ThemeService.cardBorder(context)),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                  hintText: 'Buscar personal por nombre o correo...',
                                  hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _showDirectDeleteDialog,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                                ),
                                child: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 22),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Encabezado de la lista
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Nómina y Horarios Asignados (${filteredUsers.length})',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Toca para editar',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Lista reactiva de colaboradores con horarios
                      ValueListenableBuilder<Map<String, ScheduleModel>>(
                        valueListenable: ScheduleService.schedulesNotifier,
                        builder: (context, schedulesMap, _) {
                          if (filteredUsers.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? 'No se encontraron colaboradores registrados.'
                                      : 'No hay resultados para "$_searchQuery"',
                                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: filteredUsers.map((u) {
                              final schedule = ScheduleService.getSchedule(u.id, user: u);
                              final badgeBg = _getScheduleBadgeBg(schedule.type, isDark);
                              final badgeTextColor = _getScheduleBadgeTextColor(schedule.type, isDark);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: ThemeService.cardBg(context),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: ThemeService.cardBorder(context),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _openScheduleDialog(u),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 19,
                                                backgroundColor: ThemeService.cardBorder(context),
                                                child: Text(
                                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : const Color(0xFF2D5E2A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      u.fullName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      u.email,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (u.office.isNotEmpty || u.area.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        [if (u.office.isNotEmpty) u.office, if (u.area.isNotEmpty) u.area].join(' • '),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(0xFF2D5E2A),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Badge de Rol
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: u.isAdmin
                                                      ? const Color(0xFFFEE2E2)
                                                      : (u.isSupervisor ? const Color(0xFFF3E8FF) : const Color(0xFFDCFCE7)),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  u.role.displayName,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: u.isAdmin
                                                        ? const Color(0xFFDC2626)
                                                        : (u.isSupervisor ? const Color(0xFF9333EA) : const Color(0xFF16A34A)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(height: 1),
                                          const SizedBox(height: 10),

                                          // Fila del Horario Asignado
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.schedule_rounded, size: 16, color: badgeTextColor),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: badgeBg,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          '${schedule.fullLabel} • Tol: 08:30 AM',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: badgeTextColor,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                icon: const Icon(Icons.edit_calendar_rounded, size: 15, color: Color(0xFF2D5E2A)),
                                                label: const Text(
                                                  'Horario',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2D5E2A)),
                                                ),
                                                onPressed: () => _openScheduleDialog(u),
                                              ),
                                              if (isAdmin && u.id != currentUser?.id) ...[
                                                const SizedBox(width: 4),
                                                _buildAdminUserActions(u),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
