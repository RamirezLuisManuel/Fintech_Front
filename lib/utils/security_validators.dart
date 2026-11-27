import 'package:flutter/services.dart';
import 'currency_formatter.dart';

/// Utilidades de validación de formularios y prevención de inyecciones (SQLi / XSS / DOM)
class SecurityValidators {
  /// Formateador seguro para campos de búsqueda (bloquea caracteres de inyección SQL/HTML/DOM)
  static final TextInputFormatter safeSearchFormatter =
      FilteringTextInputFormatter.deny(RegExp(r'[<>"\x27;\\`\x00]'));

  // Patrones de detección de intentos de inyección SQL, XSS, DOM o comandos
  static final List<RegExp> _injectionPatterns = [
    RegExp(r"<\s*(script|iframe|svg|object|embed|img|body|link|style|meta|form)", caseSensitive: false),
    RegExp(r"</\s*script", caseSensitive: false),
    RegExp(r"(javascript|vbscript|data\s*:\s*text/html)\s*:", caseSensitive: false),
    RegExp(r"\bon\w+\s*=", caseSensitive: false),
    RegExp(r"\b(document\.(cookie|domain|write|location)|window\.location|innerHTML|outerHTML)\b", caseSensitive: false),
    RegExp(r"\b(eval|alert|prompt|confirm|setTimeout|setInterval|Function)\s*\(", caseSensitive: false),
    RegExp(r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|EXEC|EXECUTE|TRUNCATE|WAITFOR|INFORMATION_SCHEMA|XP_CMDSHELL)\b)", caseSensitive: false),
    RegExp(r"\b(SLEEP|BENCHMARK|PG_SLEEP)\s*\(", caseSensitive: false),
    RegExp(r"(--|/\*|\*/|;|\x00)"),
    RegExp(r"('\s*(OR|AND)\s*'|'\s*=\s*'|\bOR\s+1\s*=\s*1\b)", caseSensitive: false),
  ];

  /// Verifica si una cadena contiene patrones sospechosos de inyección
  static bool containsInjectionAttempt(String? input) {
    if (input == null || input.isEmpty) return false;
    for (final pattern in _injectionPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  /// Sanitiza texto eliminando etiquetas HTML y caracteres de control peligrosos
  static String sanitize(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
  }

  /// Valida correo electrónico (sin espacios)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '• El correo electrónico es obligatorio';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return '• El correo electrónico no puede contener espacios';
    }
    final clean = value;
    if (containsInjectionAttempt(clean)) {
      return '• Se detectaron caracteres no permitidos por seguridad';
    }
    if (clean.length > 100) {
      return '• El correo no puede exceder 100 caracteres';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.(com|com\.mx|mx|org|net|edu|gob)$',
      caseSensitive: false,
    );
    if (!emailRegex.hasMatch(clean)) {
      return '• Ingresa un correo electrónico válido (ej. usuario@dominio.com)';
    }
    return null;
  }

  /// Valida contraseña en login
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '• La contraseña es obligatoria';
    }
    if (containsInjectionAttempt(value)) {
      return '• Caracteres inválidos detectados en la contraseña';
    }
    if (value.length < 6 || value.length > 100) {
      return '• La contraseña debe tener entre 6 y 100 caracteres';
    }
    return null;
  }

  /// Valida contraseña fuerte para registro / cambio de contraseña (8 a 13 caracteres)
  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '• La contraseña es obligatoria';
    }
    if (containsInjectionAttempt(value)) {
      return '• Contiene caracteres restringidos por seguridad';
    }
    final missing = <String>[];
    if (RegExp(r'\s').hasMatch(value)) {
      missing.add('No puede contener espacios');
    }
    if (value.length < 8) {
      missing.add('Mínimo 8 caracteres');
    }
    if (value.length > 13) {
      missing.add('Máximo 13 caracteres');
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      missing.add('Al menos una letra mayúscula');
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      missing.add('Al menos una letra minúscula');
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      missing.add('Al menos un número');
    }
    if (!RegExp(r'[@#$%^&+=!*._-]').hasMatch(value)) {
      missing.add('Al menos un carácter especial (@#\$%^&*...)');
    }
    if (missing.isEmpty) return null;
    return missing.map((e) => '• $e').join('\n');
  }

  /// Valida código 2FA (OTP de 6 dígitos o PIN de 4 dígitos)
  static String? validate2faOrPin(String? value, {bool onlyFourDigits = false}) {
    if (value == null || value.trim().isEmpty) {
      return onlyFourDigits
          ? '• El PIN de seguridad es obligatorio'
          : '• El código de verificación es obligatorio';
    }
    final clean = value.trim();
    final regex = onlyFourDigits ? RegExp(r'^\d{4}$') : RegExp(r'^\d{4,6}$');
    if (!regex.hasMatch(clean)) {
      return onlyFourDigits
          ? '• El PIN debe contener exactamente 4 dígitos numéricos'
          : '• Ingresa los 4 dígitos de tu PIN o los 6 dígitos del código OTP';
    }
    return null;
  }

  /// Valida teléfono a 10 dígitos (sin espacios)
  static String? validatePhone(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? '• El número telefónico es obligatorio' : null;
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return '• El teléfono no puede contener espacios';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return '• El teléfono debe contener exactamente 10 dígitos numéricos';
    }
    return null;
  }

  /// Valida referencia de pago de servicio
  static String? validateReference(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? '• La referencia del servicio es obligatoria' : null;
    }
    final clean = value.trim();
    if (containsInjectionAttempt(clean)) {
      return '• Referencia inválida por seguridad';
    }
    if (clean.length < 3 || clean.length > 100) {
      return '• La referencia debe tener entre 3 y 100 caracteres';
    }
    if (!RegExp(r'^[A-Za-z0-9#-]+$').hasMatch(clean)) {
      return '• Solo se permiten letras, números, # y guion (-)';
    }
    return null;
  }

  /// Valida monto monetario (soporta separadores de miles con comas y opcionalmente 0)
  static String? validateAmount(
    String? value, {
    double? exactPrice,
    bool allowZero = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '• El monto es obligatorio';
    }
    final clean = value.replaceAll(',', '').trim();
    final parsed = double.tryParse(clean);
    if (parsed == null || (allowZero ? parsed < 0 : parsed <= 0)) {
      return allowZero
          ? '• Ingresa un monto válido (0 o mayor)'
          : '• Ingresa un monto válido mayor a \$0.00';
    }
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
      return '• El monto solo puede tener hasta 2 decimales';
    }
    if (exactPrice != null && exactPrice > 0 && (parsed - exactPrice).abs() > 0.001) {
      return '• El monto debe coincidir con el precio del producto (${CurrencyFormatter.format(exactPrice)})';
    }
    return null;
  }

  /// Valida nombres y apellidos (inicia con mayúscula, sin espacios, mínimo 3 y máximo 50 caracteres)
  static String? validatePersonName(String? value, String fieldLabel, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? '• $fieldLabel es obligatorio' : null;
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return '• $fieldLabel no puede contener espacios';
    }
    if (!RegExp(r'^[A-ZÁÉÍÓÚÑ]').hasMatch(value)) {
      return '• $fieldLabel debe iniciar con letra mayúscula';
    }
    if (value.length < 3 || value.length > 50) {
      return '• $fieldLabel debe tener entre 3 y 50 caracteres';
    }
    if (!RegExp(r'^[A-ZÁÉÍÓÚÑ][a-zA-ZÁÉÍÓÚáéíóúÑñ]*$').hasMatch(value)) {
      return '• $fieldLabel solo puede contener letras';
    }
    return null;
  }

  /// Valida que el usuario tenga al menos 18 años cumplidos
  static String? validateAge18Plus(int year, int month, int day) {
    final now = DateTime.now();
    final birth = DateTime(year, month, day);
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    if (age < 18) {
      return '• Debes tener al menos 18 años cumplidos para aperturar la cuenta';
    }
    return null;
  }

  /// Valida CURP oficial (18 caracteres, solo letras mayúsculas y números, sin signos ni espacios)
  static String? validateCurp(String? value) {
    if (value == null || value.isEmpty) {
      return '• La CURP es obligatoria';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return '• La CURP no puede contener espacios';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value)) {
      return '• La CURP solo acepta letras mayúsculas y números (sin signos)';
    }
    final curpRegex = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$');
    if (!curpRegex.hasMatch(value)) {
      return '• Formato de CURP inválido (18 caracteres oficiales)';
    }
    return null;
  }

  /// Valida RFC oficial (12 o 13 caracteres, solo letras mayúsculas y números, sin signos ni espacios)
  static String? validateRfc(String? value) {
    if (value == null || value.isEmpty) {
      return '• El RFC es obligatorio';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return '• El RFC no puede contener espacios';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value)) {
      return '• El RFC solo acepta letras mayúsculas y números (sin signos)';
    }
    final rfcRegex = RegExp(r'^[A-Z]{3,4}\d{6}[A-Z0-9]{3}$');
    if (!rfcRegex.hasMatch(value)) {
      return '• Formato de RFC inválido (12 o 13 caracteres con homoclave)';
    }
    return null;
  }

  /// Valida código postal (5 dígitos)
  static String? validatePostalCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '• El código postal es obligatorio';
    }
    if (!RegExp(r'^\d{5}$').hasMatch(value.trim())) {
      return '• Debe contener exactamente 5 dígitos numéricos';
    }
    return null;
  }

  /// Valida campo de texto general seguro
  static String? validateSafeText(String? value, String label, {int min = 2, int max = 100}) {
    if (value == null || value.trim().isEmpty) {
      return '• $label es obligatorio';
    }
    final clean = value.trim();
    if (containsInjectionAttempt(clean)) {
      return '• $label contiene caracteres no permitidos';
    }
    if (clean.length < min || clean.length > max) {
      return '• $label debe tener entre $min y $max caracteres';
    }
    return null;
  }
}

