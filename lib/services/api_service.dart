import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_model.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';

class ApiResult<T> {
  final bool success;
  final String message;
  final T? data;
  final int statusCode;
  final bool sessionDisplaced;

  ApiResult({
    required this.success,
    required this.message,
    this.data,
    this.statusCode = 200,
    this.sessionDisplaced = false,
  });
}

class CatalogItem {
  final int id;
  final String nombre;
  final String? codigoPostal;

  const CatalogItem({
    required this.id,
    required this.nombre,
    this.codigoPostal,
  });

  bool get isOtro => nombre.toLowerCase() == 'otro' || nombre.toLowerCase() == 'otra';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogItem && other.id == id && other.nombre == nombre;

  @override
  int get hashCode => Object.hash(id, nombre);
}

class ApiService {
  static const String _envApiHost = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static void Function(String reason)? onSessionInvalidated;
  static DateTime _lastActivity = DateTime.now();
  static DateTime _lastTokenRefresh = DateTime.now();
  static const Duration sessionInactivityLimit = Duration(minutes: 5);
  static const Duration _tokenRefreshInterval = Duration(minutes: 3);

  // Tokens solo en memoria: al cerrar la app móvil o pestaña web caducan de inmediato
  static String? _memoryAccessToken;
  static String? _memoryRefreshToken;
  static String? _memoryCorreo;

  static String? get currentAccessToken => _memoryAccessToken;
  static String? get currentCorreo => _memoryCorreo;

  static bool needsTokenRefresh() {
    return _memoryAccessToken != null &&
        _memoryRefreshToken != null &&
        DateTime.now().difference(_lastTokenRefresh) >= _tokenRefreshInterval;
  }

