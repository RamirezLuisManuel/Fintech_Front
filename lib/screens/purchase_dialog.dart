import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../utils/security_validators.dart';

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

  bool _confirmStep = false;
  bool _isSubmitting = false;
  late String _idempotencyKey;

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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _confirmStep = true);
  }

  Future<void> _executePurchase() async {
    final pinError = SecurityValidators.validate2faOrPin(_pinCtrl.text, onlyFourDigits: true);
    if (pinError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pinError), backgroundColor: const Color(0xFFDC2626)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final monto = double.tryParse(_amountCtrl.text.trim()) ?? widget.product.precio;

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
    setState(() => _isSubmitting = false);

    widget.onPurchaseCompleted();
    Navigator.of(context).pop();

    _showOperationResultDialog(
      context: context,
      result: res,
      product: widget.product,
      monto: monto,
      destino: _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : _referenceCtrl.text,
    );
  }

  static void _showOperationResultDialog({
    required BuildContext context,
    required ApiResult<TransactionModel> result,
    required GestoPagoProductModel product,
    required double monto,
    required String destino,
  }) {
    final tx = result.data;
    final isCommError = result.message.startsWith('ERROR_COMUNICACION') ||
        result.statusCode == 503 ||
        result.statusCode == 504;

    Color headerColor;
    IconData headerIcon;
    String statusTitle;
    String statusSubtitle;

    if (tx != null && tx.isSucceeded) {
      headerColor = const Color(0xFF16A34A);
      headerIcon = Icons.check_circle_rounded;
      statusTitle = '¡Compra Exitosa!';
      statusSubtitle =
          'La operación fue aprobada y confirmada por GestoPago (Código ${tx.providerCode ?? "01"}).';
    } else if (tx != null && tx.isPending) {
      headerColor = const Color(0xFFD97706);
      headerIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Compra Pendiente de Confirmación';
      statusSubtitle =
          'La solicitud fue enviada a GestoPago y se encuentra en proceso de conciliación.';
    } else if (isCommError && tx == null) {
      headerColor = const Color(0xFFEA580C);
      headerIcon = Icons.wifi_off_rounded;
      statusTitle = 'Error de Comunicación';
      statusSubtitle = result.message.replaceAll('ERROR_COMUNICACION: ', '');
    } else {
      headerColor = const Color(0xFFDC2626);
      headerIcon = Icons.cancel_rounded;
      statusTitle = 'Compra Rechazada';
      statusSubtitle = tx?.providerMessage ?? result.message;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                color: headerColor,
                child: Column(
                  children: [
                    Icon(headerIcon, color: Colors.white, size: 54),
                    const SizedBox(height: 12),
                    Text(
                      statusTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
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
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _receiptRow('Servicio / Marca', product.servicio),
                    _receiptRow('Producto', product.producto),
                    _receiptRow('Importe', '\$${monto.toStringAsFixed(2)} MXN', bold: true),
                    if (destino.isNotEmpty)
                      _receiptRow('Teléfono / Referencia', destino),
                    if (tx != null) ...[
                      const Divider(height: 22),
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
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: headerColor),
            child: const Text('Cerrar Comprobante'),
          ),
        ],
      ),
    );
  }

  static Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
          const SizedBox(width: 12),
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

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isFixed = p.isFixedAmount;
    final needsPhone = p.requiresPhoneNumber;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      title: Container(
        padding: const EdgeInsets.all(20),
        color: p.brandColor,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(p.brandIcon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.servicio,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    p.producto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: _confirmStep ? _buildConfirmStep(p) : _buildCaptureForm(p, isFixed, needsPhone),
        ),
      ),
      actions: _confirmStep
          ? [
              TextButton(
                onPressed: _isSubmitting ? null : () => setState(() => _confirmStep = false),
                child: const Text('Modificar Datos'),
              ),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _executePurchase,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(_isSubmitting ? 'Procesando con GestoPago...' : 'Confirmar y Pagar'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: widget.cuentas.isEmpty ? null : _proceedToConfirmation,
                style: FilledButton.styleFrom(backgroundColor: p.brandColor),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Continuar a Confirmación'),
              ),
            ],
    );
  }

  Widget _buildCaptureForm(
      GestoPagoProductModel p, bool isFixed, bool needsPhone) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.descripcionDetallada,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID Producto: #${p.idProducto}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Text(
                      isFixed
                          ? 'Precio Fijo: \$${p.precio.toStringAsFixed(2)} MXN'
                          : 'Monto Variable',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: p.brandColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedAccount.isNotEmpty ? _selectedAccount : null,
            decoration: InputDecoration(
              labelText: 'Cuenta de Cargo',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: widget.cuentas
                .map(
                  (c) => DropdownMenuItem(
                    value: c.numeroCuenta,
                    child: Text(
                      '${c.numeroCuenta} (Disp: \$${c.saldoDisponible.toStringAsFixed(2)})',
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else if (p.idCatTipoServicio != 10 && p.idCatTipoServicio != 11)
            TextFormField(
              controller: _referenceCtrl,
              maxLength: 40,
              validator: (v) => SecurityValidators.validateReference(v, required: true),
              decoration: InputDecoration(
                labelText: 'Referencia de Pago / Contrato',
                hintText: 'Ingresa los dígitos de tu recibo o cuenta',
                counterText: '',
                prefixIcon: const Icon(Icons.qr_code_rounded),
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
              labelText: isFixed ? 'Importe Fijo del Producto (MXN)' : 'Monto a Pagar (MXN)',
              prefixIcon: const Icon(Icons.attach_money_rounded),
              filled: isFixed,
              fillColor: isFixed ? const Color(0xFFF1F5F9) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(GestoPagoProductModel p) {
    final monto = double.tryParse(_amountCtrl.text.trim()) ?? p.precio;
    final destino = _phoneCtrl.text.isNotEmpty
        ? _phoneCtrl.text
        : (_referenceCtrl.text.isNotEmpty ? _referenceCtrl.text : 'Acreditación directa');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RESUMEN DE CONFIRMACIÓN DE COMPRA',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF166534),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _receiptRow('Producto:', '${p.servicio} - ${p.producto}'),
              _receiptRow('Cuenta de cargo:', _selectedAccount),
              _receiptRow('Destino / Ref:', destino),
              _receiptRow('Total a pagar:', '\$${monto.toStringAsFixed(2)} MXN', bold: true),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Para autorizar esta operación ante GestoPago, ingresa tu PIN de seguridad de 4 dígitos:',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pinCtrl,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 10,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'PIN de Autorización (4 dígitos)',
            counterText: '',
            prefixIcon: const Icon(Icons.vpn_key_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
