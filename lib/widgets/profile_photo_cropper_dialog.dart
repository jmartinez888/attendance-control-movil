import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla completa de recorte interactivo estilo WhatsApp:
/// - La foto permanece quieta y centrada en pantalla.
/// - El usuario MUEVE EL CUADRADO libremente sobre la foto (como WhatsApp).
/// - Se puede redimensionar el cuadrado arrastrando desde cualquiera de sus 4 esquinas.
/// - Pellizcar para agrandar o achicar el cuadrado.
/// - Botón girar 90° en la barra inferior.
/// - Máscara exterior oscurecida y cuadrícula 3x3 con esquinas en 'L' gruesas.
/// - Exportación nítida y ultraligera a 360x360 px para cambio instantáneo sin demoras.
class ProfilePhotoCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const ProfilePhotoCropperDialog({
    super.key,
    required this.imageBytes,
  });

  /// Abre la pantalla completa de recorte.
  static Future<Uint8List?> show({
    required BuildContext context,
    required Uint8List imageBytes,
  }) async {
    return Navigator.of(context).push<Uint8List?>(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (ctx, anim, secAnim) => ProfilePhotoCropperDialog(imageBytes: imageBytes),
        transitionsBuilder: (ctx, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  State<ProfilePhotoCropperDialog> createState() => _ProfilePhotoCropperDialogState();
}

enum _ActiveDragHandle {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topEdge,
  bottomEdge,
  leftEdge,
  rightEdge,
}

class _ProfilePhotoCropperDialogState extends State<ProfilePhotoCropperDialog> {
  ui.Image? _decodedImage;
  bool _isLoading = true;
  String? _errorMessage;

  // Rotación (0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°)
  int _quarterTurns = 0;

  // Rectángulo del recorte (en coordenadas de pantalla)
  Rect? _cropRect;

  // Control de arrastre
  _ActiveDragHandle _activeHandle = _ActiveDragHandle.none;
  Offset? _lastFocalPoint;
  double _baseCropWidth = 0.0;
  double _baseCropHeight = 0.0;
  bool _isProcessingCrop = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _decodedImage = frame.image;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo abrir la imagen: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  Rect _calculateImageRect(Size screenSize) {
    if (_decodedImage == null) return Rect.zero;

    final double availableWidth = screenSize.width;
    final double availableHeight = screenSize.height - 74; // Espacio libre sobre la barra inferior
    final Offset previewCenter = Offset(availableWidth / 2, availableHeight / 2);

    final bool isRotated = _quarterTurns % 2 != 0;
    final double imgW = isRotated ? _decodedImage!.height.toDouble() : _decodedImage!.width.toDouble();
    final double imgH = isRotated ? _decodedImage!.width.toDouble() : _decodedImage!.height.toDouble();

    // Ajustar con BoxFit.contain
    final double scale = min(availableWidth / imgW, availableHeight / imgH);
    final double renderedW = imgW * scale;
    final double renderedH = imgH * scale;

    return Rect.fromCenter(
      center: previewCenter,
      width: renderedW,
      height: renderedH,
    );
  }

  void _rotateClockwise() {
    HapticFeedback.selectionClick();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _cropRect = null; // Reiniciar cuadrado centrado a la nueva orientación
    });
  }

  _ActiveDragHandle _hitTest(Offset point, Rect crop) {
    const double cornerTouchRadius = 45.0;
    const double edgeCenterRadius = 48.0;
    const double edgeBorderThickness = 32.0;

    // 1. Esquinas (4 esquinas en 'L') - Máxima prioridad
    if ((point - crop.topLeft).distance <= cornerTouchRadius) return _ActiveDragHandle.topLeft;
    if ((point - crop.topRight).distance <= cornerTouchRadius) return _ActiveDragHandle.topRight;
    if ((point - crop.bottomLeft).distance <= cornerTouchRadius) return _ActiveDragHandle.bottomLeft;
    if ((point - crop.bottomRight).distance <= cornerTouchRadius) return _ActiveDragHandle.bottomRight;

    // 2. Marcas medias de los bordes (lo que el usuario marcó en rojo en superior e inferior)
    final topCenter = Offset(crop.center.dx, crop.top);
    final bottomCenter = Offset(crop.center.dx, crop.bottom);
    final leftCenter = Offset(crop.left, crop.center.dy);
    final rightCenter = Offset(crop.right, crop.center.dy);

    if ((point - topCenter).distance <= edgeCenterRadius) return _ActiveDragHandle.topEdge;
    if ((point - bottomCenter).distance <= edgeCenterRadius) return _ActiveDragHandle.bottomEdge;
    if ((point - leftCenter).distance <= edgeCenterRadius) return _ActiveDragHandle.leftEdge;
    if ((point - rightCenter).distance <= edgeCenterRadius) return _ActiveDragHandle.rightEdge;

    // 3. Arrastre por cualquier punto de las líneas de borde (zona de toque de 32px)
    final bool withinHoriz = point.dx >= (crop.left - 16) && point.dx <= (crop.right + 16);
    final bool withinVert = point.dy >= (crop.top - 16) && point.dy <= (crop.bottom + 16);

    final double distToTop = (point.dy - crop.top).abs();
    final double distToBottom = (point.dy - crop.bottom).abs();
    final double distToLeft = (point.dx - crop.left).abs();
    final double distToRight = (point.dx - crop.right).abs();

    if (distToTop <= edgeBorderThickness && withinHoriz) return _ActiveDragHandle.topEdge;
    if (distToBottom <= edgeBorderThickness && withinHoriz) return _ActiveDragHandle.bottomEdge;
    if (distToLeft <= edgeBorderThickness && withinVert) return _ActiveDragHandle.leftEdge;
    if (distToRight <= edgeBorderThickness && withinVert) return _ActiveDragHandle.rightEdge;

    // 4. Si toca en el interior del marco: Mover el cuadro completo sobre la foto
    if (crop.contains(point)) return _ActiveDragHandle.move;

    return _ActiveDragHandle.none;
  }

  void _onScaleStart(ScaleStartDetails details, Rect imageRect) {
    if (_cropRect == null) return;
    _lastFocalPoint = details.focalPoint;
    _baseCropWidth = _cropRect!.width;
    _baseCropHeight = _cropRect!.height;
    _activeHandle = _hitTest(details.focalPoint, _cropRect!);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Rect imageRect) {
    if (_cropRect == null || _lastFocalPoint == null) return;

    final delta = details.focalPoint - _lastFocalPoint!;
    _lastFocalPoint = details.focalPoint;

    const double minCropWidth = 60.0;
    const double minCropHeight = 60.0;

    // Pellizco con dos dedos (Escalado simétrico del cuadro)
    if (details.pointerCount >= 2 && details.scale != 1.0) {
      final double scale = details.scale;
      final double newW = (_baseCropWidth * scale).clamp(minCropWidth, imageRect.width);
      final double newH = (_baseCropHeight * scale).clamp(minCropHeight, imageRect.height);
      final center = _cropRect!.center;

      final double l = (center.dx - newW / 2).clamp(imageRect.left, imageRect.right - newW);
      final double t = (center.dy - newH / 2).clamp(imageRect.top, imageRect.bottom - newH);

      setState(() {
        _cropRect = Rect.fromLTWH(l, t, newW, newH);
      });
      return;
    }

    final crop = _cropRect!;

    switch (_activeHandle) {
      case _ActiveDragHandle.move:
        // MOVER EL CUADRO SOBRE LA FOTO (Estilo WhatsApp)
        final double newLeft = (crop.left + delta.dx).clamp(
          imageRect.left,
          imageRect.right - crop.width,
        );
        final double newTop = (crop.top + delta.dy).clamp(
          imageRect.top,
          imageRect.bottom - crop.height,
        );
        setState(() {
          _cropRect = Rect.fromLTWH(newLeft, newTop, crop.width, crop.height);
        });
        break;

      case _ActiveDragHandle.topEdge:
        // Redimensionar desde el tirador superior (la marca que indicó el usuario)
        final double newTop = (crop.top + delta.dy).clamp(
          imageRect.top,
          crop.bottom - minCropHeight,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(crop.left, newTop, crop.right, crop.bottom);
        });
        break;

      case _ActiveDragHandle.bottomEdge:
        // Redimensionar desde el tirador inferior (la marca que indicó el usuario)
        final double newBottom = (crop.bottom + delta.dy).clamp(
          crop.top + minCropHeight,
          imageRect.bottom,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(crop.left, crop.top, crop.right, newBottom);
        });
        break;

      case _ActiveDragHandle.leftEdge:
        // Redimensionar desde el borde izquierdo
        final double newLeft = (crop.left + delta.dx).clamp(
          imageRect.left,
          crop.right - minCropWidth,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(newLeft, crop.top, crop.right, crop.bottom);
        });
        break;

      case _ActiveDragHandle.rightEdge:
        // Redimensionar desde el borde derecho
        final double newRight = (crop.right + delta.dx).clamp(
          crop.left + minCropWidth,
          imageRect.right,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(crop.left, crop.top, newRight, crop.bottom);
        });
        break;

      case _ActiveDragHandle.topLeft:
        final double newLeft = (crop.left + delta.dx).clamp(
          imageRect.left,
          crop.right - minCropWidth,
        );
        final double newTop = (crop.top + delta.dy).clamp(
          imageRect.top,
          crop.bottom - minCropHeight,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(newLeft, newTop, crop.right, crop.bottom);
        });
        break;

      case _ActiveDragHandle.topRight:
        final double newRight = (crop.right + delta.dx).clamp(
          crop.left + minCropWidth,
          imageRect.right,
        );
        final double newTop = (crop.top + delta.dy).clamp(
          imageRect.top,
          crop.bottom - minCropHeight,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(crop.left, newTop, newRight, crop.bottom);
        });
        break;

      case _ActiveDragHandle.bottomLeft:
        final double newLeft = (crop.left + delta.dx).clamp(
          imageRect.left,
          crop.right - minCropWidth,
        );
        final double newBottom = (crop.bottom + delta.dy).clamp(
          crop.top + minCropHeight,
          imageRect.bottom,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(newLeft, crop.top, crop.right, newBottom);
        });
        break;

      case _ActiveDragHandle.bottomRight:
        final double newRight = (crop.right + delta.dx).clamp(
          crop.left + minCropWidth,
          imageRect.right,
        );
        final double newBottom = (crop.bottom + delta.dy).clamp(
          crop.top + minCropHeight,
          imageRect.bottom,
        );
        setState(() {
          _cropRect = Rect.fromLTRB(crop.left, crop.top, newRight, newBottom);
        });
        break;

      case _ActiveDragHandle.none:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _activeHandle = _ActiveDragHandle.none;
    _lastFocalPoint = null;
  }

  Future<void> _performCrop(Rect imageRect) async {
    if (_decodedImage == null || _cropRect == null || _isProcessingCrop) return;

    setState(() => _isProcessingCrop = true);
    HapticFeedback.mediumImpact();

    try {
      final double cropW = _cropRect!.width;
      final double cropH = _cropRect!.height;
      // Normalizar tamaño de salida nítido y ultraligero (máximo 400px en su eje mayor)
      const double maxOutputDim = 400.0;
      final double scaleFactor = min(maxOutputDim / cropW, maxOutputDim / cropH);
      final double outW = (cropW * scaleFactor).roundToDouble().clamp(80.0, 600.0);
      final double outH = (cropH * scaleFactor).roundToDouble().clamp(80.0, 600.0);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

      // Mapear exactamente lo que está dentro de _cropRect hacia el lienzo de salida
      final double ratioX = outW / cropW;
      final double ratioY = outH / cropH;

      canvas.save();
      canvas.scale(ratioX, ratioY);
      canvas.translate(-_cropRect!.left, -_cropRect!.top);

      // Dibujar la imagen exactamente como se ve en la pantalla
      final bool isRotated = _quarterTurns % 2 != 0;
      final double imgW = isRotated ? _decodedImage!.height.toDouble() : _decodedImage!.width.toDouble();
      final double scale = imageRect.width / imgW;

      canvas.translate(imageRect.center.dx, imageRect.center.dy);
      canvas.rotate(_quarterTurns * (pi / 2));
      canvas.scale(scale);
      canvas.drawImage(
        _decodedImage!,
        Offset(-_decodedImage!.width / 2, -_decodedImage!.height / 2),
        Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final croppedUi = await picture.toImage(outW.toInt(), outH.toInt());
      final byteData = await croppedUi.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('No se pudo codificar la imagen.');
      }

      final croppedBytes = byteData.buffer.asUint8List();
      if (!mounted) return;
      Navigator.of(context).pop(croppedBytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingCrop = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al recortar: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final imageRect = _calculateImageRect(screenSize);

    // Inicializar el cuadrado centrado dentro de la imagen si no existe o si la pantalla rotó
    if (_cropRect == null && imageRect != Rect.zero) {
      final double initialSize = min(imageRect.width, imageRect.height) * 0.90;
      _cropRect = Rect.fromCenter(
        center: imageRect.center,
        width: initialSize,
        height: initialSize,
      );
    }

    const accentGreen = Color(0xFF00C853); // Verde WhatsApp / UCrop

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Área interactiva: Foto + Cuadrado móvil
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: accentGreen))
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) => _onScaleStart(details, imageRect),
                  onScaleUpdate: (details) => _onScaleUpdate(details, imageRect),
                  onScaleEnd: _onScaleEnd,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _WhatsAppCropPainter(
                      image: _decodedImage!,
                      quarterTurns: _quarterTurns,
                      imageRect: imageRect,
                      cropRect: _cropRect ?? imageRect,
                    ),
                  ),
                ),
              ),

            // 2. Barra inferior flotante (Cancelar | Girar | OK)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: Colors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cancelar
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: accentGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: _isProcessingCrop ? null : () => Navigator.of(context).pop(null),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      // Botón Girar 90°
                      IconButton(
                        icon: const Icon(Icons.rotate_90_degrees_ccw_rounded, size: 28),
                        color: Colors.white,
                        tooltip: 'Girar 90°',
                        splashRadius: 24,
                        onPressed: _isProcessingCrop ? null : _rotateClockwise,
                      ),

                      // OK
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: accentGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: _isProcessingCrop ? null : () => _performCrop(imageRect),
                        child: _isProcessingCrop
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: accentGreen,
                                ),
                              )
                            : const Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter idéntico al estilo WhatsApp:
