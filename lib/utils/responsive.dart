import 'package:flutter/material.dart';

/// Utilidad responsiva y adaptativa para optimizar la interfaz en Escritorio (Windows/macOS/Web), Tablets/iPads y Celulares
class Responsive {
  /// Retorna true si el dispositivo es Tablet o iPad (lado menor >= 600dp)
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 600;
  }

  /// Retorna true si es pantalla ancha de Escritorio, Laptop o Web (ancho >= 800dp)
  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 800;
  }

  /// Retorna true si es pantalla muy ancha (>= 1100dp)
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 1100;
  }

  /// Retorna true si es una tablet grande o iPad Pro (lado menor >= 720dp)
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 720;
  }

  /// Retorna true si el dispositivo está en orientación horizontal (Landscape)
  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  /// Escala de fuentes: en celular devuelve el tamaño exacto, en desktop/tablet escala proporcionalmente
  static double font(BuildContext context, double phoneSize, {double tabletFactor = 1.15}) {
    if (isTablet(context) || isDesktop(context)) {
      return phoneSize * tabletFactor;
    }
    return phoneSize;
  }

  /// Escala de iconos: en celular devuelve el tamaño exacto, en desktop/tablet escala proporcionalmente
  static double icon(BuildContext context, double phoneSize, {double tabletFactor = 1.18}) {
    if (isTablet(context) || isDesktop(context)) {
      return phoneSize * tabletFactor;
    }
    return phoneSize;
  }

  /// Tamaño del código QR en pantalla optimizado para:
  /// - Celulares compactos (iPhone SE, Android pequeños): 200 - 220dp
  /// - Celulares estándar (Android, iPhone Pro/Max): 240 - 260dp
  /// - Tablets / iPads (Portrait): 300 - 330dp
  /// - Laptops / Monitores / Proyectores (Landscape / Desktop): 360 - 420dp
  /// Garantiza matemáticamente que nunca exceda el ancho o alto disponible.
  static double qrDisplaySize(BuildContext context, {bool isProjectorMode = false}) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final isLandscapeMode = width > height;

    if (isProjectorMode) {
      final safeSide = width < height ? width : height;
      return (safeSide * 0.65).clamp(280.0, 520.0);
    }

    if (isDesktop(context) || isWideScreen(context)) {
      return 380.0;
    } else if (isLargeTablet(context)) {
      return 350.0;
    } else if (isTablet(context)) {
      return 310.0;
    } else if (width < 360 || (isLandscapeMode && height < 480)) {
      return 210.0;
    } else if (width < 400) {
      return 235.0;
    } else {
      return 260.0;
    }
  }

  /// Contenedor centrado ergonómico: en celular usa ancho completo, en tablet/escritorio limita el ancho máximo
  static Widget constrained(
    BuildContext context, {
    required Widget child,
    double maxTabletWidth = 840.0,
    double? maxDesktopWidth,
  }) {
    final width = isDesktop(context) ? (maxDesktopWidth ?? 1200.0) : maxTabletWidth;
    if (!isTablet(context) && !isDesktop(context)) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }

  /// Ancho ergonómico para diálogos modales en desktop y tablets
  static BoxConstraints dialogConstraints(BuildContext context, {double maxTabletWidth = 540.0}) {
    if (isTablet(context) || isDesktop(context)) {
      return BoxConstraints(maxWidth: maxTabletWidth);
    }
    return const BoxConstraints();
  }
}
