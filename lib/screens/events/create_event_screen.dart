import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive.dart';

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
  int _currentStep = 0;

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

  Widget _buildStepTab({
    required int index,
    required String label,
    required String number,
  }) {
    final isSelected = _currentStep == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mintGreen = Color(0xFF34D399);
    const darkGreen = Color(0xFF064E3B);
    final inactiveColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final inactiveBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (index > _currentStep && _titleController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Por favor, ingresa el título del evento para continuar.'),
                backgroundColor: Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          setState(() => _currentStep = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? mintGreen : inactiveBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? darkGreen : inactiveColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isSelected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : inactiveColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? mintGreen : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeQuickButton({
    required EventType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;
    const mintGreen = Color(0xFF10B981);
    const darkGreen = Color(0xFF064E3B);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? mintGreen
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? mintGreen
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? darkGreen : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? darkGreen : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.eventToEdit != null;

    final bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    const mintGreen = Color(0xFF34D399);
    const darkGreen = Color(0xFF064E3B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEdit ? 'Editar Evento' : 'Crear Nuevo Evento',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: mintGreen,
              child: Icon(Icons.person, color: darkGreen, size: 20),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Responsive.constrained(
            context,
            maxTabletWidth: 700,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. BANNER HEADER
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_today_rounded, color: mintGreen, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Programación de Evento IIAP',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF064E3B).withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                                    ),
                                    child: const Text(
                                      'Oficial',
                                      style: TextStyle(
                                        color: mintGreen,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Código QR institucional con validación biométrica...',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. STEPPER DE 3 PASOS (INFO - TURNOS - CIERRE)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        _buildStepTab(index: 0, label: 'INFO', number: '1'),
                        _buildStepTab(index: 1, label: 'TURNOS', number: '2'),
                        _buildStepTab(index: 2, label: 'CIERRE', number: '3'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. CONTENIDO SEGÚN EL PASO ACTIVO
                  if (_currentStep == 0) ...[
                    // --- PASO 1: INFO ---
                    // TÍTULO DEL EVENTO
                    Row(
                      children: [
                        Text(
                          'Título del Evento',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('*', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: TextFormField(
                        controller: _titleController,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.text_fields_rounded, color: Color(0xFF64748B), size: 20),
                          hintText: 'Taller Institucional de Asistencia y Gestión',
                          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El título del evento es obligatorio';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // TIPO DE EVENTO
                    Row(
                      children: [
                        Text(
                          'Tipo de Evento',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('*', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'Selector Dinámico',
                            style: TextStyle(color: mintGreen, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Tarjeta principal del Tipo
                    InkWell(
                      onTap: _openEventTypeSelector,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_getTypeIcon(_selectedType), color: mintGreen, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedType.displayName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Toca para cambiar la categoría del evento',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Grid 2x2 de accesos rápidos
                    Row(
                      children: [
                        _buildTypeQuickButton(
                          type: EventType.CAPACITACION,
                          label: 'Capacitación',
                          icon: Icons.school_outlined,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeQuickButton(
                          type: EventType.REUNION,
                          label: 'Reunión de Coord.',
                          icon: Icons.handshake_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTypeQuickButton(
                          type: EventType.INSTITUCIONAL,
                          label: 'Seminario IIAP',
                          icon: Icons.account_balance_outlined,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeQuickButton(
                          type: EventType.TALLER,
                          label: 'Taller de Campo',
                          icon: Icons.science_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // UNIDAD ORGANIZATIVA (UO)
                    Row(
                      children: [
                        Text(
                          'Unidad Organizativa (UO)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('*', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.security_rounded, size: 11, color: mintGreen),
                              SizedBox(width: 4),
                              Text(
                                'Admin IIAP: Acceso Total',
                                style: TextStyle(color: mintGreen, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _openUoSelector,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B).withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.domain_rounded, color: mintGreen, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _uoController.text.isNotEmpty ? _uoController.text : 'Seleccionar Unidad...',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Sede Central Iquitos • 14 sedes y direcciones',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 22),
                          ],
                        ),
                      ),
                    ),
                    if (_isCustomUo) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                        ),
                        child: TextFormField(
                          controller: _uoController,
                          style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B), size: 20),
                            hintText: 'Escribe el nombre de la Unidad personalizada...',
                            hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),

                    // BOTÓN CONTINUAR A SEDES & HORARIOS
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mintGreen,
                          foregroundColor: darkGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          if (_titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Por favor, ingresa el título del evento.'),
                                backgroundColor: Color(0xFFDC2626),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          setState(() => _currentStep = 1);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continuar a Sedes & Horarios',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: darkGreen),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: darkGreen, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_currentStep == 1) ...[
                    // --- PASO 2: TURNOS & SEDES ---
                    Row(
                      children: [
                        Text(
                          'Vigencia del Evento',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('*', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectStartDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Inicio', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 14, color: mintGreen),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(_startDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              onTap: _selectEndDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fin', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.event_available_rounded, size: 15, color: mintGreen),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(_endDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                    ),
                    const SizedBox(height: 18),

                    // UBICACIÓN / SEDE
                    Row(
                      children: [
                        Text(
                          'Ubicación / Sede',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('*', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: TextFormField(
                        controller: _locationController,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_on_outlined, color: mintGreen, size: 20),
                          hintText: 'Ej. Auditorio Jaime Moro - IIAP',
                          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _ubicacionesSugeridas.map((loc) {
                        return InkWell(
                          onTap: () => setState(() => _locationController.text = loc),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(loc, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // GESTIÓN DE TURNOS INDEPENDIENTES
                    Row(
                      children: [
                        Text(
                          'Gestión de Turnos Independientes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('*', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildShiftCard(
                      context: context,
                      title: '☀️ Turno Mañana',
                      subtitle: 'Horario oficial de acreditación matutina',
                      icon: Icons.wb_sunny_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      isEnabled: _hasManana,
                      startTime: _mananaStart,
                      endTime: _mananaEnd,
                      onToggle: (val) => setState(() => _hasManana = val),
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
                    _buildShiftCard(
                      context: context,
                      title: '⛅ Turno Tarde',
                      subtitle: 'Horario oficial de acreditación vespertina',
                      icon: Icons.wb_twilight_rounded,
                      iconColor: const Color(0xFFF97316),
                      isEnabled: _hasTarde,
                      startTime: _tardeStart,
                      endTime: _tardeEnd,
                      onToggle: (val) => setState(() => _hasTarde = val),
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
                    _buildShiftCard(
                      context: context,
                      title: '🌙 Turno Noche',
                      subtitle: 'Horario para jornadas nocturnas y talleres',
                      icon: Icons.nights_stay_rounded,
                      iconColor: const Color(0xFF6366F1),
                      isEnabled: _hasNoche,
                      startTime: _nocheStart,
                      endTime: _nocheEnd,
                      onToggle: (val) => setState(() => _hasNoche = val),
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
                    const SizedBox(height: 20),

                    // BOTONES DE NAVEGACIÓN
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                              side: BorderSide(color: cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => setState(() => _currentStep = 0),
                            child: const Text('← Volver a Info', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mintGreen,
                              foregroundColor: darkGreen,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              if (!_hasManana && !_hasTarde && !_hasNoche) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Activa al menos 1 turno (Mañana, Tarde o Noche).'),
                                    backgroundColor: Color(0xFFDC2626),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setState(() => _currentStep = 2);
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Continuar a Cierre', style: TextStyle(fontWeight: FontWeight.bold, color: darkGreen)),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, color: darkGreen, size: 17),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // --- PASO 3: CIERRE & TEMARIO ---
                    Row(
                      children: [
                        Text(
                          'Descripción y Temario del Evento',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: '• Detalla la agenda, objetivos y temas del evento...\n• Cada línea se mostrará como viñeta en el detalle.',
                          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // CONTROL DE ASISTENCIA SWITCH
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: mintGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: mintGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Control de Asistencia Activo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const Text(
                                  'Genera código QR para personal y formulario web para externos',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _requiresAttendance,
                            activeTrackColor: mintGreen,
                            onChanged: (val) => setState(() => _requiresAttendance = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // RESUMEN EJECUTIVO
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B131E) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: mintGreen, size: 18),
                              SizedBox(width: 8),
                              Text('Resumen de Configuración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Evento: ${_titleController.text.isNotEmpty ? _titleController.text : "(Sin título)"}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text('Categoría: ${_selectedType.displayName} • UO: ${_uoController.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 4),
                          Text('Vigencia: ${_formatDate(_startDate)} al ${_formatDate(_endDate)}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 4),
                          Text(
                            'Turnos: ${[if (_hasManana) "Mañana", if (_hasTarde) "Tarde", if (_hasNoche) "Noche"].join(", ")}',
                            style: const TextStyle(fontSize: 12, color: mintGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // BOTONES FINALES
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                              side: BorderSide(color: cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => setState(() => _currentStep = 1),
                            child: const Text('← Volver a Turnos', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mintGreen,
                              foregroundColor: darkGreen,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isSubmitting ? null : _handleSave,
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: darkGreen))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_rounded, color: darkGreen, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        isEdit ? 'Guardar Cambios' : 'Publicar Evento',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkGreen),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
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
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required ValueChanged<bool> onToggle,
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
