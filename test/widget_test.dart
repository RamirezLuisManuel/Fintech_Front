import 'package:flutter_test/flutter_test.dart';
import 'package:fintech_front/main.dart';
import 'package:fintech_front/models/account_model.dart';
import 'package:fintech_front/models/product_model.dart';
import 'package:fintech_front/models/transaction_model.dart';
import 'package:fintech_front/utils/security_validators.dart';
import 'package:fintech_front/widgets/monograma.dart';

void main() {
  testWidgets('Renderiza pantalla de Login correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const FintechGestoPagoApp(startLoggedIn: false));
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Continuar con Verificación 2FA'), findsOneWidget);
  });

  group('Validaciones de Seguridad y Anti-Inyección', () {
    test('Detecta intentos de inyección SQL y XSS', () {
      expect(SecurityValidators.containsInjectionAttempt("' OR '1'='1"), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('1 OR 1=1'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('UNION SELECT * FROM usuarios'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('PG_SLEEP(5)'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('<script>alert(1)</script>'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('<img src=x onerror=alert(1)>'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('document.cookie'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('javascript:alert(1)'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('DROP TABLE usuarios;'), isTrue);
      expect(SecurityValidators.containsInjectionAttempt('prueba3@gmail.com'), isFalse);
    });

    test('Valida formato de correo, teléfono y monto', () {
      expect(SecurityValidators.validateEmail('prueba3@gmail.com'), isNull);
      expect(SecurityValidators.validateEmail('usuario@dominio.com.mx'), isNull);
      expect(SecurityValidators.validateEmail('correo-invalido'), isNotNull);
      expect(SecurityValidators.validateEmail('prueba@gmail.cm'), isNotNull);
      expect(SecurityValidators.validateEmail('prueba@gmail.c'), isNotNull);
      expect(SecurityValidators.validatePhone('4181234567'), isNull);
      expect(SecurityValidators.validatePhone('12345'), isNotNull);
      expect(SecurityValidators.validateAmount('100.00', exactPrice: 100.0), isNull);
      expect(SecurityValidators.validateAmount('50.00', exactPrice: 100.0), isNotNull);
      expect(SecurityValidators.validateAmount('0', allowZero: true), isNull);
      expect(SecurityValidators.validateAmount('15,000.50', allowZero: true), isNull);
      expect(SecurityValidators.validateStrongPassword('Abc1234!'), isNull);
      expect(SecurityValidators.validateStrongPassword('Abc12345678901!'), isNotNull);
      expect(SecurityValidators.validatePersonName('Luis', 'El nombre'), isNull);
      expect(SecurityValidators.validatePersonName('María', 'El nombre'), isNull);
      expect(SecurityValidators.validatePersonName('Luis ', 'El nombre'), isNotNull);
      expect(SecurityValidators.validatePersonName('Luis Manuel', 'El nombre'), isNotNull);
      expect(SecurityValidators.validatePersonName('luis', 'El nombre'), isNotNull);
      expect(SecurityValidators.validatePersonName('Lu', 'El nombre'), isNotNull);
      expect(SecurityValidators.validateEmail('prueba@gmail.com '), isNotNull);
      expect(SecurityValidators.validateRfc('GODE561231GR8'), isNull);
      expect(SecurityValidators.validateRfc('G&DE561231GR8'), isNotNull);
      expect(SecurityValidators.validateCurp('GODE561231HGTNRR01'), isNull);
      expect(SecurityValidators.validateCurp('GODE-561231HGTNR01'), isNotNull);
    });
  });

  group('Modelos GestoPago', () {
    test('Sanitiza errores crudos de IP 55/validIPS a código 05 limpio', () {
      final tx = TransactionModel.fromJson({
        'operationId': 'op-1',
        'upc': 'UPC123',
        'estado': 'FAILED',
        'monto': 50.0,
        'idProducto': 185,
        'providerCode': '55',
        'providerMessage':
            '{validationCompleted=false, codigoDispositivo=GPS83-TPV-17, isValid=false, validIPS=(83): [1.2.3.4]}',
      });
      expect(tx.providerCode, '05');
      expect(tx.providerMessage, isNot(contains('validIPS')));
      expect(tx.providerMessage, contains('05'));
    });

    test('Habilita todos los tipoFront y distingue pines digitales fijos', () {
      for (final tf in [1, 2, 4, 5, 30, 40]) {
        final p = GestoPagoProductModel.fromJson({
          'idProducto': 10 + tf,
          'servicio': 'Servicio',
          'producto': 'Producto',
          'tipoFront': tf,
          'precio': tf == 1 ? 100.0 : 12.0,
          'idCatTipoServicio': 10,
        });
        expect(p.isAvailableForPurchase, isTrue);
        expect(p.isDigitalPinWithoutReference, tf == 1);
      }
    });

    test('Construye nombreCompleto incluyendo segundoNombre cuando existe', () {
      final profile = UserProfileModel.fromJson({
        'usuarioId': 1,
        'clienteId': 2,
        'nombre': 'Luis',
        'segundoNombre': 'Manuel',
        'apellidoPaterno': 'Ramírez',
        'apellidoMaterno': 'Ramírez',
        'nombreCompleto': 'Luis Ramírez Ramírez',
        'correo': 'luis@test.com',
        'telefonoMovil': '4181234567',
        'rfc': 'RARL000101XXX',
        'curp': 'RARL000101HGTNRR01',
        'cuentas': [],
      });
      expect(profile.nombreCompleto, 'Luis Manuel Ramírez Ramírez');
    });

    test('Monograma construye URL oficial de GestoPago e iniciales de respaldo', () {
      expect(
        Monograma.buildImageUrl(71),
        'https://gestopago.portalventas.net/sistema/images/gestopago/servicios/71.png',
      );
      expect(Monograma.extractInitials('Amazon'), 'AM');
      expect(Monograma.extractInitials('Mercado Pago'), 'MP');
      expect(Monograma.extractInitials(''), 'GP');
    });
  });
}
