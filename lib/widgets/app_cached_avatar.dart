import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Proveedor de imagen con caché en disco y memoria de alto rendimiento
ImageProvider? appCachedImageProvider(String? imageUrl) {
  if (imageUrl == null || imageUrl.trim().isEmpty) return null;
  final clean = imageUrl.trim();
  if (clean.startsWith('data:image')) {
    final commaIndex = clean.indexOf(',');
    if (commaIndex != -1) {
      try {
        final bytes = base64Decode(clean.substring(commaIndex + 1));
        return MemoryImage(bytes);
      } catch (_) {}
    }
  }
  return CachedNetworkImageProvider(clean);
}

/// Widget optimizado para fotos de perfil con almacenamiento en caché persistente en disco
/// Carga al instante (0 ms) en aperturas posteriores sin volver a descargar de internet.
class AppCachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxBorder? border;
  final VoidCallback? onTap;

  const AppCachedAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.size = 40.0,
    this.backgroundColor,
    this.textColor,
    this.border,
    this.onTap,
  });

  String get _initial {
    final clean = name.trim();
    if (clean.isEmpty) return 'U';
    return clean[0].toUpperCase();
  }

  String get _twoInitials {
    final clean = name.trim();
    if (clean.isEmpty) return 'U';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? const Color(0xFF10B981).withValues(alpha: 0.15);
    final effectiveText = textColor ?? const Color(0xFF10B981);
    final validUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    Widget avatarContent;

    if (validUrl) {
      final clean = imageUrl!.trim();
      if (clean.startsWith('data:image')) {
        final commaIndex = clean.indexOf(',');
        Uint8List? memoryBytes;
        if (commaIndex != -1) {
          try {
            memoryBytes = base64Decode(clean.substring(commaIndex + 1));
          } catch (_) {}
        }
        if (memoryBytes != null) {
          avatarContent = Image.memory(
            memoryBytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          );
        } else {
          avatarContent = Container(
            color: effectiveBg,
            alignment: Alignment.center,
            child: Text(
              size <= 28 ? _initial : _twoInitials,
              style: TextStyle(
                color: effectiveText,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38,
              ),
            ),
          );
        }
      } else {
        avatarContent = CachedNetworkImage(
          imageUrl: clean,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 2.5).toInt(),
          memCacheHeight: (size * 2.5).toInt(),
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => Container(
            color: effectiveBg,
            alignment: Alignment.center,
            child: Text(
              size <= 28 ? _initial : _twoInitials,
              style: TextStyle(
                color: effectiveText,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: effectiveBg,
            alignment: Alignment.center,
            child: Text(
              size <= 28 ? _initial : _twoInitials,
              style: TextStyle(
                color: effectiveText,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38,
              ),
            ),
          ),
        );
      }
    } else {
      avatarContent = Container(
        width: size,
        height: size,
        color: effectiveBg,
        alignment: Alignment.center,
        child: Text(
          size <= 28 ? _initial : _twoInitials,
          style: TextStyle(
            color: effectiveText,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      );
    }

    Widget result = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
      ),
      child: ClipOval(
        child: avatarContent,
      ),
    );

    if (onTap != null) {
      result = GestureDetector(
        onTap: onTap,
        child: result,
      );
    }

    return result;
  }
}
