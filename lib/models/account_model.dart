class CuentaModel {
  final int id;
  final String numeroCuenta;
  final double saldo;
  final double saldoRetenido;
  final double saldoDisponible;
  final bool activo;
  final String? clienteNombre;

  CuentaModel({
    required this.id,
    required this.numeroCuenta,
    required this.saldo,
    required this.saldoRetenido,
    required this.saldoDisponible,
    required this.activo,
    this.clienteNombre,
  });

  factory CuentaModel.fromJson(Map<String, dynamic> json) {
    final saldoVal = (json['saldo'] as num?)?.toDouble() ?? 0.0;
    final retenidoVal = (json['saldoRetenido'] as num?)?.toDouble() ?? 0.0;
    final dispVal = (json['saldoDisponible'] as num?)?.toDouble() ?? (saldoVal - retenidoVal);
    return CuentaModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      numeroCuenta: (json['numeroCuenta'] ?? '').toString(),
      saldo: saldoVal,
      saldoRetenido: retenidoVal,
      saldoDisponible: dispVal,
      activo: json['activo'] != false,
      clienteNombre: json['clienteNombre']?.toString(),
    );
  }
}

class UserProfileModel {
  final int usuarioId;
  final int clienteId;
  final String nombreCompleto;
  final String correo;
  final String telefonoMovil;
  final String rfc;
  final String curp;
  final List<CuentaModel> cuentas;

  UserProfileModel({
    required this.usuarioId,
    required this.clienteId,
    required this.nombreCompleto,
    required this.correo,
    required this.telefonoMovil,
    required this.rfc,
    required this.curp,
    required this.cuentas,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final rawCuentas = json['cuentas'] as List<dynamic>? ?? [];
    return UserProfileModel(
      usuarioId: (json['usuarioId'] as num?)?.toInt() ?? 0,
      clienteId: (json['clienteId'] as num?)?.toInt() ?? 0,
      nombreCompleto: (json['nombreCompleto'] ?? '').toString(),
      correo: (json['correo'] ?? '').toString(),
      telefonoMovil: (json['telefonoMovil'] ?? '').toString(),
      rfc: (json['rfc'] ?? '').toString(),
      curp: (json['curp'] ?? '').toString(),
      cuentas: rawCuentas
          .whereType<Map<String, dynamic>>()
          .map(CuentaModel.fromJson)
          .toList(),
    );
  }
}

