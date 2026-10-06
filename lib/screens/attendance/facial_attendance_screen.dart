import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

class FacialAttendanceScreen extends StatefulWidget {
  final String jwtToken; // Token JWT del usuario autenticado
  final String backendBaseUrl; // Ej: 'http://192.168.1.50:3000/api' o 'http://10.0.2.2:3000/api'

  const FacialAttendanceScreen({
    super.key,
    required this.jwtToken,
    required this.backendBaseUrl,
  });

  @override
  State<FacialAttendanceScreen> createState() => _FacialAttendanceScreenState();
}

class _FacialAttendanceScreenState extends State<FacialAttendanceScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  Timer? _throttlingTimer;

  bool _isProcessingFrame = false;
  bool _attendanceSuccess = false;
  String _statusMessage = "Posiciona tu rostro dentro del óvalo...";
  Color _statusColor = Colors.white;
  IconData _statusIcon = Icons.face;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = "No se encontraron cámaras disponibles.";
            _statusColor = Colors.redAccent;
          });
        }
        return;
      }
      // Priorizar la cámara frontal para reconocimiento facial
      final frontCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Resolución ideal: rápida y ligera
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
      // Iniciar el ciclo de captura automática con throttling (cada 1.8 segundos)
      _startContinuousFaceScanning();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error al inicializar cámara: $e";
          _statusColor = Colors.redAccent;
        });
      }
    }
  }

  /// Throttling obligatorio: 1 frame cada 1.8s para no saturar la red ni el backend
  void _startContinuousFaceScanning() {
    _throttlingTimer?.cancel();
    _throttlingTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) async {
      if (_isProcessingFrame || _attendanceSuccess || _cameraController == null || !_cameraController!.value.isInitialized) {
        return;
      }
      await _captureAndProcessFrame();
    });
  }

  Future<void> _captureAndProcessFrame() async {
    if (_isProcessingFrame || _attendanceSuccess) return;
    setState(() {
      _isProcessingFrame = true;
      _statusMessage = "Escaneando rostro...";
      _statusColor = Colors.amberAccent;
      _statusIcon = Icons.sync;
    });
    try {
      // Capturar frame en formato JPG
      final XFile imageFile = await _cameraController!.takePicture();
      final bytes = await File(imageFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      // Eliminar temporalmente el archivo capturado para no llenar la memoria del teléfono
      File(imageFile.path).delete().ignore();

      // Enviar al backend de NestJS
      final url = Uri.parse('${widget.backendBaseUrl}/attendance/facial-recognition');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
        body: jsonEncode({
          'image_base64': base64Image,
          'device_id': 'flutter-facial-app',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // ¡ÉXITO! Detener el timer y la cámara inmediatamente
          _throttlingTimer?.cancel();
          final userName = data['user']?['full_name'] ?? 'Usuario';
          final type = data['type'] == 'CHECK_IN' ? 'ENTRADA' : 'SALIDA';
          if (mounted) {
            setState(() {
              _attendanceSuccess = true;
              _statusMessage = "✅ ¡Asistencia de $type registrada con éxito para $userName!";
              _statusColor = Colors.greenAccent;
              _statusIcon = Icons.check_circle;
            });
          }
          // Opcional: Cerrar la pantalla después de 2.5 segundos
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) Navigator.pop(context, true);
          });
          return;
        } else {
          if (mounted) {
            setState(() {
              _statusMessage = data['message'] ?? "Rostro no detectado o no coincide.";
              _statusColor = Colors.orangeAccent;
              _statusIcon = Icons.warning_amber_rounded;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = "Esperando alineación de rostro...";
            _statusColor = Colors.white70;
            _statusIcon = Icons.face;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Buscando rostro...";
          _statusColor = Colors.white70;
        });
      }
    } finally {
      if (mounted && !_attendanceSuccess) {
        setState(() {
          _isProcessingFrame = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _throttlingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Control Biométrico Facial", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Vista previa de la cámara (Llena la pantalla)
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          // 2. HUD - Guía visual ovalada con animación
          CustomPaint(
            size: Size.infinite,
            painter: FaceOvalOverlayPainter(
              borderColor: _attendanceSuccess
                  ? Colors.greenAccent
                  : (_isProcessingFrame ? Colors.amberAccent : Colors.white),
            ),
          ),
          // 3. Panel inferior de feedback visual
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _statusColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_statusIcon, color: _statusColor, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isProcessingFrame && !_attendanceSuccess)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja el marco de la cámara oscureciendo el exterior y dejando un óvalo transparente en el centro
class FaceOvalOverlayPainter extends CustomPainter {
  final Color borderColor;
  FaceOvalOverlayPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.68,
      height: size.height * 0.42,
    );

    // Máscara oscura exterior
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, backgroundPaint);

    // Borde ovalado iluminado
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant FaceOvalOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor;
  }
}
