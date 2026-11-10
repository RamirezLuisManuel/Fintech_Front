import 'package:flutter_test/flutter_test.dart';
import 'package:fintech_front/main.dart';
import 'package:fintech_front/utils/security_validators.dart';

void main() {
  testWidgets('Renderiza pantalla de Login correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const FintechGestoPagoApp(startLoggedIn: false));
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Continuar con Verificación 2FA'), findsOneWidget);
  });

  group('Validaciones de Seguridad y Anti-Inyección', () {
    test('Detecta intentos de inyección SQL y XSS', () {
      expect(SecurityValidators.containsInjectionAttempt("' OR '1'='1"), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('<script>alert(1)</script>'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('DROP TABLE usuarios;'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('prueba3@gmail.com'), isFalse);
    });

    test('Valida formato de correo, teléfono y monto', () {
      expect(SecurityValidators.validateEmail('prueba3@gmail.com'), isNull);
      expect(SecurityValidators.validateEmail('correo-invalido'), isNotNull);
      expect(SecurityValidators.validatePhone('4181234567'), isNull);
      expect(SecurityValidators.validatePhone('12345'), isNotNull);
      expect(SecurityValidators.validateAmount('100.00', exactPrice: 100.0), isNull);
      expect(SecurityValidators.validateAmount('50.00', exactPrice: 100.0), isNotNull);
    });
  });
}
