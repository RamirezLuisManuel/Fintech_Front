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

class ApiService {
  static const String _envApiHost = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static String _customBaseHost = '';
  static void Function(String reason)? onSessionInvalidated;
  static DateTime _lastActivity = DateTime.now();
  static const Duration sessionInactivityLimit = Duration(minutes: 25);

  /// Obtiene la URL base según la variable de entorno (Render), configuración manual o plataforma
  static String get baseHost {
    if (_customBaseHost.isNotEmpty) return _customBaseHost;
    if (_envApiHost.isNotEmpty) return _envApiHost;
    if (kIsWeb) {
      return 'http://localhost:9090';
    }
    // En emulador Android 10.0.2.2 apunta al localhost de la máquina anfitriona
    return 'http://10.0.2.2:9090';
  }

  static String get apiBaseUrl => '$baseHost/api/v1';

  static Future<void> initServerHost() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString('server_base_host');
    if (savedHost != null && savedHost.trim().isNotEmpty) {
      _customBaseHost = savedHost.trim();
    }
  }

  static Future<void> setServerHost(String hostUrl) async {
    var clean = hostUrl.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    _customBaseHost = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_base_host', clean);
  }

  static void recordUserActivity() {
    _lastActivity = DateTime.now();
  }

  static bool isInactivityExpired() {
    return DateTime.now().difference(_lastActivity) > sessionInactivityLimit;
  }

  static Future<Map<String, String>> _buildAuthHeaders({Map<String, String>? extra}) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken') ?? '';
    final refreshToken = prefs.getString('refreshToken') ?? '';
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
        final prefs = await SharedPreferences.getInstance();
        if (profile.cuentas.isNotEmpty) {
          await prefs.setString('numeroCuenta', profile.cuentas.first.numeroCuenta);
        }
        await prefs.setString('nombreCompleto', profile.nombreCompleto);
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
      final prefs = await SharedPreferences.getInstance();
      final correo = prefs.getString('correo');
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
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString('server_base_host');
    await prefs.clear();
    if (savedHost != null) {
      await prefs.setString('server_base_host', savedHost);
    }
  }

  static Future<void> _persistSession(Map<String, dynamic> data, String correo) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['accessToken'] != null) {
      await prefs.setString('accessToken', data['accessToken'].toString());
    }
    if (data['refreshToken'] != null) {
      await prefs.setString('refreshToken', data['refreshToken'].toString());
    }
    if (data['numeroCuenta'] != null) {
      await prefs.setString('numeroCuenta', data['numeroCuenta'].toString());
    }
    if (data['nombreCompleto'] != null) {
      await prefs.setString('nombreCompleto', data['nombreCompleto'].toString());
    }
    if (data['clienteId'] != null) {
      await prefs.setInt('clienteId', (data['clienteId'] as num).toInt());
    }
    await prefs.setString('correo', correo);
    await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> hasActiveLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
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
            'Se detectó un nuevo inicio de sesión con tu cuenta en otro dispositivo o navegador. Por seguridad, esta sesión ha sido cerrada.',
          );
        } else {
          onSessionInvalidated!(
            'Tu sesión ha expirado o fue cerrada. Por favor inicia sesión nuevamente.',
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

