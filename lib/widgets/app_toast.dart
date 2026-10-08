import 'dart:async';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../utils/responsive.dart';

/// Notificación flotante ultraligera, responsiva y autónoma (Toast Overlay)
/// Inmune a bugs de accesibilidad de MIUI/Honor, pausas por cursor en laptops y congelamientos en iOS/iPadOS.
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? icon,
    Color? accentColor,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    // 1. Limpieza inmediata de cualquier toast previo para evitar encolamientos
    dismiss();

    // 2. Limpieza de cualquier snackbar pendiente
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (_) {}

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = accentColor ?? ThemeService.primaryColor(context);

    _currentEntry = OverlayEntry(
      builder: (ctx) => _AppToastWidget(
        title: title,
        subtitle: subtitle,
        icon: icon,
        accentColor: primary,
        isDark: isDark,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    // 3. Temporizador garantizado e implacable
    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }
}

class _AppToastWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onDismiss;

  const _AppToastWidget({
    required this.title,
    this.subtitle,
    this.icon,
    required this.accentColor,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    final bgCard = widget.isDark
        ? const Color(0xFF131F24)
        : const Color(0xFF0F172A);
    final borderColor = widget.accentColor.withValues(alpha: 0.4);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            isDesktopOrTablet ? 32 : 92,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Dismissible(
                  key: const Key('app_toast_dismiss'),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) => widget.onDismiss(),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: widget.isDark ? 0.5 : 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: widget.accentColor
                                      .withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.accentColor
                                        .withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: widget.accentColor,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (widget.subtitle != null &&
                                      widget.subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