  /// Renueva silenciosamente el accessToken cuando el usuario está activo para no sacarlo
  static Future<bool> refreshAccessToken() async {
    if (_memoryCorreo == null || _memoryRefreshToken == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/auth/refresh'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'correo': _memoryCorreo,
              'refreshToken': _memoryRefreshToken,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = _safeDecode(response.body);
        final data = body['data'];
        if (data is Map<String, dynamic> && data['accessToken'] != null) {
          _memoryAccessToken = data['accessToken'].toString();
          _lastTokenRefresh = DateTime.now();
          return true;
        }
      }
      if (response.statusCode == 401) {
        await _checkSessionDisplaced(response);
      }
    } catch (_) {}
    return false;
  }

  /// Obtiene la URL base según la variable de entorno (--dart-define=API_BASE_URL=...)
  /// o la configuración por defecto de la plataforma (Web o Móvil Android)
  static String get baseHost {
    if (_envApiHost.trim().isNotEmpty) {
      var clean = _envApiHost.trim();
      if (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      return clean;
    }
    if (kIsWeb) {
      return 'http://localhost:9090';
    }
    // En emulador Android 10.0.2.2 apunta al localhost de la máquina anfitriona
    return 'http://10.0.2.2:9090';
  }

  static String get apiBaseUrl => '$baseHost/api/v1';

  /// Parsea una lista de elementos de catálogo ({id, nombre, codigoPostal?})
  static List<CatalogItem> _parseCatalogList(dynamic data) {
    if (data is! List) return [];
    final items = <CatalogItem>[];
    for (int i = 0; i < data.length; i++) {
      final raw = data[i];
      if (raw is Map<String, dynamic>) {
        items.add(CatalogItem(
          id: (raw['id'] as num?)?.toInt() ?? -(i + 1),
          nombre: (raw['nombre'] ?? '').toString(),
          codigoPostal: raw['codigoPostal']?.toString(),
        ));
      } else if (raw is String) {
        items.add(CatalogItem(id: i + 1, nombre: raw));
      }
    }
    return items;
  }

  /// Obtiene el catálogo oficial de países desde el backend con fallback local
  static Future<List<CatalogItem>> getPaises() async {
    try {
      final res = await http
          .get(Uri.parse('$apiBaseUrl/catalogos/paises'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = _safeDecode(res.body);
        final parsed = _parseCatalogList(body['data']);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}
    const names = [
      'México', 'Estados Unidos', 'Canadá', 'España', 'Argentina', 'Colombia',
      'Brasil', 'Chile', 'Perú', 'Alemania', 'Francia', 'Italia', 'Reino Unido',
      'Japón', 'China', 'Corea del Sur', 'Australia', 'Portugal', 'Países Bajos',
      'Suiza', 'Suecia', 'Costa Rica', 'Panamá', 'Uruguay', 'Ecuador', 'Guatemala',
      'India', 'Rusia', 'Turquía', 'Sudáfrica', 'Otro',
    ];
    return [
      for (int i = 0; i < names.length; i++)
        CatalogItem(id: names[i] == 'Otro' ? -1 : i + 1, nombre: names[i]),
    ];
  }

  /// Obtiene el catálogo oficial de ocupaciones desde el backend con fallback local
  static Future<List<CatalogItem>> getOcupaciones() async {
    try {
      final res = await http
          .get(Uri.parse('$apiBaseUrl/catalogos/ocupaciones'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = _safeDecode(res.body);
        final parsed = _parseCatalogList(body['data']);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}
    const names = [
      'Ingeniería y Desarrollo de Software', 'Medicina y Servicios de Salud',
      'Docencia y Educación', 'Contabilidad y Auditoría', 'Administración y Gestión Empresarial',
      'Comercio y Ventas', 'Derecho y Servicios Jurídicos', 'Arquitectura y Construcción',
      'Estudiante', 'Empleado Administrativo', 'Transporte y Logística', 'Hostelería y Turismo',
      'Arte y Diseño Digital', 'Finanzas y Banca', 'Independiente / Emprendedor',
      'Sector Agropecuario e Industrial', 'Servicios Generales y Mantenimiento',
      'Investigación Científica', 'Otra',
    ];
    return [
      for (int i = 0; i < names.length; i++)
        CatalogItem(id: names[i] == 'Otra' ? -1 : i + 1, nombre: names[i]),
    ];
  }

  /// Obtiene el catálogo de estados/entidades relacionado con un país
  static Future<List<CatalogItem>> getEstados(int paisId) async {
    if (paisId > 0) {
      try {
        final res = await http
            .get(Uri.parse('$apiBaseUrl/catalogos/estados?paisId=$paisId'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final body = _safeDecode(res.body);
          final parsed = _parseCatalogList(body['data']);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {}
    }
    if (paisId == 1) {
      const mxStates = [
        'Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche',
        'Chiapas', 'Chihuahua', 'Ciudad de México', 'Coahuila', 'Colima',
        'Durango', 'Estado de México', 'Guanajuato', 'Guerrero', 'Hidalgo',
        'Jalisco', 'Michoacán', 'Morelos', 'Nayarit', 'Nuevo León', 'Oaxaca',
        'Puebla', 'Querétaro', 'Quintana Roo', 'San Luis Potosí', 'Sinaloa',
        'Sonora', 'Tabasco', 'Tamaulipas', 'Tlaxcala', 'Veracruz', 'Yucatán',
        'Zacatecas',
      ];
      return [
        for (int i = 0; i < mxStates.length; i++)
          CatalogItem(id: i + 1, nombre: mxStates[i]),
        const CatalogItem(id: -1, nombre: 'Otro'),
      ];
    }
    return const [CatalogItem(id: -1, nombre: 'Otro')];
  }

  /// Obtiene el catálogo de municipios/alcaldías relacionado con un estado
  static Future<List<CatalogItem>> getMunicipios(int estadoId) async {
    if (estadoId > 0) {
      try {
        final res = await http
            .get(Uri.parse('$apiBaseUrl/catalogos/municipios?estadoId=$estadoId'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final body = _safeDecode(res.body);
          final parsed = _parseCatalogList(body['data']);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {}
    }
    if (estadoId == 12) {
      const gtoMun = [
        'Dolores Hidalgo', 'San Miguel de Allende', 'Guanajuato', 'León',
        'Celaya', 'Irapuato', 'Salamanca', 'Silao', 'San Luis de la Paz',
      ];
      return [
        for (int i = 0; i < gtoMun.length; i++)
          CatalogItem(id: i + 1, nombre: gtoMun[i]),
        const CatalogItem(id: -1, nombre: 'Otro'),
      ];
    }
    return const [CatalogItem(id: -1, nombre: 'Otro')];
  }

  /// Obtiene el catálogo de colonias y comunidades relacionado con un municipio
  static Future<List<CatalogItem>> getColonias(int municipioId) async {
    if (municipioId > 0) {
      try {
        final res = await http
            .get(Uri.parse('$apiBaseUrl/catalogos/colonias?municipioId=$municipioId'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final body = _safeDecode(res.body);
          final parsed = _parseCatalogList(body['data']);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {}
    }
    if (municipioId == 1) {
      const dhItems = [
        ('Centro', '37800'),
        ('Lindavista', '37800'),
        ('San Cristóbal', '37800'),
        ('Guanajuato', '37800'),
        ('Mariano Balleza', '37800'),
        ('Todos Santos', '37800'),
        ('Fraccionamiento Independencia', '37800'),
        ('El Saucillo', '37848'),
        ('Remátalo', '37830'),
        ('Don Pedro', '37830'),
        ('Xoconoxtle el Grande', '37830'),
        ('Xoconoxtle el Chico', '37830'),
        ('Río Laja', '37810'),
        ('El Llanito', '37840'),
        ('La Erre', '37842'),
        ('Adjuntas del Río', '37814'),
        ('La Ventilla', '37842'),
        ('San Gabriel', '37817'),
        ('El Gallinero', '37829'),
        ('San Antón de las Minas', '37849'),
        ('San Marcos de Abajo', '37848'),
        ('San Marcos de Arriba', '37848'),
        ('San Martín de Terreros', '37838'),
        ('Peñuelitas', '37814'),
        ('Santa Bárbara', '37832'),
        ('Trancas', '37828'),
        ('Tequisquiapan', '37814'),
        ('Tierra Blanca', '37843'),
        ('Zamarripa', '37825'),
      ];
      return [
        for (int i = 0; i < dhItems.length; i++)
          CatalogItem(id: i + 1, nombre: dhItems[i].$1, codigoPostal: dhItems[i].$2),
        const CatalogItem(id: -1, nombre: 'Otra'),
      ];
    }
    return const [CatalogItem(id: -1, nombre: 'Otra')];
  }

  static Future<void> initServerHost() async {}

  static void recordUserActivity() {
    _lastActivity = DateTime.now();
  }

  static bool isInactivityExpired() {
    return DateTime.now().difference(_lastActivity) > sessionInactivityLimit;
  }

  static Future<Map<String, String>> _buildAuthHeaders({Map<String, String>? extra}) async {
    final accessToken = _memoryAccessToken ?? '';
    final refreshToken = _memoryRefreshToken ?? '';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    if (refreshToken.isNotEmpty) {
      headers['X-Session-Token'] = refreshToken;
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// Paso 1 del Login: Valida credenciales y verifica si existe otra sesión activa en Web/Móvil
  static Future<ApiResult<Map<String, dynamic>>> preLogin({
    required String correo,
    required String password,
    bool forceClosePrevious = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/auth/pre-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'correo': correo.trim(),
              'password': password,
              'forceClosePrevious': forceClosePrevious,
              'platform': kIsWeb ? 'WEB' : 'MOBILE_ANDROID',
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0) {
        final data = (body['data'] as Map<String, dynamic>?) ?? {};
        return ApiResult(
          success: true,
          message: (body['mensaje'] ?? 'Credenciales verificadas').toString(),
          data: data,
          statusCode: response.statusCode,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Error de comunicación con el servidor ($baseHost). Verifica tu conexión.',
        statusCode: 503,
      );
    }
  }

  /// Paso 2 del Login: Valida el segundo factor (2FA / PIN o código OTP) en el servidor y crea la sesión única
  static Future<ApiResult<Map<String, dynamic>>> verify2faAndLogin({
    required String correo,
    required String password,
    required String codigo2fa,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/auth/verify-2fa'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'correo': correo.trim(),
              'password': password,
              'codigo2fa': codigo2fa.trim(),
              'forceClosePrevious': true,
              'platform': kIsWeb ? 'WEB' : 'MOBILE_ANDROID',
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0) {
        final data = (body['data'] as Map<String, dynamic>?) ?? {};
        await _persistSession(data, correo.trim());
        recordUserActivity();
        return ApiResult(
          success: true,
          message: (body['mensaje'] ?? 'Autenticación exitosa').toString(),
          data: data,
          statusCode: response.statusCode,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Error de comunicación al validar 2FA con el servidor.',
        statusCode: 503,
      );
    }
  }

  /// Registro completo de nuevo cliente Fintech (Onboarding con creación de cuenta y PIN único)
  static Future<ApiResult<Map<String, dynamic>>> registrarCliente(
      Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/clientes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final body = _safeDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['codigo'] == 0) {
        final data = (body['data'] as Map<String, dynamic>?) ?? {};
        return ApiResult(
          success: true,
          message: (body['mensaje'] ?? 'Cliente registrado exitosamente').toString(),
          data: data,
          statusCode: response.statusCode,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'No fue posible conectar con el servidor para completar el registro.',
        statusCode: 503,
      );
    }
  }

  /// Obtiene el perfil del usuario autenticado y sus cuentas bancarias con saldo en vivo
  static Future<ApiResult<UserProfileModel>> obtenerPerfilYCuentas() async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .post(Uri.parse('$apiBaseUrl/usuarios/perfil'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (await _checkSessionDisplaced(response)) {
        return ApiResult(
          success: false,
          message: 'Tu sesión fue cerrada porque ingresaste desde otro dispositivo.',
          statusCode: 401,
          sessionDisplaced: true,
        );
      }

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0 && body['data'] != null) {
        final profile = UserProfileModel.fromJson(body['data'] as Map<String, dynamic>);
        return ApiResult(
          success: true,
          message: 'Perfil actualizado',
          data: profile,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'No se pudo cargar la información de la cuenta.',
        statusCode: 503,
      );
    }
  }

  /// Consulta el catálogo oficial de productos de GestoPago
  static Future<ApiResult<List<GestoPagoProductModel>>> obtenerCatalogoProductos() async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .get(Uri.parse('$apiBaseUrl/gestopago/products'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (await _checkSessionDisplaced(response)) {
        return ApiResult(
          success: false,
          message: 'Sesión finalizada en otro dispositivo.',
          statusCode: 401,
          sessionDisplaced: true,
        );
      }

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0) {
        final rawList = body['data'] as List<dynamic>? ?? [];
        final products = rawList
            .whereType<Map<String, dynamic>>()
            .map(GestoPagoProductModel.fromJson)
            .toList();
        return ApiResult(
          success: true,
          message: 'Catálogo cargado (${products.length} productos)',
          data: products,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Error de comunicación al consultar el catálogo de GestoPago.',
        statusCode: 503,
      );
    }
  }

  /// Fuerza la sincronización del catálogo en vivo con GestoPago
  static Future<ApiResult<int>> sincronizarCatalogoGestoPago() async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .post(Uri.parse('$apiBaseUrl/gestopago/products/sync'), headers: headers)
          .timeout(const Duration(seconds: 40));

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0) {
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final total = (data['total_productos'] as num?)?.toInt() ?? 0;
        return ApiResult(
          success: true,
          message: 'Catálogo sincronizado con GestoPago ($total productos)',
          data: total,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Tiempo de espera agotado o error al sincronizar con GestoPago.',
        statusCode: 503,
      );
    }
  }

  /// Procesa una operación de compra / pago de servicio con GestoPago
  static Future<ApiResult<TransactionModel>> realizarCompra({
    required String numeroCuenta,
    required int idProducto,
    int? idServicio,
    required double monto,
    String? telefono,
    String? referencia,
    required String pin,
    required String idempotencyKey,
  }) async {
    try {
      final headers = await _buildAuthHeaders(extra: {
        'Idempotency-Key': idempotencyKey,
      });

      final payload = <String, dynamic>{
        'idempotencyKey': idempotencyKey,
        'numeroCuenta': numeroCuenta.trim(),
        'idProducto': idProducto,
        'monto': double.parse(monto.toStringAsFixed(2)),
        'pin': pin.trim(),
      };
      if (idServicio != null) payload['idServicio'] = idServicio;
      if (telefono != null && telefono.trim().isNotEmpty) {
        payload['telefono'] = telefono.trim();
      }
      if (referencia != null && referencia.trim().isNotEmpty) {
        payload['referencia'] = referencia.trim();
      }

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/gestopago/transactions/pagar'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 68));

      if (await _checkSessionDisplaced(response)) {
        return ApiResult(
          success: false,
          message: 'Tu sesión fue cerrada porque ingresaste en otro dispositivo.',
          statusCode: 401,
          sessionDisplaced: true,
        );
      }

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['data'] != null) {
        final tx = TransactionModel.fromJson(body['data'] as Map<String, dynamic>);
        return ApiResult(
          success: tx.isSucceeded,
          message: (body['mensaje'] ?? tx.estadoLabel).toString(),
          data: tx,
          statusCode: response.statusCode,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return ApiResult(
        success: false,
        message: 'ERROR_COMUNICACION: Tiempo de espera agotado con GestoPago. Verifica tu historial antes de reintentar.',
        statusCode: 504,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'ERROR_COMUNICACION: No fue posible contactar al servidor de pagos.',
        statusCode: 503,
      );
    }
  }

  /// Consulta el historial de transacciones del usuario autenticado
  static Future<ApiResult<List<TransactionModel>>> obtenerHistorialCompras() async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .post(Uri.parse('$apiBaseUrl/gestopago/transactions/historial'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (await _checkSessionDisplaced(response)) {
        return ApiResult(
          success: false,
          message: 'Sesión finalizada en otro dispositivo.',
          statusCode: 401,
          sessionDisplaced: true,
        );
      }

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0) {
        final rawList = body['data'] as List<dynamic>? ?? [];
        final list = rawList
            .whereType<Map<String, dynamic>>()
            .map(TransactionModel.fromJson)
            .toList();
        return ApiResult(
          success: true,
          message: 'Historial obtenido',
          data: list,
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Error de comunicación al consultar el historial de compras.',
        statusCode: 503,
      );
    }
  }

  /// Consulta el detalle puntual de una compra por su operationId sin usar @PathVariable
  static Future<ApiResult<TransactionModel>> obtenerDetalleCompra(String operationId) async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/gestopago/transactions/detalle'),
            headers: headers,
            body: jsonEncode({'operationId': operationId}),
          )
          .timeout(const Duration(seconds: 15));

      if (await _checkSessionDisplaced(response)) {
        return ApiResult(
          success: false,
          message: 'Sesión finalizada en otro dispositivo.',
          statusCode: 401,
          sessionDisplaced: true,
        );
      }

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0 && body['data'] != null) {
        return ApiResult(
          success: true,
          message: 'Detalle obtenido',
          data: TransactionModel.fromJson(body['data'] as Map<String, dynamic>),
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Error al consultar el detalle de la operación.',
        statusCode: 503,
      );
    }
  }

  /// Verifica el PIN de seguridad de 4 dígitos contra el servidor
  static Future<ApiResult<bool>> verificarPin(String pin) async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/usuarios/verificar-pin'),
            headers: headers,
            body: jsonEncode({'pin': pin.trim()}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'PIN verificado correctamente', data: true);
      }
      final body = _safeDecode(response.body);
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        data: false,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiResult(
        success: false,
        message: 'No fue posible validar el PIN en el servidor.',
        data: false,
        statusCode: 503,
      );
    }
  }

  /// Actualiza el PIN de seguridad de 4 dígitos
  static Future<ApiResult<String>> actualizarPin(String nuevoPin) async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .patch(
            Uri.parse('$apiBaseUrl/usuarios/pin'),
            headers: headers,
            body: jsonEncode({'pin': nuevoPin.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (await _checkSessionDisplaced(response)) {
        return ApiResult(
          success: false,
          message: 'Sesión desplazada.',
          statusCode: 401,
          sessionDisplaced: true,
        );
      }

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0) {
        return ApiResult(
          success: true,
          message: (body['mensaje'] ?? 'PIN actualizado exitosamente').toString(),
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'No fue posible actualizar el PIN.',
        statusCode: 503,
      );
    }
  }

  /// Cambia la contraseña del usuario
  static Future<ApiResult<String>> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
    required String passwordConfirmacion,
  }) async {
    try {
      final headers = await _buildAuthHeaders();
      final response = await http
          .patch(
            Uri.parse('$apiBaseUrl/usuarios/password'),
            headers: headers,
            body: jsonEncode({
              'passwordActual': passwordActual,
              'passwordNueva': passwordNueva,
              'passwordConfirmacion': passwordConfirmacion,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (await _checkSessionDisplaced(response)) {
        return ApiResult(
          success: false,
          message: 'Sesión desplazada.',
          statusCode: 401,
          sessionDisplaced: true,
        );
      }

      final body = _safeDecode(response.body);
      if (response.statusCode == 200 && body['codigo'] == 0) {
        return ApiResult(
          success: true,
          message: (body['mensaje'] ?? 'Contraseña actualizada exitosamente').toString(),
        );
      }
      return ApiResult(
        success: false,
        message: _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Error al actualizar la contraseña.',
        statusCode: 503,
      );
    }
  }

  /// Cierra la sesión de manera segura tanto en el servidor (Redis + BD) como localmente
  static Future<void> logout() async {
    try {
      final correo = _memoryCorreo;
      final headers = await _buildAuthHeaders();
      await http
          .post(
            Uri.parse('$apiBaseUrl/auth/logout'),
            headers: headers,
            body: jsonEncode({'correo': correo}),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Incluso si falla la red, limpiamos credenciales locales de forma segura
    } finally {
      await clearLocalSession();
    }
  }

  static Future<void> clearLocalSession() async {
    _memoryAccessToken = null;
    _memoryRefreshToken = null;
    _memoryCorreo = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> _persistSession(Map<String, dynamic> data, String correo) async {
    _memoryAccessToken = data['accessToken']?.toString();
    _memoryRefreshToken = data['refreshToken']?.toString();
    _memoryCorreo = correo;
    _lastActivity = DateTime.now();
    _lastTokenRefresh = DateTime.now();
  }

  static Future<bool> hasActiveLocalSession() async {
    final token = _memoryAccessToken;
    return token != null && token.isNotEmpty;
  }

  static Future<bool> _checkSessionDisplaced(http.Response response) async {
    if (response.statusCode == 401) {
      final body = _safeDecode(response.body);
      final msg = (body['mensaje'] ?? '').toString();
      await clearLocalSession();
      if (onSessionInvalidated != null) {
        if (msg.contains('SESION_DESPLAZADA')) {
          onSessionInvalidated!(
            'Sesión cerrada: iniciaste sesión en otro dispositivo.',
          );
        } else {
          onSessionInvalidated!(
            'Tu sesión expiró. Inicia sesión nuevamente.',
          );
        }
      }
      return true;
    }
    return false;
  }

  static Map<String, dynamic> _safeDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    if (body['mensaje'] != null && body['mensaje'].toString().trim().isNotEmpty) {
      return body['mensaje'].toString();
    }
    if (statusCode == 401) return 'Credenciales o código de verificación inválidos.';
    if (statusCode == 403) return 'No tienes permisos para realizar esta operación.';
    if (statusCode == 404) return 'El recurso solicitado no fue encontrado.';
    return 'No se pudo procesar la solicitud (Código HTTP $statusCode).';
  }
}

