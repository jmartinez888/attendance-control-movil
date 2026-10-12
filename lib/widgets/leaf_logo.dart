import 'package:flutter/material.dart';

class LeafLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final BorderRadius? borderRadius;

  const LeafLogo({
    super.key,
    this.size = 48,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/app_icon.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: borderRadius ?? BorderRadius.circular(size * 0.22),
              ),
              child: Icon(Icons.eco_rounded, size: size * 0.6, color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}
