import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/event_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class CreateEventScreen extends StatefulWidget {
  final EventModel? eventToEdit;

  const CreateEventScreen({
    super.key,
    this.eventToEdit,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _uoController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  late EventType _selectedType;
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _requiresAttendance;

  // Turnos Independientes del Evento
  bool _hasManana = true;
  TimeOfDay _mananaStart = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _mananaEnd = const TimeOfDay(hour: 12, minute: 30);

  bool _hasTarde = false;
  TimeOfDay _tardeStart = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _tardeEnd = const TimeOfDay(hour: 18, minute: 0);

  bool _hasNoche = false;
  TimeOfDay _nocheStart = const TimeOfDay(hour: 18, minute: 30);
  TimeOfDay _nocheEnd = const TimeOfDay(hour: 21, minute: 30);

  bool _isSubmitting = false;
  bool _isCustomUo = false;

  static const List<String> _uoOficiales = [
    'Presidencia Ejecutiva',
    'Dirección de Investigación en Recursos Naturales (DIRN)',
    'Dirección de Investigación e Información Ambiental (DIIA)',
    'Dirección de Investigación en Manejo Integral del Bosque (DIMIB)',
    'Laboratorio de Inteligencia Artificial (IA)',
    'Oficina de Tecnologías de Información (OTI)',
    'Oficina de Recursos Humanos (ORH)',
    'Oficina de Administración y Finanzas (OAF)',
    'Estación Experimental Allpahuayo',
    'Estación Experimental Jenaro Herrera',
    'Estación Experimental Quistococha',
    'Sede Regional San Martín (Tarapoto)',
    'Sede Regional Ucayali (Pucallpa)',
    'Sede Regional Madre de Dios',
  ];

  static const List<String> _ubicacionesSugeridas = [
    'IIAP - Sede Central',
    'Auditorio Principal',
    'Sala de Capacitaciones',
    'Virtual (Google Meet)',
    'Virtual (Zoom)',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.eventToEdit;
    final now = DateTime.now();

    _titleController = TextEditingController(text: edit?.title ?? '');
    _uoController = TextEditingController(text: edit?.organizationalUnit ?? '');
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _locationController = TextEditingController(text: edit?.location ?? 'IIAP - Sede Central');

    _selectedType = edit?.type ?? EventType.CAPACITACION;

    final currentUser = StorageService.currentUser;
    if (_uoController.text.trim().isEmpty) {
      if (currentUser?.department != null && currentUser!.department!.trim().isNotEmpty) {
        _uoController.text = currentUser.department!.trim();
      } else {
        _uoController.text = _uoOficiales.first;
      }
    } else {
      if (!_uoOficiales.any((u) => u.toLowerCase() == _uoController.text.trim().toLowerCase())) {
        _isCustomUo = true;
      }
    }

    final initialStart = edit?.startDate ?? now.add(const Duration(hours: 1));
    _startDate = DateTime(initialStart.year, initialStart.month, initialStart.day);

    final initialEnd = edit?.endDate ?? initialStart.add(const Duration(hours: 4));
    _endDate = DateTime(initialEnd.year, initialEnd.month, initialEnd.day);

    _requiresAttendance = edit?.requiresAttendance ?? true;

    // Restaurar turnos si viene de edición
    final editShifts = edit?.shifts;
    if (editShifts != null && editShifts.isNotEmpty) {
      _hasManana = false;
      _hasTarde = false;
      _hasNoche = false;
      for (final s in editShifts) {
        if (s.name == 'manana') {
          _hasManana = s.enabled;
          _mananaStart = _parseTimeOfDay(s.startTime, defaultHour: 8, defaultMinute: 30);
          _mananaEnd = _parseTimeOfDay(s.endTime, defaultHour: 12, defaultMinute: 30);
        } else if (s.name == 'tarde') {
          _hasTarde = s.enabled;
          _tardeStart = _parseTimeOfDay(s.startTime, defaultHour: 14, defaultMinute: 0);
          _tardeEnd = _parseTimeOfDay(s.endTime, defaultHour: 18, defaultMinute: 0);
        } else if (s.name == 'noche') {
          _hasNoche = s.enabled;
          _nocheStart = _parseTimeOfDay(s.startTime, defaultHour: 18, defaultMinute: 30);
          _nocheEnd = _parseTimeOfDay(s.endTime, defaultHour: 21, defaultMinute: 30);
        }
      }
      if (!_hasManana && !_hasTarde && !_hasNoche) {
        _hasManana = true;
      }
    } else if (edit != null) {
      final sHour = edit.startDate.hour;
      final startTod = TimeOfDay(hour: edit.startDate.hour, minute: edit.startDate.minute);
      final endTod = TimeOfDay(hour: edit.endDate.hour, minute: edit.endDate.minute);
      if (sHour < 13) {
        _hasManana = true;
        _mananaStart = startTod;
        _mananaEnd = endTod;
      } else if (sHour < 18) {
        _hasTarde = true;
        _tardeStart = startTod;
        _tardeEnd = endTod;
      } else {
        _hasNoche = true;
        _nocheStart = startTod;
        _nocheEnd = endTod;
      }
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr, {required int defaultHour, required int defaultMinute}) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return TimeOfDay(hour: defaultHour, minute: defaultMinute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _uoController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de inicio del evento',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de culminación del evento',
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectShiftTime({
    required TimeOfDay initialTime,
    required String title,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: title,
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación obligatoria: al menos 1 turno activo
    if (!_hasManana && !_hasTarde && !_hasNoche) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes activar al menos un turno para el evento (Mañana, Tarde o Noche).'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final activeShifts = <EventShift>[];
    if (_hasManana) {
      activeShifts.add(EventShift(
        name: 'manana',
        label: 'Turno Mañana',
        startTime: _formatTimeOfDay(_mananaStart),
        endTime: _formatTimeOfDay(_mananaEnd),
        enabled: true,
      ));
    }
    if (_hasTarde) {
      activeShifts.add(EventShift(
        name: 'tarde',
        label: 'Turno Tarde',
        startTime: _formatTimeOfDay(_tardeStart),
        endTime: _formatTimeOfDay(_tardeEnd),
        enabled: true,
      ));
    }
    if (_hasNoche) {
      activeShifts.add(EventShift(
        name: 'noche',
        label: 'Turno Noche',
        startTime: _formatTimeOfDay(_nocheStart),
        endTime: _formatTimeOfDay(_nocheEnd),
        enabled: true,
      ));
    }

    final firstShift = activeShifts.first;
    final lastShift = activeShifts.last;
    final startParts = firstShift.startTime.split(':');
    final endParts = lastShift.endTime.split(':');

    final start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );
    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y hora de culminación debe ser posterior al inicio.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uoText = _uoController.text.trim();
      final uoVal = uoText.isNotEmpty ? uoText : null;

      if (widget.eventToEdit != null) {
        final updated = widget.eventToEdit!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          startDate: start,
          endDate: end,
          type: _selectedType,
          requiresAttendance: _requiresAttendance,
          organizationalUnit: uoVal,
          shifts: activeShifts,
        );
        await EventService.updateEvent(updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Evento actualizado exitosamente!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        await EventService.createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          startDate: start,
          endDate: end,
          type: _selectedType,
          requiresAttendance: _requiresAttendance,
          organizationalUnit: uoVal,
          shifts: activeShifts,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Evento creado y programado exitosamente!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar evento: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  IconData _getTypeIcon(EventType type) {
    switch (type) {
      case EventType.CAPACITACION:
        return Icons.school_rounded;
      case EventType.REUNION:
        return Icons.groups_rounded;
      case EventType.INSTITUCIONAL:
        return Icons.account_balance_rounded;
      case EventType.TALLER:
        return Icons.handshake_rounded;
      case EventType.CONFERENCIA:
        return Icons.mic_external_on_rounded;
      case EventType.OTRO:
        return Icons.event_rounded;
    }
  }

  Color _getTypeColor(EventType type) {
    switch (type) {
      case EventType.CAPACITACION:
        return const Color(0xFF2563EB); // Azul
      case EventType.REUNION:
        return const Color(0xFF0D9488); // Teal
      case EventType.INSTITUCIONAL:
        return const Color(0xFF7C3AED); // Púrpura
      case EventType.TALLER:
        return const Color(0xFFEA580C); // Naranja
      case EventType.CONFERENCIA:
        return const Color(0xFFDB2777); // Rosa
      case EventType.OTRO:
        return const Color(0xFF4B5563); // Gris
    }
  }

  void _openEventTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ThemeService.cardBg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.category_rounded, size: 22, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Text(
                    'Seleccionar Tipo de Evento',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Elige la categoría oficial del evento institucional',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ...EventType.values.map((type) {
                final isSelected = _selectedType == type;
                final color = _getTypeColor(type);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedType = type);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: isDark ? 0.2 : 0.1)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getTypeIcon(type), color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              type.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : color)
                                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: color, size: 22)
                          else
                            Icon(Icons.circle_outlined,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openUoSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = ThemeService.primaryColor(context);
    String searchQuery = '';
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredUos = _uoOficiales.where((uo) {
              if (searchQuery.trim().isEmpty) return true;
              return uo.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: ThemeService.cardBg(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.apartment_rounded, size: 22, color: primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seleccionar Unidad Organizativa (UO)',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Direcciones, Oficinas y Estaciones Oficiales del IIAP',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Buscador en vivo
                  TextField(
                    controller: searchController,
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Buscar unidad organizativa...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ...filteredUos.map((uo) {
                          final isSelected = _uoController.text.trim().toLowerCase() == uo.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _uoController.text = uo;
                                  _isCustomUo = false;
                                });
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? primary
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.business_rounded,
                                      size: 18,
                                      color: isSelected ? primary : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        uo,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected
                                              ? (isDark ? Colors.white : primary)
                                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: primary, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const Divider(height: 20),
                        // Opción personalizada
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isCustomUo = true;
                              _uoController.clear();
                            });
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFFF59E0B)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Escribir otra Unidad / Oficina personalizada...',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.eventToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Editar Evento' : 'Crear Nuevo Evento',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: ThemeService.cardBg(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Responsive.constrained(
            context,
            maxTabletWidth: 700,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner informativo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeService.primaryColor(context).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ThemeService.primaryColor(context).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ThemeService.primaryColor(context).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: ThemeService.primaryColor(context),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Programación de Evento IIAP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Podrás generar un código QR único para que los asistentes registren su participación.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 1. Selector de Tipo de Evento (Selector Desplegable Premium)
                  Row(
                    children: [
                      Text(
                        'Tipo de Evento *',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(_selectedType).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Selector',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _getTypeColor(_selectedType),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openEventTypeSelector,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _getTypeColor(_selectedType).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getTypeColor(_selectedType).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getTypeIcon(_selectedType), color: _getTypeColor(_selectedType), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedType.displayName,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toca para cambiar la categoría del evento',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Título del Evento
                  AppTextField(
                    controller: _titleController,
                    label: 'Título del Evento *',
                    hint: 'Ej. Taller Institucional de Asistencia y Gestión',
                    prefixIcon: Icons.title_rounded,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa el título del evento';
                      if (v.trim().length < 5) return 'El título debe tener al menos 5 caracteres';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // 3. Unidad Organizativa (UO) - Selector Desplegable Oficial
                  Row(
                    children: [
                      Text(
                        'Unidad Organizativa (UO) *',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final user = StorageService.currentUser;
                          final isAdminIiap = user?.role == UserRole.ADMIN || user?.role == UserRole.SUPERADMIN;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text(
                                  isAdminIiap ? 'Admin IIAP: Acceso Total' : 'Selector IIAP',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openUoSelector,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.apartment_rounded, color: Color(0xFF16A34A), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _uoController.text.trim().isNotEmpty
                                      ? _uoController.text.trim()
                                      : 'Seleccionar Unidad Organizativa...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _uoController.text.trim().isNotEmpty
                                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toca para desplegar las 14 sedes y direcciones',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isCustomUo) ...[
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _uoController,
                      label: 'Nombre de la Unidad Organizativa personalizada',
                      hint: 'Ej. Laboratorio de Biología Molecular',
                      prefixIcon: Icons.edit_location_alt_rounded,
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 4. Ubicación / Plataforma con sugerencias rápidas
                  AppTextField(
                    controller: _locationController,
                    label: 'Ubicación / Plataforma *',
                    hint: 'Ej. Auditorio Principal IIAP / Google Meet',
                    prefixIcon: Icons.location_on_rounded,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa la ubicación o plataforma';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _ubicacionesSugeridas.map((loc) {
                        final isMatch = _locationController.text.trim().toLowerCase() == loc.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              loc,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
                                color: isMatch
                                    ? (isDark ? Colors.white : const Color(0xFF2563EB))
                                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () => setState(() => _locationController.text = loc),
                            backgroundColor: isMatch
                                ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            side: BorderSide(
                              color: isMatch
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 5. Descripción o Agenda
                  AppTextField(
                    controller: _descriptionController,
                    label: 'Descripción o Agenda',
                    hint: 'Detalla los objetivos, ponentes o temas a tratar...',
                    prefixIcon: Icons.notes_rounded,
                    keyboardType: TextInputType.multiline,
                    maxLength: 500,
                  ),

                  const SizedBox(height: 20),

                  // 6. Selector de Vigencia del Evento (Fecha de Inicio y Fecha de Fin)
                  Text(
                    'Vigencia del Evento',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPickerCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'Fecha Inicio',
                          value: _formatDate(_startDate),
                          onTap: _selectStartDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildPickerCard(
                          icon: Icons.event_available_rounded,
                          label: 'Fecha Fin',
                          value: _formatDate(_endDate),
                          onTap: _selectEndDate,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 7. Gestión de Turnos Independientes (Mañana, Tarde, Noche)
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: ThemeService.primaryColor(context)),
                      const SizedBox(width: 8),
                      Text(
                        'Turnos y Horarios Independientes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Puedes activar 1 solo turno, 2 turnos o los 3 turnos en el mismo evento:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ☀️ Turno Mañana
                  _buildShiftCard(
                    context: context,
                    title: 'Turno Mañana',
                    subtitle: 'Jornada matutina',
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isEnabled: _hasManana,
                    onToggle: (v) => setState(() => _hasManana = v),
                    startTime: _mananaStart,
                    endTime: _mananaEnd,
                    onPickStart: () => _selectShiftTime(
                      initialTime: _mananaStart,
                      title: 'Hora Inicio - Turno Mañana',
                      onSelected: (t) => _mananaStart = t,
                    ),
                    onPickEnd: () => _selectShiftTime(
                      initialTime: _mananaEnd,
                      title: 'Hora Fin - Turno Mañana',
                      onSelected: (t) => _mananaEnd = t,
                    ),
                  ),

                  // ⛅ Turno Tarde
                  _buildShiftCard(
                    context: context,
                    title: 'Turno Tarde',
                    subtitle: 'Jornada vespertina',
                    icon: Icons.wb_twilight_rounded,
                    iconColor: const Color(0xFFF97316),
                    isEnabled: _hasTarde,
                    onToggle: (v) => setState(() => _hasTarde = v),
                    startTime: _tardeStart,
                    endTime: _tardeEnd,
                    onPickStart: () => _selectShiftTime(
                      initialTime: _tardeStart,
                      title: 'Hora Inicio - Turno Tarde',
                      onSelected: (t) => _tardeStart = t,
                    ),
                    onPickEnd: () => _selectShiftTime(
                      initialTime: _tardeEnd,
                      title: 'Hora Fin - Turno Tarde',
                      onSelected: (t) => _tardeEnd = t,
                    ),
                  ),

                  // 🌙 Turno Noche
                  _buildShiftCard(
                    context: context,
                    title: 'Turno Noche',
                    subtitle: 'Jornada nocturna',
                    icon: Icons.nights_stay_rounded,
                    iconColor: const Color(0xFF6366F1),
                    isEnabled: _hasNoche,
                    onToggle: (v) => setState(() => _hasNoche = v),
                    startTime: _nocheStart,
                    endTime: _nocheEnd,
                    onPickStart: () => _selectShiftTime(
                      initialTime: _nocheStart,
                      title: 'Hora Inicio - Turno Noche',
                      onSelected: (t) => _nocheStart = t,
                    ),
                    onPickEnd: () => _selectShiftTime(
                      initialTime: _nocheEnd,
                      title: 'Hora Fin - Turno Noche',
                      onSelected: (t) => _nocheEnd = t,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 8. Switch de Control de Asistencia con QR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: ThemeService.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _requiresAttendance
                            ? ThemeService.primaryColor(context).withValues(alpha: 0.5)
                            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Color(0xFF16A34A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Control de Asistencia con QR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Permite a los asistentes escanear el QR del evento y quedar registrados.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _requiresAttendance,
                          activeTrackColor: ThemeService.primaryColor(context),
                          onChanged: (val) => setState(() => _requiresAttendance = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón de Publicar / Guardar Evento
                  AppButton(
                    text: isEdit ? 'Guardar Cambios' : 'Publicar Evento',
                    icon: isEdit ? Icons.check_circle_outline_rounded : Icons.add_circle_outline_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ThemeService.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? ThemeService.cardBorder(context) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ThemeService.primaryColor(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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

  Widget _buildShiftCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required VoidCallback onPickStart,
    required VoidCallback onPickEnd,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? iconColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: isEnabled ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isEnabled ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: isEnabled ? iconColor : Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
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
              Switch.adaptive(
                value: isEnabled,
                activeTrackColor: iconColor,
                onChanged: onToggle,
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onPickStart,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hora Inicio',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 14, color: iconColor),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeOfDay(startTime),
                                style: TextStyle(
                                  fontSize: 13,
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
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: onPickEnd,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hora Fin',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.access_time_filled_rounded, size: 14, color: iconColor),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeOfDay(endTime),
                                style: TextStyle(
                                  fontSize: 13,
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
          ],
        ],
      ),
    );
  }
}
