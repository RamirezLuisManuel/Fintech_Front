import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/currency_formatter.dart';

class AccountCreatedScreen extends StatefulWidget {
  final String correo;
  final String numCuenta;
  final String pin;
  final String totpSecret;
  final String totpUri;
  final String aviso;

  const AccountCreatedScreen({
    super.key,
    required this.correo,
    required this.numCuenta,
    required this.pin,
    required this.totpSecret,
    required this.totpUri,
    required this.aviso,
  });

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen> {
  /// En Web inicia mostrando Código QR; en Móvil inicia mostrando Clave Manual.
  /// En ambas plataformas el usuario puede alternar libremente entre ambos modos.
  late bool _showQrMode;

  @override
  void initState() {
    super.initState();
    _showQrMode = kIsWeb;
  }

  String get _effectiveTotpUri {
    if (widget.totpUri.isNotEmpty) return widget.totpUri;
    final encodedEmail = Uri.encodeComponent(widget.correo);
    return 'otpauth://totp/FintechGestoPago:$encodedEmail?secret=${widget.totpSecret}&issuer=FintechGestoPago';
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Apertura de Cuenta Completada',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado ejecutivo limpio
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF38BDF8),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cuenta Digital Activa',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Saldo de bienvenida acreditado: ${CurrencyFormatter.format(1000, withMxn: true)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Credenciales Bancarias
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CREDENCIALES DE ACCESO',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _credentialRow(
                          label: 'Número de Cuenta',
                          value: widget.numCuenta,
                          onCopy: () => _copy(widget.numCuenta, 'Número de cuenta'),
                        ),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _credentialRow(
                          label: 'PIN de Seguridad (4 dígitos)',
                          value: widget.pin,
                          highlight: true,
                          onCopy: () => _copy(widget.pin, 'PIN de seguridad'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Configuración de Google Authenticator (QR o Clave Manual)
                  if (widget.totpSecret.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.phonelink_lock_rounded, color: Color(0xFF0F172A), size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Vincular Google Authenticator (2FA)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Elige cómo deseas registrar tu cuenta en la app Google Authenticator:',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),

                          // Selector alternable QR / Clave Manual
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _modeTab(
                                    label: 'Código QR',
                                    icon: Icons.qr_code_2_rounded,
                                    selected: _showQrMode,
                                    onTap: () => setState(() => _showQrMode = true),
                                  ),
                                ),
                                Expanded(
                                  child: _modeTab(
                                    label: 'Clave Manual',
                                    icon: Icons.key_rounded,
                                    selected: !_showQrMode,
                                    onTap: () => setState(() => _showQrMode = false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_showQrMode) ...[
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: QrImageView(
                                  data: _effectiveTotpUri,
                                  version: QrVersions.auto,
                                  size: 196,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF0F172A),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Abre Google Authenticator en tu teléfono, pulsa "+" → "Escanear un código QR" y apunta a este código.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'CLAVE SECRETA TOTP',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          widget.totpSecret,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: 1.8,
                                          ),
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: () => _copy(widget.totpSecret, 'Clave TOTP'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F172A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.copy_rounded, size: 15),
                                        label: const Text('Copiar', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'En Google Authenticator pulsa "+" → "Ingresar clave de configuración", usa "${widget.correo}" como nombre y pega esta clave (basada en tiempo).',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  Text(
                    widget.aviso,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 22),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copy(
                          'Correo: ${widget.correo}\nCuenta: ${widget.numCuenta}\nPIN: ${widget.pin}\nGoogle Authenticator: ${widget.totpSecret}',
                          'Resumen de credenciales',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        label: const Text('Copiar Todo', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Ir a Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialRow({
    required String label,
    required String value,
    required VoidCallback onCopy,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: highlight ? 22 : 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: highlight ? 4.0 : 1.5,
                  color: highlight ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          tooltip: 'Copiar',
          icon: const Icon(Icons.copy_rounded, size: 19, color: Color(0xFF475569)),
        ),
      ],
    );
  }
}
