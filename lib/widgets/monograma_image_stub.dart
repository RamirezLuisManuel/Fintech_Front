import 'package:flutter/material.dart';

/// Implementación para Android/iOS/Desktop/Tests usando Image.network directo.
Widget buildPlatformMonogramaImage({
  required String imageUrl,
  required String altText,
  required double size,
  required Widget fallback,
}) {
  return Image.network(
    imageUrl,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) {
        return Padding(
          padding: EdgeInsets.all(size * 0.10),
          child: child,
        );
      }
      return fallback;
    },
    errorBuilder: (_, _, _) => fallback,
  );
}
