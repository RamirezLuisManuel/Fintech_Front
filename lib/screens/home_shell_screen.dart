import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../utils/security_validators.dart';
import 'login_screen.dart';
import 'purchase_dialog.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedIndex = 0;

  UserProfileModel? _profile;
  List<GestoPagoProductModel> _products = [];
  List<TransactionModel> _transactions = [];

  bool _loadingProfile = true;
  bool _loadingCatalog = true;
  bool _loadingHistory = true;
  bool _syncingCatalog = false;

  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  bool _onlyAvailableProducts = true;
  bool _onlySuccessfulPurchases = true;

  Timer? _sessionWatchdogTimer;

  static const List<String> _categories = [
    'Todos',
    'Recargas Telefónicas',
    'Paquetes de Datos',
    'Servicios y Recibos',
    'Pines y Entretenimiento',
    'Comercio y Otros',
  ];

  @override
  void initState() {
    super.initState();
    ApiService.onSessionInvalidated = _handleSessionInvalidated;
    _loadAllData();
    // Monitoreo periódico de sesión única activa e inactividad
    _sessionWatchdogTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (ApiService.isInactivityExpired()) {
        _handleSessionInvalidated(
          'Tu sesión expiró automáticamente por inactividad para proteger tu información financiera.',
        );
      } else {
        _silentSessionCheck();
      }
    });
  }

  @override
  void dispose() {
    _sessionWatchdogTimer?.cancel();
    if (ApiService.onSessionInvalidated == _handleSessionInvalidated) {
      ApiService.onSessionInvalidated = null;
    }
    super.dispose();
  }

  void _handleSessionInvalidated(String reason) {
    if (!mounted) return;
    _sessionWatchdogTimer?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialAlertMessage: reason),
      ),
      (route) => false,
    );
  }

  Future<void> _silentSessionCheck() async {
    final res = await ApiService.obtenerPerfilYCuentas();
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() => _profile = res.data);
    }
  }

  Future<void> _loadAllData() async {
    ApiService.recordUserActivity();
    await Future.wait([
      _fetchProfile(),
      _fetchCatalog(),
      _fetchHistory(),
    ]);
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() => _loadingProfile = true);
    final res = await ApiService.obtenerPerfilYCuentas();
    if (!mounted) return;
    setState(() {
      _loadingProfile = false;
      if (res.success && res.data != null) {
        _profile = res.data;
      }
    });
  }

  Future<void> _fetchCatalog() async {
    if (!mounted) return;
    setState(() => _loadingCatalog = true);
    final res = await ApiService.obtenerCatalogoProductos();
    if (!mounted) return;
    setState(() {
      _loadingCatalog = false;
      if (res.success && res.data != null) {
        _products = res.data!;
      }
    });
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _loadingHistory = true);
    final res = await ApiService.obtenerHistorialCompras();
    if (!mounted) return;
    setState(() {
      _loadingHistory = false;
      if (res.success && res.data != null) {
        _transactions = res.data!;
      }
    });
  }

  Future<void> _syncCatalogWithGestoPago() async {
    setState(() => _syncingCatalog = true);
    final res = await ApiService.sincronizarCatalogoGestoPago();
    if (!mounted) return;
    setState(() => _syncingCatalog = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor:
            res.success ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
      ),
    );
    if (res.success) {
      _fetchCatalog();
    }
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Cerrar Sesión Segura'),
          ],
        ),
        content: const Text(
          '¿Deseas finalizar tu sesión activa? Podrás volver a ingresar en cualquier momento desde la aplicación Web o Móvil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _openPurchaseModal(GestoPagoProductModel product) {
    ApiService.recordUserActivity();
    if (!product.isAvailableForPurchase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este producto no está habilitado para compra directa.'),
        ),
      );
      return;
    }
    final cuentas = _profile?.cuentas ?? [];
    if (cuentas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron cuentas activas para realizar el cargo.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PurchaseDialog(
        product: product,
        cuentas: cuentas,
        onPurchaseCompleted: () {
          _fetchProfile();
          _fetchHistory();
        },
      ),
    );
  }

  void _showProductDetailSheet(GestoPagoProductModel product) {
    ApiService.recordUserActivity();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: product.brandColor.withValues(alpha: 0.14),
              child: Icon(product.brandIcon, color: product.brandColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.servicio,
                    style: TextStyle(
                      fontSize: 13,
                      color: product.brandColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    product.producto,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
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
              Text(
                product.descripcionDetallada,
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.45),
              ),
              const Divider(height: 24),
              _detailRow('Categoría', product.categoria),
              _detailRow('ID Producto GestoPago', '#${product.idProducto}'),
              _detailRow('ID Servicio', '#${product.idServicio ?? "N/A"}'),
              _detailRow(
                'Modalidad de Precio',
                product.isFixedAmount ? 'Denominación Fija' : 'Monto Variable / Recibo',
              ),
              _detailRow(
                'Precio Oficial',
                product.precio > 0
                    ? '\$${product.precio.toStringAsFixed(2)} MXN'
                    : 'Monto según recibo',
                bold: true,
              ),
              _detailRow(
                'Disponibilidad',
                product.isAvailableForPurchase ? 'Disponible para compra inmediata' : 'No disponible',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          if (product.isAvailableForPurchase)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openPurchaseModal(product);
              },
              style: FilledButton.styleFrom(backgroundColor: product.brandColor),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Comprar Ahora'),
            ),
        ],
      ),
    );
  }

  Future<void> _openTransactionDetailModal(TransactionModel item) async {
    ApiService.recordUserActivity();
    TransactionModel tx = item;
    if (item.operationId.isNotEmpty) {
      final res = await ApiService.obtenerDetalleCompra(item.operationId);
      if (res.success && res.data != null) {
        tx = res.data!;
      }
    }
    if (!mounted) return;

    final badgeColor = tx.isSucceeded
        ? const Color(0xFF16A34A)
        : (tx.isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(
              tx.isSucceeded
                  ? Icons.verified_rounded
                  : (tx.isPending ? Icons.schedule_rounded : Icons.error_outline_rounded),
              color: badgeColor,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Detalle de Operación (${tx.estadoLabel})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailRow('Producto Adquirido', tx.displayTitle, bold: true),
              _detailRow('Importe Total', '\$${tx.monto.toStringAsFixed(2)} MXN', bold: true),
              _detailRow('Fecha y Hora', tx.formattedDate),
              _detailRow('Folio / Referencia UPC', tx.upc),
              _detailRow('ID Operación Interno', tx.operationId),
              if (tx.numeroCuenta != null)
                _detailRow('Cuenta Bancaria Cargo', tx.numeroCuenta!),
              if (tx.telefono != null && tx.telefono!.isNotEmpty)
                _detailRow('Teléfono / Destino', tx.telefono!),
              if (tx.referencia != null && tx.referencia!.isNotEmpty)
                _detailRow('Referencia de Recibo', tx.referencia!),
              const Divider(height: 22),
              _detailRow('Código GestoPago', tx.providerCode ?? 'N/A'),
              _detailRow('Mensaje Proveedor', tx.providerMessage ?? 'N/A'),
              if (tx.providerTransactionId != null &&
                  tx.providerTransactionId!.isNotEmpty)
                _detailRow('Transacción GestoPago', tx.providerTransactionId!),
              if (tx.providerAuthorization != null &&
                  tx.providerAuthorization!.isNotEmpty)
                _detailRow('Autorización Carrier', tx.providerAuthorization!, bold: true),
              if (tx.pin != null && tx.pin!.isNotEmpty)
                _detailRow('PIN / Código Digital', tx.pin!, bold: true),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: 13,
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
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 860;
    final cuentaPrincipal =
        (_profile?.cuentas.isNotEmpty ?? false) ? _profile!.cuentas.first : null;

    return Listener(
      onPointerDown: (_) => ApiService.recordUserActivity(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: isWide
            ? null
            : AppBar(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                title: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Fintech GestoPago',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (cuentaPrincipal != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '\$${cuentaPrincipal.saldoDisponible.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: _loadAllData,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Actualizar datos',
                  ),
                  IconButton(
                    onPressed: _confirmAndLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5)),
                    tooltip: 'Cerrar sesión',
                  ),
                ],
              ),
        body: isWide
            ? Row(
                children: [
                  _buildDesktopSidebar(cuentaPrincipal),
                  Expanded(
                    child: Column(
                      children: [
                        _buildDesktopTopBar(cuentaPrincipal),
                        Expanded(child: _buildSelectedBody()),
                      ],
                    ),
                  ),
                ],
              )
            : _buildSelectedBody(),
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (idx) {
                  ApiService.recordUserActivity();
                  setState(() => _selectedIndex = idx);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Resumen',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon: Icon(Icons.storefront_rounded),
                    label: 'Catálogo',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Historial',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.shield_outlined),
                    selectedIcon: Icon(Icons.shield_rounded),
                    label: 'Seguridad',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktopSidebar(CuentaModel? cuentaPrincipal) {
    return Container(
      width: 265,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF38BDF8),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fintech Digital',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Pasarela GestoPago',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _sidebarItem(0, Icons.dashboard_rounded, 'Resumen y Cuenta'),
          const SizedBox(height: 8),
          _sidebarItem(1, Icons.storefront_rounded, 'Catálogo de Productos'),
          const SizedBox(height: 8),
          _sidebarItem(2, Icons.receipt_long_rounded, 'Historial de Compras'),
          const SizedBox(height: 8),
          _sidebarItem(3, Icons.shield_rounded, 'Seguridad y Perfil'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        color: Color(0xFF4ADE80), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      kIsWeb ? 'Sesión Única Web' : 'Sesión Única Móvil',
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _profile?.correo ?? 'Usuario autenticado',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmAndLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFCA5A5),
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Cerrar Sesión Segura'),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String title) {
    final selected = _selectedIndex == index;
    return Material(
      color: selected ? const Color(0xFF1E3A8A) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ApiService.recordUserActivity();
          setState(() => _selectedIndex = index);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar(CuentaModel? cuentaPrincipal) {
    final titles = [
      'Resumen Financiero y Cuenta Digital',
      'Catálogo Oficial de Servicios y Productos GestoPago',
      'Historial de Compras y Comprobantes',
      'Seguridad 2FA, Administración de Sesión y Perfil',
    ];
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titles[_selectedIndex],
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Row(
            children: [
              if (cuentaPrincipal != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Saldo Disponible: \$${cuentaPrincipal.saldoDisponible.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _loadAllData,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar información',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildCatalogTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildSecurityAndProfileTab();
      default:
        return _buildOverviewTab();
    }
  }

  // ==================== TAB 0: RESUMEN Y CUENTA ====================
  Widget _buildOverviewTab() {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }
    final cuenta =
        (_profile?.cuentas.isNotEmpty ?? false) ? _profile!.cuentas.first : null;
    final recentSuccess = _transactions.where((t) => t.isSucceeded).take(4).toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta Bancaria Digital
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bienvenido(a), ${_profile?.nombreCompleto ?? "Cliente Fintech"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cuenta Digital Activa • ${cuenta?.numeroCuenta ?? "Sin cuenta"}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13.5,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_clock_rounded,
                                    color: Color(0xFF5EEAD4), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  kIsWeb ? 'Web Verificada (2FA)' : 'Móvil Verificado (2FA)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'SALDO DISPONIBLE PARA COMPRAS',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$${(cuenta?.saldoDisponible ?? 0.0).toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          _balanceMiniPill(
                            'Saldo Total Contable',
                            '\$${(cuenta?.saldo ?? 0.0).toStringAsFixed(2)}',
                          ),
                          _balanceMiniPill(
                            'En Retención GestoPago',
                            '\$${(cuenta?.saldoRetenido ?? 0.0).toStringAsFixed(2)}',
                          ),
                          _balanceMiniPill(
                            'Catálogo Disponible',
                            '${_products.length} Productos',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Accesos Rápidos al Catálogo GestoPago',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _quickCategoryCard(
                      'Recargas Telefónicas',
                      'Telcel, Movistar, AT&T, Bait',
                      Icons.phone_iphone_rounded,
                      const Color(0xFF1E3A8A),
                    ),
                    _quickCategoryCard(
                      'Paquetes de Datos',
                      'Internet Amigo, eSIM, Roaming',
                      Icons.wifi_tethering_rounded,
                      const Color(0xFF0284C7),
                    ),
                    _quickCategoryCard(
                      'Servicios y Recibos',
                      'Agua, Luz, Gas, Telecom',
                      Icons.receipt_long_rounded,
                      const Color(0xFF4F46E5),
                    ),
                    _quickCategoryCard(
                      'Pines y Entretenimiento',
                      'Amazon, Streaming, Gaming',
                      Icons.card_giftcard_rounded,
                      const Color(0xFFD97706),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Últimas Compras Exitosas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedIndex = 2),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Ver todo el historial'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (recentSuccess.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.shopping_bag_outlined,
                              size: 44, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 10),
                          const Text(
                            'Aún no tienes compras registradas.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () => setState(() => _selectedIndex = 1),
                            icon: const Icon(Icons.storefront_rounded),
                            label: const Text('Explorar Catálogo de Productos'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recentSuccess.map(_buildTransactionTile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _balanceMiniPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCategoryCard(
    String category,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _selectedCategory = category;
              _selectedIndex = 1;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TAB 1: CATÁLOGO DE PRODUCTOS ====================
  Widget _buildCatalogTab() {
    final cleanQuery = SecurityValidators.sanitize(_searchQuery).toLowerCase();
    final filtered = _products.where((p) {
      if (_onlyAvailableProducts && !p.isAvailableForPurchase) return false;
      if (_selectedCategory != 'Todos' && p.categoria != _selectedCategory) {
        return false;
      }
      if (cleanQuery.isNotEmpty) {
        final matchServicio = p.servicio.toLowerCase().contains(cleanQuery);
        final matchProducto = p.producto.toLowerCase().contains(cleanQuery);
        final matchLegend = (p.legend ?? '').toLowerCase().contains(cleanQuery);
        final matchId = p.idProducto.toString() == cleanQuery;
        return matchServicio || matchProducto || matchLegend || matchId;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText:
                                'Buscar por compañía, servicio o producto (ej. Telcel, Amazon, Agua, 100)...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () => setState(() => _searchQuery = ''),
                                    icon: const Icon(Icons.clear_rounded),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _syncingCatalog ? null : _syncCatalogWithGestoPago,
                        icon: _syncingCatalog
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_sync_rounded, size: 18),
                        label: Text(_syncingCatalog ? 'Sincronizando...' : 'Sincronizar API'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._categories.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: _selectedCategory == cat,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = cat),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Solo disponibles para compra'),
                          selected: _onlyAvailableProducts,
                          onSelected: (v) =>
                              setState(() => _onlyAvailableProducts = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingCatalog
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 56, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron productos con los filtros seleccionados.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _selectedCategory = 'Todos';
                              });
                            },
                            child: const Text('Restablecer filtros'),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 340,
                            mainAxisExtent: 235,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _buildProductCard(filtered[i]),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildProductCard(GestoPagoProductModel p) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showProductDetailSheet(p),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(p.brandIcon, color: p.brandColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.servicio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.brandColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          p.producto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  p.descripcionDetallada,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.isFixedAmount ? 'PRECIO FIJO' : 'PAGO DE SERVICIO',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        p.precio > 0
                            ? '\$${p.precio.toStringAsFixed(2)} MXN'
                            : 'Monto Libre',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: p.isAvailableForPurchase
                        ? () => _openPurchaseModal(p)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.brandColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                    label: const Text('Comprar', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TAB 2: HISTORIAL DE COMPRAS ====================
  Widget _buildHistoryTab() {
    final displayed = _onlySuccessfulPurchases
        ? _transactions.where((t) => t.isSucceeded).toList()
        : _transactions;

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mis Operaciones Registradas en GestoPago',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Mostrando ${displayed.length} operaciones confirmadas',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilterChip(
                              label: const Text('Mostrar únicamente compras exitosas'),
                              selected: _onlySuccessfulPurchases,
                              onSelected: (v) =>
                                  setState(() => _onlySuccessfulPurchases = v),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _fetchHistory,
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Actualizar historial',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loadingHistory)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (displayed.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.history_toggle_off_rounded,
                              size: 52, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'No hay compras exitosas registradas para mostrar.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...displayed.map(_buildTransactionTile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    final statusColor = tx.isSucceeded
        ? const Color(0xFF16A34A)
        : (tx.isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        onTap: () => _openTransactionDetailModal(tx),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(
            tx.isSucceeded
                ? Icons.check_circle_rounded
                : (tx.isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded),
            color: statusColor,
          ),
        ),
        title: Text(
          tx.displayTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Fecha: ${tx.formattedDate}  •  Folio UPC: ${tx.upc}'
            '${tx.providerAuthorization != null ? "  •  Aut: ${tx.providerAuthorization}" : ""}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${tx.monto.toStringAsFixed(2)} MXN',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tx.estadoLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 3: SEGURIDAD Y PERFIL ====================
  Widget _buildSecurityAndProfileTab() {
    final pinCtrl = TextEditingController();
    final passActualCtrl = TextEditingController();
    final passNuevaCtrl = TextEditingController();
    final passConfirmCtrl = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded,
                              color: Color(0xFF1E3A8A), size: 26),
                          SizedBox(width: 10),
                          Text(
                            'Información del Titular y Estado de Seguridad',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      _detailRow('Nombre Completo', _profile?.nombreCompleto ?? 'N/A',
                          bold: true),
                      _detailRow('Correo Autenticado', _profile?.correo ?? 'N/A'),
                      _detailRow('Teléfono Móvil', _profile?.telefonoMovil ?? 'N/A'),
                      _detailRow('RFC', _profile?.rfc ?? 'N/A'),
                      _detailRow('CURP', _profile?.curp ?? 'N/A'),
                      _detailRow(
                        'Política de Sesión Activa',
                        'Sesión Única Exclusiva (${kIsWeb ? "Plataforma Web" : "Aplicación Móvil Android"})',
                        bold: true,
                      ),
                      _detailRow(
                        'Autenticación de Doble Factor (2FA)',
                        'Activa y validada en Servidor (PIN Criptográfico BCrypt + OTP)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Actualizar PIN
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actualizar PIN de Seguridad y 2FA (4 dígitos)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Este PIN se solicita al iniciar sesión (2FA) y antes de autorizar cualquier compra en GestoPago.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pinCtrl,
                              obscureText: true,
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: InputDecoration(
                                labelText: 'Nuevo PIN de 4 dígitos',
                                counterText: '',
                                prefixIcon: const Icon(Icons.pin_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          FilledButton.icon(
                            onPressed: () async {
                              final err = SecurityValidators.validate2faOrPin(
                                pinCtrl.text,
                                onlyFourDigits: true,
                              );
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }
                              final res =
                                  await ApiService.actualizarPin(pinCtrl.text);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              );
                              if (res.success) pinCtrl.clear();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Actualizar PIN'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Cambiar Contraseña
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cambiar Contraseña de Acceso',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: passActualCtrl,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Contraseña Actual',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: passNuevaCtrl,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Nueva Contraseña Segura',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: passConfirmCtrl,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Confirmar Contraseña',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final err = SecurityValidators.validateStrongPassword(
                              passNuevaCtrl.text,
                            );
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                              return;
                            }
                            final res = await ApiService.cambiarPassword(
                              passwordActual: passActualCtrl.text,
                              passwordNueva: passNuevaCtrl.text,
                              passwordConfirmacion: passConfirmCtrl.text,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                              ),
                            );
                            if (res.success) {
                              passActualCtrl.clear();
                              passNuevaCtrl.clear();
                              passConfirmCtrl.clear();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                          ),
                          icon: const Icon(Icons.key_rounded, size: 18),
                          label: const Text('Actualizar Contraseña'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