/// - Dibuja la foto centrada en pantalla.
/// - Oscurece todo lo que esté fuera del cuadrado de recorte.
/// - Dibuja el marco del cuadrado con regla de tercios (3x3).
/// - Dibuja las 4 esquinas gruesas en ángulo 'L' blancas.
/// - Dibuja las marcas en el punto medio de cada borde.
class _WhatsAppCropPainter extends CustomPainter {
  final ui.Image image;
  final int quarterTurns;
  final Rect imageRect;
  final Rect cropRect;

  _WhatsAppCropPainter({
    required this.image,
    required this.quarterTurns,
    required this.imageRect,
    required this.cropRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageRect == Rect.zero) return;

    // 1. Dibujar la foto centrada con su rotación actual
    canvas.save();
    final bool isRotated = quarterTurns % 2 != 0;
    final double imgW = isRotated ? image.height.toDouble() : image.width.toDouble();
    final double scale = imageRect.width / imgW;

    canvas.translate(imageRect.center.dx, imageRect.center.dy);
    canvas.rotate(quarterTurns * (pi / 2));
    canvas.scale(scale);
    canvas.drawImage(
      image,
      Offset(-image.width / 2, -image.height / 2),
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();

    // 2. Máscara oscura exterior (oscurece todo fuera del cropRect)
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      maskPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill,
    );

    // 3. Borde fino blanco del cuadrado
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(cropRect, borderPaint);

    // 4. Regla de tercios (Cuadrícula 3x3)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final double stepX = cropRect.width / 3;
    final double stepY = cropRect.height / 3;
    // Líneas verticales
    canvas.drawLine(Offset(cropRect.left + stepX, cropRect.top), Offset(cropRect.left + stepX, cropRect.bottom), gridPaint);
    canvas.drawLine(Offset(cropRect.left + stepX * 2, cropRect.top), Offset(cropRect.left + stepX * 2, cropRect.bottom), gridPaint);
    // Líneas horizontales
    canvas.drawLine(Offset(cropRect.left, cropRect.top + stepY), Offset(cropRect.right, cropRect.top + stepY), gridPaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.top + stepY * 2), Offset(cropRect.right, cropRect.top + stepY * 2), gridPaint);

