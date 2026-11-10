import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/security_validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _segundoNombreCtrl = TextEditingController();
  final _apellidoPaternoCtrl = TextEditingController();
  final _apellidoMaternoCtrl = TextEditingController();
  final _fechaNacCtrl = TextEditingController(text: '2000-05-15');
  final _curpCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  String _sexo = 'M';
  final String _estadoCivil = 'Soltero';
  final _nacionalidadCtrl = TextEditingController(text: 'Mexicana');

  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _ocupacionCtrl = TextEditingController(text: 'Ingeniero de Software');
  final _empresaCtrl = TextEditingController(text: 'Tecnologia Fintech SA');
  final _ingresoCtrl = TextEditingController(text: '25000.00');
  final _passwordCtrl = TextEditingController();

  final _calleCtrl = TextEditingController(text: 'Av Educacion Tecnologica');
  final _numExtCtrl = TextEditingController(text: '34');
  final _coloniaCtrl = TextEditingController(text: 'Fracc Universidad');
  final _municipioCtrl = TextEditingController(text: 'Dolores Hidalgo');
  final _estadoCtrl = TextEditingController(text: 'Guanajuato');
  final _cpCtrl = TextEditingController(text: '37800');
  final _paisCtrl = TextEditingController(text: 'Mexico');

  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _segundoNombreCtrl.dispose();
    _apellidoPaternoCtrl.dispose();
    _apellidoMaternoCtrl.dispose();
    _fechaNacCtrl.dispose();
    _curpCtrl.dispose();
    _rfcCtrl.dispose();
    _nacionalidadCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _ocupacionCtrl.dispose();
    _empresaCtrl.dispose();
    _ingresoCtrl.dispose();
    _passwordCtrl.dispose();
    _calleCtrl.dispose();
    _numExtCtrl.dispose();
    _coloniaCtrl.dispose();
    _municipioCtrl.dispose();
    _estadoCtrl.dispose();
    _cpCtrl.dispose();
    _paisCtrl.dispose();
    super.dispose();
  }

  /// Genera identificadores CURP y RFC únicos con formato oficial para agilizar pruebas en vivo
  void _fillQuickValidSample() {
    final rnd = Random();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final l1 = letters[rnd.nextInt(letters.length)];
    final l2 = 'AEIOU'[rnd.nextInt(5)];
    final l3 = letters[rnd.nextInt(letters.length)];
    final l4 = letters[rnd.nextInt(letters.length)];
    final d1 = rnd.nextInt(9) + 1;
    final d2 = rnd.nextInt(9) + 1;

    setState(() {
      if (_nombreCtrl.text.isEmpty) _nombreCtrl.text = 'Carlos';
      if (_apellidoPaternoCtrl.text.isEmpty) _apellidoPaternoCtrl.text = 'Mendoza';
      if (_apellidoMaternoCtrl.text.isEmpty) _apellidoMaternoCtrl.text = 'Salazar';
      _curpCtrl.text = '$l1$l2$l3${l4}000515HGTNRL$d1$d2';
      _rfcCtrl.text = '$l1$l2$l3${l4}000515A$d1$d2';
      if (_telefonoCtrl.text.isEmpty) {
        _telefonoCtrl.text = '418${1000000 + rnd.nextInt(8999999)}';
      }
      if (_correoCtrl.text.isEmpty) {
        _correoCtrl.text = 'cliente${100 + rnd.nextInt(899)}@gmail.com';
      }
      if (_passwordCtrl.text.isEmpty) {
        _passwordCtrl.text = 'Password123#';
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 5, 15),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _fechaNacCtrl.text = '$y-$m-$d';
      });
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa los campos marcados en rojo antes de continuar.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      'nombre': SecurityValidators.sanitize(_nombreCtrl.text),
      if (_segundoNombreCtrl.text.trim().isNotEmpty)
        'segundoNombre': SecurityValidators.sanitize(_segundoNombreCtrl.text),
      'apellidoPaterno': SecurityValidators.sanitize(_apellidoPaternoCtrl.text),
      'apellidoMaterno': SecurityValidators.sanitize(_apellidoMaternoCtrl.text),
      'fechaNacimiento': _fechaNacCtrl.text.trim(),
      'curp': _curpCtrl.text.trim().toUpperCase(),
      'rfc': _rfcCtrl.text.trim().toUpperCase(),
      'sexo': _sexo,
      'nacionalidad': SecurityValidators.sanitize(_nacionalidadCtrl.text),
      'estadoCivil': _estadoCivil,
      'correo': SecurityValidators.sanitize(_correoCtrl.text),
      'telefonoMovil': _telefonoCtrl.text.trim(),
      'ocupacion': SecurityValidators.sanitize(_ocupacionCtrl.text),
      'empresa': SecurityValidators.sanitize(_empresaCtrl.text),
      'ingresoMensual': double.parse(_ingresoCtrl.text.trim()),
      'password': _passwordCtrl.text,
      'domicilio': {
        'calle': SecurityValidators.sanitize(_calleCtrl.text),
        'numeroExterior': SecurityValidators.sanitize(_numExtCtrl.text),
        'colonia': SecurityValidators.sanitize(_coloniaCtrl.text),
        'municipio': SecurityValidators.sanitize(_municipioCtrl.text),
        'estado': SecurityValidators.sanitize(_estadoCtrl.text),
        'codigoPostal': _cpCtrl.text.trim(),
        'pais': SecurityValidators.sanitize(_paisCtrl.text),
      },
    };

    final res = await ApiService.registrarCliente(payload);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success && res.data != null) {
      final numCuenta = (res.data!['numero_cuenta'] ?? 'N/A').toString();
      final pin = (res.data!['pin'] ?? 'N/A').toString();
      final aviso = (res.data!['aviso_seguridad'] ??
              'Guarda este PIN de 4 dígitos. Por seguridad no volverá a mostrarse.')
          .toString();
      _showSuccessCredentialsDialog(numCuenta: numCuenta, pin: pin, aviso: aviso);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showSuccessCredentialsDialog({
    required String numCuenta,
    required String pin,
    required String aviso,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Cuenta Aperturada con Éxito!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tu cuenta digital ha sido creada con un saldo inicial de apertura de \$1,000.00 MXN.',
                style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'NÚMERO DE CUENTA (10 DÍGITOS)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      numCuenta,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                        letterSpacing: 2,
                      ),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'PIN DE SEGURIDAD Y 2FA (ÚNICA VISUALIZACIÓN)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      pin,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F766E),
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  aviso,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'Correo: ${_correoCtrl.text}\nCuenta: $numCuenta\nPIN: $pin',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Datos copiados al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar Datos'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: const Text('Ir a Iniciar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Apertura de Cuenta Digital Fintech'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _fillQuickValidSample,
            icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF5EEAD4), size: 18),
            label: const Text(
              'Autocompletar Demo',
              style: TextStyle(color: Color(0xFF5EEAD4), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '1. Datos Personales e Identificación Oficial',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _nombreCtrl,
                              validator: (v) =>
                                  SecurityValidators.validatePersonName(v, 'El nombre'),
                              decoration: _inputDeco('Nombre *', Icons.person_outline),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _segundoNombreCtrl,
                              validator: (v) => SecurityValidators.validatePersonName(
                                  v, 'El segundo nombre',
                                  required: false),
                              decoration: _inputDeco('Segundo Nombre', Icons.person_outline),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _apellidoPaternoCtrl,
                              validator: (v) => SecurityValidators.validatePersonName(
                                  v, 'El apellido paterno'),
                              decoration: _inputDeco('Apellido Paterno *', Icons.badge_outlined),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _apellidoMaternoCtrl,
                              validator: (v) => SecurityValidators.validatePersonName(
                                  v, 'El apellido materno'),
                              decoration: _inputDeco('Apellido Materno *', Icons.badge_outlined),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _fechaNacCtrl,
                              readOnly: true,
                              onTap: _selectDate,
                              decoration: _inputDeco(
                                'Fecha Nacimiento (AAAA-MM-DD) *',
                                Icons.calendar_today_rounded,
                              ),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: DropdownButtonFormField<String>(
                              initialValue: _sexo,
                              decoration: _inputDeco('Sexo *', Icons.wc_rounded),
                              items: const [
                                DropdownMenuItem(value: 'M', child: Text('Masculino (M)')),
                                DropdownMenuItem(value: 'F', child: Text('Femenino (F)')),
                              ],
                              onChanged: (v) => setState(() => _sexo = v ?? 'M'),
                            ),
                          ),
                          _buildFieldBox(
                            width: 360,
                            child: TextFormField(
                              controller: _curpCtrl,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 18,
                              validator: SecurityValidators.validateCurp,
                              decoration: _inputDeco('CURP (18 caracteres) *', Icons.fingerprint)
                                  .copyWith(counterText: ''),
                            ),
                          ),
                          _buildFieldBox(
                            width: 360,
                            child: TextFormField(
                              controller: _rfcCtrl,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 13,
                              validator: SecurityValidators.validateRfc,
                              decoration: _inputDeco('RFC con Homoclave (13) *', Icons.assignment_ind)
                                  .copyWith(counterText: ''),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 36),
                      const Text(
                        '2. Credenciales de Acceso y Contacto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildFieldBox(
                            width: 360,
                            child: TextFormField(
                              controller: _correoCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: SecurityValidators.validateEmail,
                              decoration: _inputDeco('Correo Electrónico *', Icons.email_outlined),
                            ),
                          ),
                          _buildFieldBox(
                            width: 360,
                            child: TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePass,
                              validator: SecurityValidators.validateStrongPassword,
                              decoration: _inputDeco(
                                'Contraseña (8+ chars, Mayús, Num, @#\$) *',
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePass ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _telefonoCtrl,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: SecurityValidators.validatePhone,
                              decoration: _inputDeco('Teléfono Móvil (10 dígitos) *', Icons.phone_android)
                                  .copyWith(counterText: ''),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _ocupacionCtrl,
                              validator: (v) =>
                                  SecurityValidators.validateSafeText(v, 'La ocupación'),
                              decoration: _inputDeco('Ocupación *', Icons.work_outline),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _ingresoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => SecurityValidators.validateAmount(v),
                              decoration: _inputDeco('Ingreso Mensual MXN *', Icons.attach_money),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 36),
                      const Text(
                        '3. Domicilio del Titular',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildFieldBox(
                            width: 360,
                            child: TextFormField(
                              controller: _calleCtrl,
                              validator: (v) =>
                                  SecurityValidators.validateSafeText(v, 'La calle'),
                              decoration: _inputDeco('Calle *', Icons.home_outlined),
                            ),
                          ),
                          _buildFieldBox(
                            width: 170,
                            child: TextFormField(
                              controller: _numExtCtrl,
                              validator: (v) => SecurityValidators.validateSafeText(
                                  v, 'Número exterior',
                                  min: 1,
                                  max: 20),
                              decoration: _inputDeco('Núm. Exterior *', Icons.pin_drop_outlined),
                            ),
                          ),
                          _buildFieldBox(
                            width: 170,
                            child: TextFormField(
                              controller: _cpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 5,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: SecurityValidators.validatePostalCode,
                              decoration: _inputDeco('Código Postal *', Icons.markunread_mailbox_outlined)
                                  .copyWith(counterText: ''),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _coloniaCtrl,
                              validator: (v) =>
                                  SecurityValidators.validateSafeText(v, 'La colonia'),
                              decoration: _inputDeco('Colonia *', Icons.location_city_outlined),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _municipioCtrl,
                              validator: (v) =>
                                  SecurityValidators.validateSafeText(v, 'El municipio'),
                              decoration: _inputDeco('Municipio *', Icons.map_outlined),
                            ),
                          ),
                          _buildFieldBox(
                            width: 240,
                            child: TextFormField(
                              controller: _estadoCtrl,
                              validator: (v) =>
                                  SecurityValidators.validateSafeText(v, 'El estado'),
                              decoration: _inputDeco('Estado *', Icons.public_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _submitRegister,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          _isLoading
                              ? 'Registrando y generando PIN...'
                              : 'Completar Registro y Obtener PIN de Seguridad',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldBox({required double width, required Widget child}) {
    return SizedBox(
      width: width,
      child: child,
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

