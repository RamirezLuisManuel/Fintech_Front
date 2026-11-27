import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/security_validators.dart';
import '../widgets/monograma.dart';

/// Flujo de compra GestoPago en pantalla completa (3 etapas: Captura -> Confirmación PIN -> Comprobante)
class PurchaseDialog extends StatefulWidget {
  final GestoPagoProductModel product;
  final List<CuentaModel> cuentas;
  final VoidCallback onPurchaseCompleted;

  const PurchaseDialog({
    super.key,
    required this.product,
    required this.cuentas,
    required this.onPurchaseCompleted,
  });

  @override
  State<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<PurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedAccount;
  final _phoneCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  late final TextEditingController _amountCtrl;
  final _pinCtrl = TextEditingController();

  /// 0 = Captura de datos, 1 = Confirmación y PIN, 2 = Comprobante (Éxito / Fallida / Pendiente)
  int _step = 0;
  bool _isSubmitting = false;
  late String _idempotencyKey;

  ApiResult<TransactionModel>? _purchaseResult;
  double _executedMonto = 0.0;
  String _executedDestino = '';

  @override
  void initState() {
    super.initState();
    _selectedAccount = widget.cuentas.isNotEmpty ? widget.cuentas.first.numeroCuenta : '';
    final defaultPrice = widget.product.precio > 0 ? widget.product.precio : 50.0;
    _amountCtrl = TextEditingController(text: defaultPrice.toStringAsFixed(2));
    _idempotencyKey = _generateIdempotencyKey();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _referenceCtrl.dispose();
    _amountCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  String _generateIdempotencyKey() {
    final rnd = Random.secure();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final suffix = List.generate(6, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return 'gp-${widget.product.idProducto}-$ts-$suffix';
  }

  void _proceedToConfirmation() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _step = 1);
  }

