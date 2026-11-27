import 'package:flutter/material.dart';
import 'monograma_image_stub.dart'
    if (dart.library.js_interop) 'monograma_image_web.dart';

/// Muestra el logotipo oficial del servicio desde GestoPago usando `idServicio`:
/// `https://gestopago.portalventas.net/sistema/images/gestopago/servicios/{idServicio}.png`
///
/// Si el PNG no existe (404), está cargando o falla la red/CORS, muestra
/// automáticamente un monograma limpio con las iniciales del servicio.
class Monograma extends StatelessWidget {
  static const String _baseUrl =
      'https://gestopago.portalventas.net/sistema/images/gestopago/servicios';

  final int? idServicio;
  final String nombre;
  final double size;
  final double borderRadius;
  final Color? accentColor;

  const Monograma({
    super.key,
    required this.idServicio,
    required this.nombre,
    this.size = 46,
    this.borderRadius = 12,
    this.accentColor,
  });

  static String buildImageUrl(int idServicio) => '$_baseUrl/$idServicio.png';

  static String extractInitials(String rawName) {
    final cleaned = rawName.trim();
    if (cleaned.isEmpty) return 'GP';
    final words = cleaned
        .split(RegExp(r'[\s\-_/()]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'GP';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFF0F172A);
    final hasServiceId = idServicio != null && idServicio! > 0;

    if (!hasServiceId) {
      return _buildFallbackMonogram(color);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: buildPlatformMonogramaImage(
        imageUrl: buildImageUrl(idServicio!),
        altText: nombre,
        size: size,
        fallback: _buildFallbackMonogram(color, embedded: true),
      ),
    );
  }

  Widget _buildFallbackMonogram(Color color, {bool embedded = false}) {
    final initials = extractInitials(nombre);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: embedded ? null : BorderRadius.circular(borderRadius),
        border: embedded
            ? null
            : Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
