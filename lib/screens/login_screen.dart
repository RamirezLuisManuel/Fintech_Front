import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/security_validators.dart';
import 'register_screen.dart';
import 'two_factor_screen.dart';

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
            Icon(Icons.gpp_maybe_rounded, color: Color(0xFFB85042), size: 28),
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

    // Navegar a la nueva pantalla de Verificación de Doble Factor (2FA)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TwoFactorScreen(
          correo: email,
          password: password,
          hintMessage: (data['mensaje2fa'] ??
                  'Ingresa tu código de 6 dígitos de Google Authenticator o tu PIN de 4 dígitos.')
              .toString(),
        ),
      ),
    );
  }

  void _showActiveSessionConflictDialog({required String infoMessage}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                color: const Color(0xFF0F172A),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.devices_other_rounded,
                        color: Color(0xFF38BDF8),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sesión Activa Detectada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tu cuenta ya está abierta en otro dispositivo. Si continúas aquí, la sesión anterior se cerrará de inmediato.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined, color: Color(0xFF0F172A), size: 17),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Control de sesión única activo',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _initiateLogin(forceClosePrevious: true);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Continuar aquí', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        backgroundColor: const Color(0xFF8B3A3A),
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
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 14,
              vertical: isWide ? 24 : 16,
            ),
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
                            Expanded(flex: 6, child: _buildLoginFormPanel(isWide: true)),
                          ],
                        ),
                      )
                    : _buildLoginFormPanel(isWide: false),
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

  Widget _buildLoginFormPanel({required bool isWide}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 36 : 22,
        vertical: isWide ? 38 : 28,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
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
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  : const Icon(Icons.login_rounded, size: 20),
              label: Text(
                _isLoading ? 'Verificando credenciales...' : 'Continuar con Verificación 2FA',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
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
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
              label: const Text(
                '¿Nuevo cliente? Crear Cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

