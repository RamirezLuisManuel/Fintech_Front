class TransactionModel {
  final String operationId;
  final String upc;
  final String estado;
  final double monto;
  final int idProducto;
  final int? idServicio;
  final int? tipoFront;
  final String? productoNombre;
  final String? servicioNombre;
  final String? telefono;
  final String? referencia;
  final String? numeroCuenta;
  final String? providerCode;
  final String? providerMessage;
  final String? providerTransactionId;
  final String? providerAuthorization;
  final String? pin;
  final String? legend;
  final String? createdAt;
  final String? completedAt;

  TransactionModel({
    required this.operationId,
    required this.upc,
    required this.estado,
    required this.monto,
    required this.idProducto,
    this.idServicio,
    this.tipoFront,
    this.productoNombre,
    this.servicioNombre,
    this.telefono,
    this.referencia,
    this.numeroCuenta,
    this.providerCode,
    this.providerMessage,
    this.providerTransactionId,
    this.providerAuthorization,
    this.pin,
    this.legend,
    this.createdAt,
    this.completedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      operationId: (json['operationId'] ?? json['transactionId'] ?? '').toString(),
      upc: (json['upc'] ?? 'N/A').toString(),
      estado: (json['estado'] ?? 'UNKNOWN').toString().toUpperCase(),
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      idProducto: (json['idProducto'] as num?)?.toInt() ?? 0,
      idServicio: (json['idServicio'] as num?)?.toInt(),
      tipoFront: (json['tipoFront'] as num?)?.toInt(),
      productoNombre: json['productoNombre']?.toString(),
      servicioNombre: json['servicioNombre']?.toString(),
      telefono: json['telefono']?.toString(),
      referencia: json['referencia']?.toString(),
      numeroCuenta: json['numeroCuenta']?.toString(),
      providerCode: json['providerCode']?.toString(),
      providerMessage: json['providerMessage']?.toString(),
      providerTransactionId: json['providerTransactionId']?.toString(),
      providerAuthorization: json['providerAuthorization']?.toString(),
      pin: json['pin']?.toString(),
      legend: json['legend']?.toString(),
      createdAt: json['createdAt']?.toString(),
      completedAt: json['completedAt']?.toString(),
    );
  }

  bool get isSucceeded => estado == 'SUCCEEDED';
  bool get isFailed => estado == 'FAILED';
  bool get isPending => estado == 'UNKNOWN' || estado == 'PROCESSING' || estado == 'PENDING';

  String get estadoLabel {
    if (isSucceeded) return 'Compra Exitosa';
    if (isFailed) return 'Compra Rechazada';
    if (isPending) return 'Compra Pendiente';
    return estado;
  }

  String get displayTitle {
    if (servicioNombre != null && productoNombre != null) {
      return '$servicioNombre - $productoNombre';
    }
    if (productoNombre != null) return productoNombre!;
    return 'Producto GestoPago #$idProducto';
  }

  String get formattedDate {
    final raw = completedAt ?? createdAt;
    if (raw == null || raw.isEmpty) return 'Fecha reciente';
    final clean = raw.replaceAll('T', ' ');
    return clean.length > 19 ? clean.substring(0, 19) : clean;
  }
}

