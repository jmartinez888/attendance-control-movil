import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
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

  static const List<String> _uoSugeridas = [
    'Laboratorio de IA',
    'Dirección de Investigación',
    'Presidencia',
    'Tecnologías (OTI)',
    'Recursos Humanos',
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

                  // 1. Selector de Tipo de Evento (ChoiceChips con Iconos y Colores)
                  Text(
                    'Tipo de Evento',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EventType.values.map((type) {
                      final isSelected = _selectedType == type;
                      final typeColor = _getTypeColor(type);
                      return ChoiceChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(type),
                              size: 16,
                              color: isSelected ? Colors.white : typeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type.displayName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12.5,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                        selectedColor: typeColor,
                        backgroundColor: isDark ? ThemeService.cardBg(context) : const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? typeColor : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedType = type);
                        },
                      );
                    }).toList(),
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

                  // 3. Unidad Organizativa (UO) con Selectores Rápidos
                  AppTextField(
                    controller: _uoController,
                    label: 'Unidad Organizativa (UO)',
                    hint: 'Ej. Laboratorio de IA, Dirección de Investigación, Presidencia...',
                    prefixIcon: Icons.apartment_rounded,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _uoSugeridas.map((uo) {
                      final isMatch = _uoController.text.trim().toLowerCase() == uo.toLowerCase();
                      return ActionChip(
                        avatar: isMatch
                            ? const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A))
                            : null,
                        label: Text(
                          uo,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
                            color: isMatch
                                ? (isDark ? Colors.white : const Color(0xFF16A34A))
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () => setState(() => _uoController.text = uo),
                        backgroundColor: isMatch
                            ? const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.12)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        side: BorderSide(
                          color: isMatch
                              ? const Color(0xFF16A34A)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      );
                    }).toList(),
                  ),

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
