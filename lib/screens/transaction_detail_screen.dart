import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/monograma.dart';

/// Pantalla completa de detalle y comprobante de una operación GestoPago
class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TransactionModel _tx;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _refreshLatestDetail();
  }

  Future<void> _refreshLatestDetail() async {
    if (_tx.operationId.isEmpty) return;
    setState(() => _refreshing = true);
    final res = await ApiService.obtenerDetalleCompra(_tx.operationId);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (res.success && res.data != null) {
        _tx = res.data!;
      }
    });
  }

  void _copyValue(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = _tx;
    final headerColor = tx.isSucceeded
        ? const Color(0xFF166534)
        : (tx.isPending ? const Color(0xFFB45309) : const Color(0xFF991B1B));
    final softBgColor = tx.isSucceeded
        ? const Color(0xFFF0FDF4)
        : (tx.isPending ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));
    final softBorderColor = tx.isSucceeded
        ? const Color(0xFFBBF7D0)
        : (tx.isPending ? const Color(0xFFFDE68A) : const Color(0xFFFECACA));

    final statusIcon = tx.isSucceeded
        ? Icons.verified_rounded
        : (tx.isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded);

    final statusSubtitle = tx.isSucceeded
        ? 'Operación aprobada y liquidada ante GestoPago.'
        : (tx.isPending
            ? 'Operación en curso de confirmación con el proveedor.'
            : (tx.providerMessage != null && tx.providerMessage!.isNotEmpty
                ? tx.providerMessage!
                : 'La operación fue rechazada y no se aplicó cargo definitivo.'));

    final showTelefono = tx.telefono != null &&
        tx.telefono!.isNotEmpty &&
        tx.telefono != '1111111111' &&
        tx.telefono != '#1111111111';
    final showAuthorization = tx.providerAuthorization != null &&
        tx.providerAuthorization!.isNotEmpty &&
        tx.providerAuthorization != '-1';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Detalle de Operación',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refreshLatestDetail,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar estado',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_refreshing)
              const LinearProgressIndicator(
                minHeight: 2.5,
                color: Color(0xFF0F766E),
                backgroundColor: Color(0xFFE2E8F0),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Banner principal de estado e importe
                        Container(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 26,
                                ),
                                color: headerColor,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        statusIcon,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      tx.estadoLabel,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      CurrencyFormatter.format(tx.monto, withMxn: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'INFORMACIÓN DEL SERVICIO Y CARGO',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Monograma(
                                          idServicio: tx.idServicio,
                                          nombre: tx.servicioNombre ?? tx.displayTitle,
                                          size: 48,
                                          borderRadius: 12,
                                          accentColor: headerColor,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tx.servicioNombre ?? 'Servicio GestoPago',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                tx.productoNombre ?? tx.displayTitle,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _infoRow('Producto Adquirido', tx.displayTitle, bold: true),
                                    _infoRow('Fecha y Hora', tx.formattedDate),
                                    if (tx.numeroCuenta != null && tx.numeroCuenta!.isNotEmpty)
                                      _infoRow('Cuenta Bancaria Cargo', tx.numeroCuenta!),
                                    if (showTelefono)
                                      _infoRow('Teléfono / Destino', tx.telefono!),
                                    if (tx.referencia != null && tx.referencia!.isNotEmpty)
                                      _infoRow('Referencia de Recibo', tx.referencia!),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Tarjeta de trazabilidad GestoPago
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'TRAZABILIDAD Y COMPROBANTE GESTOPAGO',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _infoRow(
                                'Folio / Referencia UPC',
                                tx.upc,
                                bold: true,
                                trailingAction: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 17),
                                  tooltip: 'Copiar UPC',
                                  color: const Color(0xFF64748B),
                                  onPressed: () => _copyValue('Folio UPC', tx.upc),
                                ),
                              ),
                              _infoRow(
                                'ID Operación Interno',
                                tx.operationId,
                                trailingAction: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 17),
                                  tooltip: 'Copiar ID',
                                  color: const Color(0xFF64748B),
                                  onPressed: () => _copyValue('ID de operación', tx.operationId),
                                ),
                              ),
                              _codeStatusRow(
                                'Código GestoPago',
                                tx.providerCode ?? 'N/A',
                                headerColor,
                              ),
                              if (tx.providerTransactionId != null &&
                                  tx.providerTransactionId!.isNotEmpty)
                                _infoRow('Transacción GestoPago', tx.providerTransactionId!),
                              if (showAuthorization)
                                _infoRow(
                                  'Autorización Carrier',
                                  tx.providerAuthorization!,
                                  bold: true,
                                ),
                              if (tx.pin != null && tx.pin!.isNotEmpty)
                                _infoRow(
                                  'PIN / Código Digital',
                                  tx.pin!,
                                  bold: true,
                                  trailingAction: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 17),
                                    tooltip: 'Copiar PIN',
                                    color: const Color(0xFF0F172A),
                                    onPressed: () => _copyValue('PIN Digital', tx.pin!),
                                  ),
                                ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: softBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: softBorderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.isSucceeded
                                          ? 'RESPUESTA DEL PROVEEDOR'
                                          : 'MOTIVO / RESPUESTA DEL PROVEEDOR',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.9,
                                        color: headerColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      tx.providerMessage ?? 'Sin mensaje adicional del proveedor',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (tx.legend != null && tx.legend!.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: SelectableText(
                                    tx.legend!.trim(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF475569),
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text(
                              'Volver al Historial',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool bold = false,
    Widget? trailingAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                if (trailingAction != null) ...[
                  const SizedBox(width: 4),
                  SizedBox(width: 28, height: 28, child: trailingAction),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeStatusRow(String label, String code, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: badgeColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
