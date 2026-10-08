import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/wallpaper_service.dart';

class PendingCheckoutCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onManualRecord;

  const PendingCheckoutCard({
    super.key,
    required this.item,
    this.onManualRecord,
  });

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  Color _cardBg(BuildContext context) {
    final hasWallpaper = WallpaperService.currentWallpaper.hasWallpaper;
    return hasWallpaper
        ? ThemeService.cardBg(context).withValues(alpha: 0.85)
        : ThemeService.cardBg(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userName = item['user_name']?.toString() ?? 'Colaborador';
    final userEmail = item['user_email']?.toString() ?? '';
    final userDni = item['user_document']?.toString() ?? '';
    final workDate = item['work_date']?.toString() ?? '';
    final shiftLabel = item['shift_label']?.toString() ?? 'Mañana';
    final checkInTime = item['check_in_time']?.toString() ?? '—';
    final isToday = item['is_today'] == true;
    final hasPassedExit = item['has_passed_exit'] == true;
    final isMissing = !isToday || hasPassedExit;

    final isMorning = shiftLabel.toLowerCase().contains('mañana');
    final shiftColor = isMorning
        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMissing
              ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.6)
              : ThemeService.cardBorder(context),
          width: isMissing ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isMissing
                ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.08 : 0.03)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onManualRecord,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Avatar + Nombre del Usuario + Badge de Alerta
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: shiftColor.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: shiftColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userDni.isNotEmpty ? 'DNI: $userDni • $userEmail' : userEmail,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isMissing
                              ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                              : (isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isMissing
                                ? (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A))
                                : (isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD)),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMissing ? Icons.warning_amber_rounded : Icons.timelapse_rounded,
                                size: 12,
                                color: isMissing
                                    ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                    : const Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                isMissing ? 'Sin Salida' : 'En jornada',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isMissing
                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                      : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 10),

                // Detalles del turno y la entrada (100% responsivo)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(workDate),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: shiftColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                shiftLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: shiftColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.login_rounded, size: 13, color: Color(0xFF10B981)),
                        const SizedBox(width: 3.5),
                        Text(
                          'Entrada: $checkInTime',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
