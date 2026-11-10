/// Utilidades de validación de formularios y prevención de inyecciones (SQLi / XSS)
class SecurityValidators {
  // Patrones de detección de intentos de inyección SQL, XSS o comandos
  static final List<RegExp> _injectionPatterns = [
    RegExp(r"<\s*script", caseSensitive: false),
    RegExp(r"javascript\s*:", caseSensitive: false),
    RegExp(r"on\w+\s*=", caseSensitive: false),
    RegExp(r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|EXEC|TRUNCATE)\b)", caseSensitive: false),
    RegExp(r"(--|/\*|\*/|;|\x00)"),
    RegExp(r"('\s*(OR|AND)\s*')", caseSensitive: false),
    RegExp(r"('\s*=\s*')", caseSensitive: false),
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

  /// Valida correo electrónico
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo electrónico es obligatorio';
    }
    final clean = value.trim();
    if (containsInjectionAttempt(clean)) {
      return 'Se detectaron caracteres no permitidos por seguridad';
    }
    if (clean.length > 100) {
      return 'El correo no puede exceder 100 caracteres';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(clean)) {
      return 'Ingresa un correo electrónico válido (ej. usuario@dominio.com)';
    }
    return null;
  }

  /// Valida contraseña en login
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (containsInjectionAttempt(value)) {
      return 'Caracteres inválidos detectados en la contraseña';
    }
    if (value.length < 6 || value.length > 100) {
      return 'La contraseña debe tener entre 6 y 100 caracteres';
    }
    return null;
  }

  /// Valida contraseña fuerte para registro / cambio de contraseña
  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (containsInjectionAttempt(value)) {
      return 'La contraseña contiene secuencias restringidas';
    }
    if (value.length < 8) {
      return 'Mínimo 8 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Debe incluir al menos una letra mayúscula';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Debe incluir al menos una letra minúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Debe incluir al menos un número';
    }
    if (!RegExp(r'[@#$%^&+=!*._-]').hasMatch(value)) {
      return 'Debe incluir un carácter especial (@#\$%^&+=!)';
    }
    return null;
  }

  /// Valida código 2FA (OTP de 6 dígitos o PIN de 4 dígitos)
  static String? validate2faOrPin(String? value, {bool onlyFourDigits = false}) {
    if (value == null || value.trim().isEmpty) {
      return onlyFourDigits
          ? 'El PIN de seguridad es obligatorio'
          : 'El código de verificación es obligatorio';
    }
    final clean = value.trim();
    final regex = onlyFourDigits ? RegExp(r'^\d{4}$') : RegExp(r'^\d{4,6}$');
    if (!regex.hasMatch(clean)) {
      return onlyFourDigits
          ? 'El PIN debe contener exactamente 4 dígitos numéricos'
          : 'Ingresa los 4 dígitos de tu PIN o los 6 dígitos del código OTP';
    }
    return null;
  }

  /// Valida teléfono a 10 dígitos
  static String? validatePhone(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'El número telefónico es obligatorio' : null;
    }
    final clean = value.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return 'El teléfono debe contener exactamente 10 dígitos numéricos';
    }
    return null;
  }

  /// Valida referencia de pago de servicio
  static String? validateReference(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'La referencia del servicio es obligatoria' : null;
    }
    final clean = value.trim();
    if (containsInjectionAttempt(clean)) {
      return 'Referencia inválida por seguridad';
    }
    if (clean.length < 3 || clean.length > 100) {
      return 'La referencia debe tener entre 3 y 100 caracteres';
    }
    if (!RegExp(r'^[A-Za-z0-9#-]+$').hasMatch(clean)) {
      return 'Solo se permiten letras, números, # y guion (-)';
    }
    return null;
  }

  /// Valida monto monetario
  static String? validateAmount(String? value, {double? exactPrice}) {
    if (value == null || value.trim().isEmpty) {
      return 'El monto es obligatorio';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'Ingresa un monto válido mayor a \$0.00';
    }
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim())) {
      return 'El monto solo puede tener hasta 2 decimales';
    }
    if (exactPrice != null && exactPrice > 0 && (parsed - exactPrice).abs() > 0.001) {
      return 'El monto debe coincidir con el precio del producto (\$${exactPrice.toStringAsFixed(2)})';
    }
    return null;
  }

  /// Valida nombres y apellidos (solo letras y espacios)
  static String? validatePersonName(String? value, String fieldLabel, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldLabel es obligatorio' : null;
    }
    final clean = value.trim();
    if (clean.length < 2 || clean.length > 50) {
      return '$fieldLabel debe tener entre 2 y 50 caracteres';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(clean)) {
      return '$fieldLabel solo puede contener letras sin acentos y espacios';
    }
    return null;
  }

  /// Valida CURP oficial (18 caracteres)
  static String? validateCurp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La CURP es obligatoria';
    }
    final clean = value.trim().toUpperCase();
    final curpRegex = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z\d]\d$');
    if (!curpRegex.hasMatch(clean)) {
      return 'Formato de CURP inválido (18 caracteres oficiales)';
    }
    return null;
  }

  /// Valida RFC oficial (12 o 13 caracteres)
  static String? validateRfc(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El RFC es obligatorio';
    }
    final clean = value.trim().toUpperCase();
    final rfcRegex = RegExp(r'^[A-Z&Ñ]{3,4}\d{6}[A-Z\d]{3}$');
    if (!rfcRegex.hasMatch(clean)) {
      return 'Formato de RFC inválido (13 caracteres con homoclave)';
    }
    return null;
  }

  /// Valida código postal (5 dígitos)
  static String? validatePostalCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código postal es obligatorio';
    }
    if (!RegExp(r'^\d{5}$').hasMatch(value.trim())) {
      return 'Debe contener exactamente 5 dígitos';
    }
    return null;
  }

  /// Valida campo de texto general seguro
  static String? validateSafeText(String? value, String label, {int min = 2, int max = 100}) {
    if (value == null || value.trim().isEmpty) {
      return '$label es obligatorio';
    }
    final clean = value.trim();
    if (containsInjectionAttempt(clean)) {
      return '$label contiene caracteres no permitidos';
    }
    if (clean.length < min || clean.length > max) {
      return '$label debe tener entre $min y $max caracteres';
    }
    return null;
  }
}

