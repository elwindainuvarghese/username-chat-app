import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? glowColor;
  final LinearGradient? borderGradient;
  final Color color;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 30.0,
    this.opacity = 0.15,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.glowColor,
    this.borderGradient,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        children: [
          // Gradient Border (if provided)
          if (borderGradient != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: borderGradient,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),

          // Inner Content with background clipping
          Padding(
            padding: borderGradient != null
                ? const EdgeInsets.all(1.0)
                : EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                borderRadius - (borderGradient != null ? 1.0 : 0),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      borderRadius - (borderGradient != null ? 1.0 : 0),
                    ),
                    border: borderGradient == null
                        ? Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.0,
                          )
                        : null,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(opacity),
                        color.withOpacity(opacity > 0.1 ? opacity - 0.1 : 0.0),
                      ],
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