  Future<void> _executePurchase() async {
    final pinError = SecurityValidators.validate2faOrPin(_pinCtrl.text, onlyFourDigits: true);
    if (pinError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pinError),
          backgroundColor: const Color(0xFF991B1B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final monto = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? widget.product.precio;
    final destino = _phoneCtrl.text.trim().isNotEmpty
        ? _phoneCtrl.text.trim()
        : _referenceCtrl.text.trim();

    final res = await ApiService.realizarCompra(
      numeroCuenta: _selectedAccount,
      idProducto: widget.product.idProducto,
      idServicio: widget.product.idServicio,
      monto: monto,
      telefono: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      referencia: _referenceCtrl.text.trim().isNotEmpty
          ? SecurityValidators.sanitize(_referenceCtrl.text)
          : null,
      pin: _pinCtrl.text.trim(),
      idempotencyKey: _idempotencyKey,
    );

    if (!mounted) return;
    widget.onPurchaseCompleted();

    setState(() {
      _isSubmitting = false;
      _purchaseResult = res;
      _executedMonto = monto;
      _executedDestino = destino;
      _step = 2;
    });
  }

  String get _appBarTitle {
    if (_step == 0) return 'Comprar ${widget.product.producto}';
    if (_step == 1) return 'Confirmar Operación';
    return 'Comprobante de Operación';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isFixed = p.isFixedAmount;
    final needsPhone = p.requiresPhoneNumber;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: _step != 2 && !_isSubmitting,
        leading: _step == 1 && !_isSubmitting
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step = 0),
              )
            : null,
        title: Text(
          _appBarTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: _step == 0
                  ? _buildCaptureStep(p, isFixed, needsPhone)
                  : (_step == 1
                      ? _buildConfirmationStep(p)
                      : _buildResultStep(p)),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== PASO 1: CAPTURA DE DATOS DE COMPRA ====================
  Widget _buildCaptureStep(GestoPagoProductModel p, bool isFixed, bool needsPhone) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Monograma(
                  idServicio: p.idServicio,
                  nombre: p.servicio,
                  size: 52,
                  borderRadius: 14,
                  accentColor: p.brandColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.servicio.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.producto,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isFixed
                        ? CurrencyFormatter.format(p.precio, withMxn: true)
                        : 'Monto Variable',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESCRIPCIÓN DEL SERVICIO',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.descripcionDetallada,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF334155),
                      height: 1.55,
                    ),
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(
                        'ID Producto: #${p.idProducto}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        isFixed ? 'Modalidad: Precio Fijo' : 'Modalidad: Recibo / Variable',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedAccount.isNotEmpty ? _selectedAccount : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Cuenta de Cargo',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: widget.cuentas
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.numeroCuenta,
                      child: Text(
                        '${c.numeroCuenta} (Disp: ${CurrencyFormatter.format(c.saldoDisponible)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedAccount = v ?? ''),
            ),
            const SizedBox(height: 16),
            if (needsPhone)
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => SecurityValidators.validatePhone(v, required: true),
                decoration: InputDecoration(
                  labelText: 'Número Telefónico (10 dígitos)',
                  hintText: 'Ej. 4181234567',
                  counterText: '',
                  prefixIcon: const Icon(Icons.phone_iphone_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else if (!p.isDigitalPinWithoutReference)
              TextFormField(
                controller: _referenceCtrl,
                maxLength: p.tipoFront == 1 ? 20 : 40,
                inputFormatters: [
                  SecurityValidators.safeSearchFormatter,
                  LengthLimitingTextInputFormatter(p.tipoFront == 1 ? 20 : 40),
                ],
                validator: (v) {
                  final baseErr = SecurityValidators.validateReference(v, required: true);
                  if (baseErr != null) return baseErr;
                  if (p.tipoFront == 1 && (v?.trim().length ?? 0) > 20) {
                    return '• La referencia no puede exceder 20 caracteres';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: (p.tipoReferencia?.toLowerCase() == 'a')
                      ? 'Teléfono o Referencia de Pago'
                      : 'Referencia de Pago / Contrato',
                  hintText: (p.tipoReferencia?.toLowerCase() == 'a')
                      ? 'Ingresa el número a 10 dígitos o referencia'
                      : 'Ingresa los dígitos de tu recibo o cuenta',
                  counterText: '',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              readOnly: isFixed,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => SecurityValidators.validateAmount(
                v,
                exactPrice: isFixed ? p.precio : null,
              ),
              decoration: InputDecoration(
                labelText: isFixed ? 'Importe Fijo del Producto (MXN)' : 'Importe a Pagar (MXN)',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                filled: true,
                fillColor: isFixed ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar', textAlign: TextAlign.center),
                ),
                FilledButton.icon(
                  onPressed: widget.cuentas.isEmpty ? null : _proceedToConfirmation,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Continuar a Confirmación',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PASO 2: CONFIRMACIÓN Y PIN CENTRADO ====================
  Widget _buildConfirmationStep(GestoPagoProductModel p) {
    final monto = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? p.precio;
    final destino = _phoneCtrl.text.trim().isNotEmpty
        ? _phoneCtrl.text.trim()
        : (_referenceCtrl.text.trim().isNotEmpty ? _referenceCtrl.text.trim() : 'N/A');

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Confirmar y Autorizar Compra',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RESUMEN DE OPERACIÓN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                _receiptRow('Producto', '${p.servicio} - ${p.producto}'),
                _receiptRow('Cuenta de cargo', _selectedAccount),
                _receiptRow('Destino / Referencia', destino),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                _receiptRow(
                  'Total a pagar',
                  CurrencyFormatter.format(monto, withMxn: true),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Ingresa tu PIN de seguridad de 4 dígitos para autorizar:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pinCtrl,
            autofocus: true,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _isSubmitting ? null : _executePurchase(),
            decoration: InputDecoration(
              labelText: 'PIN de Autorización (4 dígitos)',
              floatingLabelAlignment: FloatingLabelAlignment.center,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: _isSubmitting ? null : () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Modificar Datos', textAlign: TextAlign.center),
              ),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _executePurchase,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Procesando...' : 'Confirmar y Pagar',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PASO 3: COMPROBANTE EN PANTALLA COMPLETA ====================
  Widget _buildResultStep(GestoPagoProductModel product) {
    final result = _purchaseResult!;
    final tx = result.data;
    final isCommError = result.message.startsWith('ERROR_COMUNICACION') ||
        result.statusCode == 503 ||
        result.statusCode == 504;

    Color headerColor;
    IconData headerIcon;
    String statusTitle;
    String statusSubtitle;

    if (tx != null && tx.isSucceeded) {
      headerColor = const Color(0xFF166534);
      headerIcon = Icons.check_circle_rounded;
      statusTitle = 'Compra Exitosa';
      statusSubtitle =
          'Operación aprobada y confirmada por GestoPago (Código ${tx.providerCode ?? "01"}).';
    } else if (tx != null && tx.isPending) {
      headerColor = const Color(0xFFB45309);
      headerIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Compra Pendiente';
      statusSubtitle =
          'La solicitud fue enviada a GestoPago y está en proceso de conciliación.';
    } else if (isCommError && tx == null) {
      headerColor = const Color(0xFFB45309);
      headerIcon = Icons.wifi_off_rounded;
      statusTitle = 'Error de Comunicación';
      statusSubtitle = result.message.replaceAll('ERROR_COMUNICACION: ', '');
    } else {
      headerColor = const Color(0xFF991B1B);
      headerIcon = Icons.cancel_rounded;
      statusTitle = 'Compra Fallida';
      statusSubtitle = tx?.providerMessage ?? result.message;
    }

    final isFailed = (tx != null && tx.isFailed) || (tx == null && !result.success);
    String? errorCode = tx?.providerCode;
    if (isFailed && (errorCode == null || errorCode.isEmpty)) {
      final codeMatch =
          RegExp(r'(?:c[oó]digo|code|error)\s*[:#-]?\s*(\d{2,4})', caseSensitive: false)
              .firstMatch(result.message);
      errorCode = codeMatch?.group(1) ??
          (result.statusCode >= 400 ? 'HTTP ${result.statusCode}' : 'ERROR');
    }
    final errorReason = (tx?.providerMessage != null && tx!.providerMessage!.isNotEmpty)
        ? tx.providerMessage!
        : result.message.replaceAll('ERROR_COMUNICACION: ', '');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            color: headerColor,
            child: Column(
              children: [
                Icon(headerIcon, color: Colors.white, size: 52),
                const SizedBox(height: 12),
                Text(
                  statusTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13.5,
                    height: 1.4,
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
                Row(
                  children: [
                    Monograma(
                      idServicio: product.idServicio,
                      nombre: product.servicio,
                      size: 44,
                      borderRadius: 11,
                      accentColor: product.brandColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.servicio,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            product.producto,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),
                _receiptRow('Servicio / Marca', product.servicio),
                _receiptRow('Producto', product.producto),
                _receiptRow(
                  'Importe',
                  CurrencyFormatter.format(_executedMonto, withMxn: true),
                  bold: true,
                ),
                if (_executedDestino.isNotEmpty)
                  _receiptRow('Teléfono / Referencia', _executedDestino),
                if (isFailed) ...[
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),
                  _receiptRow('Código de Error', errorCode ?? 'N/A', bold: true),
                  _receiptRow('Motivo del Error', errorReason),
                ],
                if (tx != null) ...[
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),
                  _receiptRow('Estado Oficial', tx.estadoLabel),
                  _receiptRow('Folio UPC', tx.upc),
                  if (tx.providerAuthorization != null &&
                      tx.providerAuthorization!.isNotEmpty)
                    _receiptRow('Autorización Proveedor', tx.providerAuthorization!, bold: true),
                  if (tx.providerTransactionId != null &&
                      tx.providerTransactionId!.isNotEmpty)
                    _receiptRow('ID Transacción GestoPago', tx.providerTransactionId!),
                  if (tx.pin != null && tx.pin!.isNotEmpty)
                    _receiptRow('PIN / Código Entregado', tx.pin!, bold: true),
                  _receiptRow('Fecha y Hora', tx.formattedDate),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Volver al Catálogo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
