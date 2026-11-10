import 'package:flutter/material.dart';

class GestoPagoProductModel {
  final int idProducto;
  final String servicio;
  final String producto;
  final int? idServicio;
  final int? idCatTipoServicio;
  final int? tipoFront;
  final bool hasDigitoVerificador;
  final double precio;
  final bool showAyuda;
  final String? tipoReferencia;
  final String? legend;

  GestoPagoProductModel({
    required this.idProducto,
    required this.servicio,
    required this.producto,
    this.idServicio,
    this.idCatTipoServicio,
    this.tipoFront,
    required this.hasDigitoVerificador,
    required this.precio,
    required this.showAyuda,
    this.tipoReferencia,
    this.legend,
  });

  factory GestoPagoProductModel.fromJson(Map<String, dynamic> json) {
    return GestoPagoProductModel(
      idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
      servicio: (json['servicio'] ?? 'Servicio GestoPago').toString(),
      producto: (json['producto'] ?? 'Producto').toString(),
      idServicio: (json['idServicio'] as num?)?.toInt(),
      idCatTipoServicio: (json['idCatTipoServicio'] as num?)?.toInt(),
      tipoFront: (json['tipoFront'] as num?)?.toInt(),
      hasDigitoVerificador: json['hasDigitoVerificador'] == true,
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      showAyuda: json['showAyuda'] == true,
      tipoReferencia: json['tipoReferencia']?.toString(),
      legend: json['legend']?.toString(),
    );
  }

  /// Determina si el producto está disponible para compra según las reglas del backend
  bool get isAvailableForPurchase =>
      tipoFront == 1 || tipoFront == 2 || tipoFront == 4;

  /// Determina si es de monto fijo (recargas / tarjetas) o monto libre (recibos)
  bool get isFixedAmount => tipoFront == 1 && precio > 0;

  /// Determina si requiere número de teléfono a 10 dígitos
  bool get requiresPhoneNumber =>
      tipoFront == 1 &&
      idCatTipoServicio != 10 &&
      idCatTipoServicio != 11 &&
      (tipoReferencia == null || tipoReferencia!.toLowerCase() == 'a');

  /// Categoría calculada para organizar el catálogo
  String get categoria {
    final s = servicio.toLowerCase();
    final p = producto.toLowerCase();
    if (s.contains('recarga') ||
        s.contains('telcel') ||
        s.contains('movistar') ||
        s.contains('at-t') ||
        s.contains('att') ||
        s.contains('bait') ||
        s.contains('unefon') ||
        s.contains('virgin') ||
        s.contains('pillofon')) {
      if (s.contains('paquete') || s.contains('datos') || p.contains('internet') || p.contains('gb')) {
        return 'Paquetes de Datos';
      }
      return 'Recargas Telefónicas';
    }
    if (s.contains('airalo') || p.contains('gb') || s.contains('internet')) {
      return 'Paquetes de Datos';
    }
    if (s.contains('agua') ||
        s.contains('cfe') ||
        s.contains('luz') ||
        s.contains('gas') ||
        s.contains('gobierno') ||
        s.contains('tesoreria') ||
        tipoFront == 2 ||
        tipoFront == 4) {
      return 'Servicios y Recibos';
    }
    if (s.contains('amazon') ||
        s.contains('netflix') ||
        s.contains('spotify') ||
        s.contains('xbox') ||
        s.contains('playstation') ||
        s.contains('nintendo') ||
        s.contains('steam') ||
        s.contains('cine') ||
        s.contains('google') ||
        s.contains('apple') ||
        idCatTipoServicio == 10 ||
        idCatTipoServicio == 11) {
      return 'Pines y Entretenimiento';
    }
    return 'Comercio y Otros';
  }

  /// Descripción detallada amigable del producto
  String get descripcionDetallada {
    if (legend != null && legend!.trim().isNotEmpty) {
      return legend!.trim();
    }
    if (tipoFront == 1) {
      return 'Acreditación electrónica inmediata para $servicio ($producto).';
    }
    return 'Pago de servicio referenciado para $servicio - $producto.';
  }

  /// Color representativo de la marca/categoría
  Color get brandColor {
    final s = servicio.toLowerCase();
    if (s.contains('telcel')) return const Color(0xFF0033A0);
    if (s.contains('movistar')) return const Color(0xFF019DF4);
    if (s.contains('at-t') || s.contains('att')) return const Color(0xFF00A8E0);
    if (s.contains('bait')) return const Color(0xFFD97706);
    if (s.contains('amazon')) return const Color(0xFFFF9900);
    if (s.contains('netflix')) return const Color(0xFFE50914);
    if (s.contains('spotify')) return const Color(0xFF1DB954);
    if (s.contains('agua')) return const Color(0xFF0284C7);
    if (s.contains('cfe') || s.contains('luz')) return const Color(0xFF16A34A);
    if (tipoFront == 2 || tipoFront == 4) return const Color(0xFF4F46E5);
    return const Color(0xFF0F766E);
  }

  /// Ícono representativo del producto
  IconData get brandIcon {
    final cat = categoria;
    if (cat == 'Recargas Telefónicas') return Icons.phone_iphone_rounded;
    if (cat == 'Paquetes de Datos') return Icons.wifi_tethering_rounded;
    if (cat == 'Servicios y Recibos') return Icons.receipt_long_rounded;
    if (cat == 'Pines y Entretenimiento') return Icons.card_giftcard_rounded;
    return Icons.storefront_rounded;
  }
}

