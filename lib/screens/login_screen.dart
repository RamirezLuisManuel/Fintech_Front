import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/security_validators.dart';
import 'home_shell_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialAlertMessage;
  const LoginScreen({super.key, this.initialAlertMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAlertMessage != null &&
        widget.initialAlertMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSessionDisplacedAlert(widget.initialAlertMessage!);
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showSessionDisplacedAlert(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gpp_maybe_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Control de Sesión Única',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(msg, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateLogin({bool forceClosePrevious = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = SecurityValidators.sanitize(_emailCtrl.text);
    final password = _passCtrl.text;

    final res = await ApiService.preLogin(
      correo: email,
      password: password,
      forceClosePrevious: forceClosePrevious,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!res.success) {
      _showErrorSnackBar(res.message);
      return;
    }

    final data = res.data ?? {};
    final activeSessionDetected = data['activeSessionDetected'] == true;

    if (activeSessionDetected && !forceClosePrevious) {
      _showActiveSessionConflictDialog(
        infoMessage: (data['activeSessionInfo'] ??
                'Se detectó una sesión activa en otra plataforma (Web o Móvil).')
            .toString(),
      );
      return;
    }

    // Mostrar modal de Segundo Factor de Autenticación (2FA)
    _showTwoFactorDialog(
      correo: email,
      password: password,
      hintMessage: (data['mensaje2fa'] ??
              'Ingresa tu PIN de seguridad (4 dígitos) o el código OTP (6 dígitos) enviado a tu correo.')
          .toString(),
    );
  }

  void _showActiveSessionConflictDialog({required String infoMessage}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.devices_other_rounded, color: Color(0xFFD97706), size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sesión Activa Detectada',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              infoMessage,
              style: const TextStyle(fontSize: 14.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, color: Color(0xFFB45309), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Política de Seguridad: Un usuario no puede mantener dos sesiones activas simultáneamente en Web y Móvil.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _initiateLogin(forceClosePrevious: true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Cerrar sesión anterior y continuar'),
          ),
        ],
      ),
    );
  }

  void _showTwoFactorDialog({
    required String correo,
    required String password,
    required String hintMessage,
  }) {
    final codeCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool verifying = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF0F766E), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verificación de Doble Factor (2FA)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hintMessage,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: codeCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    obscureText: true,
                    style: const TextStyle(
                      fontSize: 22,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => SecurityValidators.validate2faOrPin(v),
                    decoration: InputDecoration(
                      labelText: 'Código 2FA (OTP o PIN de 4 dígitos)',
                      counterText: '',
                      prefixIcon: const Icon(Icons.pin_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: verifying ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: verifying
                  ? null
                  : () async {
                      if (!dialogFormKey.currentState!.validate()) return;
                      setModalState(() {
                        verifying = true;
                        dialogError = null;
                      });

                      final verifyRes = await ApiService.verify2faAndLogin(
                        correo: correo,
                        password: password,
                        codigo2fa: codeCtrl.text,
                      );

                      if (!ctx.mounted) return;
                      if (verifyRes.success) {
                        Navigator.of(ctx).pop();
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const HomeShellScreen(),
                          ),
                        );
                      } else {
                        setModalState(() {
                          verifying = false;
                          dialogError = verifyRes.message;
                        });
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: verifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(verifying ? 'Validando...' : 'Verificar e Ingresar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showServerSettingsDialog() {
    final hostCtrl = TextEditingController(text: ApiService.baseHost);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: Color(0xFF1E3A8A)),
            SizedBox(width: 10),
            Text('Servidor Backend REST', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Configura la dirección del servidor Spring Boot:',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostCtrl,
              decoration: InputDecoration(
                labelText: 'URL Base del Servidor',
                hintText: 'http://localhost:9090',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Web / Localhost (9090)'),
                  onPressed: () => hostCtrl.text = 'http://localhost:9090',
                ),
                ActionChip(
                  label: const Text('Emulador Android (10.0.2.2)'),
                  onPressed: () => hostCtrl.text = 'http://10.0.2.2:9090',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await ApiService.setServerHost(hostCtrl.text);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 880;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 980 : 460),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: isWide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 5, child: _buildBrandHeroPanel()),
                            Expanded(flex: 6, child: _buildLoginFormPanel()),
                          ],
                        ),
                      )
                    : _buildLoginFormPanel(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeroPanel() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Ecosistema Digital GestoPago',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Banca Digital y Pagos de Servicios en Tiempo Real',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Accede desde Web o Móvil con tus mismas credenciales. Tus operaciones están protegidas con autenticación de doble factor (2FA) y control de sesión única activa.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              _buildFeatureRow(
                Icons.phonelink_lock_rounded,
                'Sesión Única Activa',
                'Protección automática entre plataforma Web y Móvil.',
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                Icons.verified_user_rounded,
                'Doble Factor (2FA)',
                'Validación criptográfica en servidor en cada acceso y pago.',
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                Icons.storefront_rounded,
                'Catálogo Oficial GestoPago',
                'Recargas telefónicas, paquetes de datos y pago de servicios.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF5EEAD4), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 38),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 32,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showServerSettingsDialog,
                  icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                  label: Text(
                    kIsWeb ? 'Web REST' : 'Móvil REST',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Iniciar Sesión',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ingresa tus credenciales para acceder a la plataforma comercial Fintech GestoPago',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: SecurityValidators.validateEmail,
              decoration: InputDecoration(
                labelText: 'Correo Electrónico',
                hintText: 'ejemplo@correo.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _initiateLogin(),
              validator: SecurityValidators.validateLoginPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _isLoading ? null : () => _initiateLogin(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
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
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _isLoading ? 'Verificando credenciales...' : 'Continuar con Verificación 2FA',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
              label: const Text('¿Nuevo cliente? Aperturar Cuenta Digital'),
            ),
          ],
        ),
      ),
    );
  }
}