    // 5. Esquinas y tiradores estilo WhatsApp con sombra de alto contraste
    final shadowPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.square;

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.square;

    const double cornerLen = 26.0;
    const double tickLen = 28.0;

    void drawLine(Offset p1, Offset p2) {
      canvas.drawLine(p1, p2, shadowPaint);
      canvas.drawLine(p1, p2, cornerPaint);
    }

    // Esquina Superior Izquierda ┌
    drawLine(Offset(cropRect.left, cropRect.top + cornerLen), Offset(cropRect.left, cropRect.top));
    drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left + cornerLen, cropRect.top));

    // Esquina Superior Derecha ┐
    drawLine(Offset(cropRect.right - cornerLen, cropRect.top), Offset(cropRect.right, cropRect.top));
    drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right, cropRect.top + cornerLen));

    // Esquina Inferior Izquierda └
    drawLine(Offset(cropRect.left, cropRect.bottom - cornerLen), Offset(cropRect.left, cropRect.bottom));
    drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left + cornerLen, cropRect.bottom));

    // Esquina Inferior Derecha ┘
    drawLine(Offset(cropRect.right - cornerLen, cropRect.bottom), Offset(cropRect.right, cropRect.bottom));
    drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right, cropRect.bottom - cornerLen));

    // 6. Marcas de los 4 tiradores centrales (superior, inferior, izquierdo, derecho)
    final cx = cropRect.left + cropRect.width / 2;
    final cy = cropRect.top + cropRect.height / 2;

    // Tirador Centro Superior (el que marcó el usuario en la foto)
    drawLine(Offset(cx - tickLen / 2, cropRect.top), Offset(cx + tickLen / 2, cropRect.top));
    // Tirador Centro Inferior (el que marcó el usuario en la foto)
    drawLine(Offset(cx - tickLen / 2, cropRect.bottom), Offset(cx + tickLen / 2, cropRect.bottom));
    // Tirador Centro Izquierdo
    drawLine(Offset(cropRect.left, cy - tickLen / 2), Offset(cropRect.left, cy + tickLen / 2));
    // Tirador Centro Derecho
    drawLine(Offset(cropRect.right, cy - tickLen / 2), Offset(cropRect.right, cy + tickLen / 2));
  }

  @override
  bool shouldRepaint(covariant _WhatsAppCropPainter oldDelegate) {
    return oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.cropRect != cropRect;
  }
}
