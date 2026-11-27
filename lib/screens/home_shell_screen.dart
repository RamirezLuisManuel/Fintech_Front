import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/security_validators.dart';
import '../utils/session_close_handler.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'purchase_dialog.dart';
import 'transaction_detail_screen.dart';
import '../widgets/monograma.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  UserProfileModel? _profile;
  List<GestoPagoProductModel> _products = [];
  List<TransactionModel> _transactions = [];

  bool _loadingProfile = true;
  bool _loadingCatalog = true;
  bool _loadingHistory = true;

  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  bool _onlyAvailableProducts = true;
  bool _onlySuccessfulPurchases = true;

  Timer? _sessionWatchdogTimer;
  bool _showCardCredentials = false;

  // Bloqueo con PIN de seguridad para acceder a Seguridad y Perfil
  bool _profileSecurityUnlocked = false;
  bool _verifyingProfilePin = false;
  String? _profilePinError;
  final _profilePinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _passActualCtrl = TextEditingController();
  final _passNuevaCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _obscurePassActual = true;
  bool _obscurePassNueva = true;
  bool _obscurePassConfirm = true;

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
    WidgetsBinding.instance.addObserver(this);
    registerWebUnloadLogout(
      getLogoutUrl: () => '${ApiService.apiBaseUrl}/auth/logout',
      getAccessToken: () => ApiService.currentAccessToken,
      getCorreo: () => ApiService.currentCorreo,
    );
    ApiService.onSessionInvalidated = _handleSessionInvalidated;
    _loadAllData();
    // Monitoreo periódico de inactividad real y renovación automática de token si el usuario está activo
    _sessionWatchdogTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (ApiService.isInactivityExpired()) {
        await ApiService.logout();
        if (!mounted) return;
        _handleSessionInvalidated('Tu sesión expiró por inactividad.');
      } else {
        if (ApiService.needsTokenRefresh()) {
          await ApiService.refreshAccessToken();
        }
        if (!mounted) return;
        _silentSessionCheck();
      }
    });
    HardwareKeyboard.instance.addHandler(_handleKeyActivity);
  }

  bool _handleKeyActivity(KeyEvent event) {
    ApiService.recordUserActivity();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      ApiService.logout();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyActivity);
    WidgetsBinding.instance.removeObserver(this);
    unregisterWebUnloadLogout();
    _sessionWatchdogTimer?.cancel();
    _profilePinCtrl.dispose();
    _newPinCtrl.dispose();
    _passActualCtrl.dispose();
    _passNuevaCtrl.dispose();
    _passConfirmCtrl.dispose();
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

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                color: const Color(0xFF0F172A),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFFCA5A5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cerrar Sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                      '¿Deseas finalizar tu sesión actual? Tu token de acceso se invalidará de inmediato.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
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
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF991B1B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w600)),
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
          backgroundColor: Color(0xFF8B3A3A),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseDialog(
          product: product,
          cuentas: cuentas,
          onPurchaseCompleted: () {
            _fetchProfile();
            _fetchHistory();
          },
        ),
      ),
    );
  }

  void _showProductDetailSheet(GestoPagoProductModel product) {
    ApiService.recordUserActivity();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          cuentas: _profile?.cuentas ?? [],
          onPurchaseCompleted: () {
            _fetchProfile();
            _fetchHistory();
          },
        ),
      ),
    );
  }

  Future<void> _openTransactionDetailModal(TransactionModel item) async {
    ApiService.recordUserActivity();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: item),
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
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ApiService.recordUserActivity(),
      onPointerMove: (_) => ApiService.recordUserActivity(),
      onPointerHover: (_) => ApiService.recordUserActivity(),
      onPointerSignal: (_) => ApiService.recordUserActivity(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
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
                          CurrencyFormatter.format(cuentaPrincipal.saldoDisponible),
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
              side: const BorderSide(color: Color(0xFF8B3A3A)),
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
      color: selected ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ApiService.recordUserActivity();
          setState(() => _selectedIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: Colors.white.withValues(alpha: 0.14))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13.5,
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
          Expanded(
            child: Text(
              titles[_selectedIndex],
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cuentaPrincipal != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Saldo Disponible: ${CurrencyFormatter.format(cuentaPrincipal.saldoDisponible, withMxn: true)}',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _loadAllData,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155), size: 20),
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
                // Tarjeta Bancaria Digital (Resumen Ejecutivo)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bienvenido(a), ${_profile?.nombreCompleto ?? "Cliente Fintech"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cuenta Digital Activa • ${cuenta?.numeroCuenta ?? "Sin cuenta"}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 13,
                                  letterSpacing: 0.6,
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
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_rounded,
                                    color: Color(0xFF5EEAD4), size: 15),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(cuenta?.saldoDisponible ?? 0.0, withMxn: true),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        children: [
                          _balanceMiniPill(
                            'Saldo Total Contable',
                            CurrencyFormatter.format(cuenta?.saldo ?? 0.0),
                          ),
                          _balanceMiniPill(
                            'En Retención GestoPago',
                            CurrencyFormatter.format(cuenta?.saldoRetenido ?? 0.0),
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
                _buildVirtualCardSection(cuenta),
                const SizedBox(height: 32),
                const Text(
                  'Accesos Rápidos al Catálogo GestoPago',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final quickItems = [
                      (
                        'Recargas Telefónicas',
                        'Telcel, Movistar, AT&T, Bait',
                        Icons.phone_iphone_rounded,
                        const Color(0xFF1E3A8A),
                      ),
                      (
                        'Paquetes de Datos',
                        'Internet Amigo, eSIM, Roaming',
                        Icons.wifi_tethering_rounded,
                        const Color(0xFF0284C7),
                      ),
                      (
                        'Servicios y Recibos',
                        'Agua, Luz, Gas, Telecom',
                        Icons.receipt_long_rounded,
                        const Color(0xFF0F766E),
                      ),
                      (
                        'Pines y Entretenimiento',
                        'Amazon, Streaming, Gaming',
                        Icons.card_giftcard_rounded,
                        const Color(0xFFB45309),
                      ),
                    ];
                    final cols = constraints.maxWidth >= 900
                        ? 4
                        : (constraints.maxWidth >= 520 ? 2 : 1);
                    const spacing = 14.0;
                    final rows = <Widget>[];
                    for (int i = 0; i < quickItems.length; i += cols) {
                      final slice = quickItems.skip(i).take(cols).toList();
                      rows.add(
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int j = 0; j < slice.length; j++) ...[
                                if (j > 0) const SizedBox(width: spacing),
                                Expanded(
                                  child: _quickCategoryCard(
                                    slice[j].$1,
                                    slice[j].$2,
                                    slice[j].$3,
                                    slice[j].$4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                      if (i + cols < quickItems.length) {
                        rows.add(const SizedBox(height: spacing));
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rows,
                    );
                  },
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

  Widget _buildVirtualCardSection(CuentaModel? cuenta) {
    final numCuenta = cuenta?.numeroCuenta ?? '0000000000';
    final paddedAccount = numCuenta.padLeft(10, '0');
    final cardFormatted =
        '4152 89${paddedAccount.substring(0, 2)} ${paddedAccount.substring(2, 6)} ${paddedAccount.substring(6)}';
    final last4 = numCuenta.length >= 4
        ? numCuenta.substring(numCuenta.length - 4)
        : '0000';
    final displayedCardNum =
        _showCardCredentials ? cardFormatted : '••••  ••••  ••••  $last4';
    final rawHolder = (_profile?.nombreCompleto ?? '').trim();
    final cardHolder =
        (rawHolder.isNotEmpty ? rawHolder : 'CLIENTE FINTECH').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.credit_card_rounded, color: Color(0xFF0F172A), size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Tarjeta Digital Débito',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _showCardCredentials = !_showCardCredentials);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _showCardCredentials
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  _showCardCredentials
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                ),
                label: Text(
                  _showCardCredentials ? 'Ocultar Tarjeta' : 'Ver Número',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                constraints: const BoxConstraints(minHeight: 228),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E3A5F),
                      Color(0xFF091322),
                    ],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.34),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -36,
                      top: -36,
                      child: IgnorePointer(
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF38BDF8).withValues(alpha: 0.14),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -24,
                      bottom: -42,
                      child: IgnorePointer(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFDE68A),
                                        Color(0xFFD4AF37),
                                        Color(0xFFA16207),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF854D0E),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: IgnorePointer(
                                    child: SizedBox(
                                      width: 44,
                                      height: 32,
                                      child: CustomPaint(
                                        size: const Size(44, 32),
                                        painter: const _ChipCircuitsPainter(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.contactless_rounded,
                                  color: Colors.white.withValues(alpha: 0.78),
                                  size: 24,
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'GestoPago',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '• DÉBITO',
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  displayedCardNum,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: _showCardCredentials ? 2.4 : 2.8,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                            if (_showCardCredentials) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: Color(0xFF5EEAD4),
                                  size: 18,
                                ),
                                tooltip: 'Copiar número de tarjeta',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: cardFormatted.replaceAll(' ', '')),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Número de tarjeta virtual copiado'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 26),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TITULAR',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cardHolder,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.9,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'VENCE',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '11/29',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF0F766E)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _showCardCredentials
                        ? 'Número de tarjeta visible. No lo compartas con nadie.'
                        : 'Datos de tarjeta protegidos. Pulsa "Ver Número" para visualizarla.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ApiService.recordUserActivity();
            setState(() {
              _selectedCategory = category;
              _selectedIndex = 1;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
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
                  TextField(
                    maxLength: 80,
                    inputFormatters: [
                      SecurityValidators.safeSearchFormatter,
                      LengthLimitingTextInputFormatter(80),
                    ],
                    onChanged: (v) => setState(() => _searchQuery = SecurityValidators.sanitize(v)),
                    decoration: InputDecoration(
                      counterText: '',
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
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._categories.map(
                          (cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFF0F172A),
                                backgroundColor: Colors.white,
                                checkmarkColor: Colors.white,
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = cat),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(
                            'Solo disponibles para compra',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _onlyAvailableProducts ? FontWeight.w600 : FontWeight.w500,
                              color: _onlyAvailableProducts ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          selected: _onlyAvailableProducts,
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white,
                          checkmarkColor: Colors.white,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetailSheet(p),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Monograma(
                      idServicio: p.idServicio,
                      nombre: p.servicio,
                      size: 46,
                      borderRadius: 12,
                      accentColor: p.brandColor,
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
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.producto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    p.descripcionDetallada,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.isFixedAmount ? 'PRECIO FIJO' : 'PAGO DE SERVICIO',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              p.precio > 0
                                  ? CurrencyFormatter.format(p.precio, withMxn: true)
                                  : 'Monto Libre',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: p.isAvailableForPurchase
                          ? () => _openPurchaseModal(p)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 15),
                      label: const Text(
                        'Comprar',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                              label: Text(
                                'Mostrar únicamente compras exitosas',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _onlySuccessfulPurchases
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _onlySuccessfulPurchases
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              selected: _onlySuccessfulPurchases,
                              selectedColor: const Color(0xFF0F172A),
                              backgroundColor: Colors.white,
                              checkmarkColor: Colors.white,
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
        ? const Color(0xFF236B51)
        : (tx.isPending ? const Color(0xFFB45309) : const Color(0xFF8B3A3A));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        onTap: () => _openTransactionDetailModal(tx),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Monograma(
              idServicio: tx.idServicio,
              nombre: tx.servicioNombre ?? tx.displayTitle,
              size: 46,
              borderRadius: 12,
              accentColor: statusColor,
            ),
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.8),
                ),
                child: Icon(
                  tx.isSucceeded
                      ? Icons.check_rounded
                      : (tx.isPending ? Icons.schedule_rounded : Icons.close_rounded),
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ),
          ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha: ${tx.formattedDate}  •  Folio UPC: ${tx.upc}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              if (tx.providerAuthorization != null &&
                  tx.providerAuthorization!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Aut: ${tx.providerAuthorization}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(tx.monto, withMxn: true),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tx.estadoLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 3: SEGURIDAD Y PERFIL (PROTEGIDO CON PIN) ====================
  Future<void> _verifyProfileAccessPin() async {
    final pin = _profilePinCtrl.text.trim();
    final err = SecurityValidators.validate2faOrPin(pin, onlyFourDigits: true);
    if (err != null) {
      setState(() => _profilePinError = err);
      return;
    }
    setState(() {
      _verifyingProfilePin = true;
      _profilePinError = null;
    });
    final res = await ApiService.verificarPin(pin);
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _verifyingProfilePin = false;
        _profileSecurityUnlocked = true;
        _profilePinCtrl.clear();
      });
    } else {
      setState(() {
        _verifyingProfilePin = false;
        _profilePinError = res.message;
      });
    }
  }

  Widget _buildProfilePinGate() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(32),
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Acceso a Seguridad y Perfil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tu PIN de seguridad de 4 dígitos para consultar o modificar tus datos personales y credenciales.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.45),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _profilePinCtrl,
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
                  onSubmitted: (_) => _verifyingProfilePin ? null : _verifyProfileAccessPin(),
                  decoration: InputDecoration(
                    labelText: 'PIN de Seguridad (4 dígitos)',
                    floatingLabelAlignment: FloatingLabelAlignment.center,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_profilePinError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _profilePinError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _verifyingProfilePin ? null : _verifyProfileAccessPin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _verifyingProfilePin
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(
                    _verifyingProfilePin ? 'Verificando PIN...' : 'Desbloquear Seguridad y Perfil',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityAndProfileTab() {
    if (!_profileSecurityUnlocked) {
      return _buildProfilePinGate();
    }

    final pinCtrl = _newPinCtrl;
    final passActualCtrl = _passActualCtrl;
    final passNuevaCtrl = _passNuevaCtrl;
    final passConfirmCtrl = _passConfirmCtrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 640;
              final infoItems = [
                ('Nombre Completo', _profile?.nombreCompleto ?? 'N/A', Icons.person_outline_rounded),
                ('Correo Autenticado', _profile?.correo ?? 'N/A', Icons.email_outlined),
                ('Teléfono Móvil', _profile?.telefonoMovil ?? 'N/A', Icons.phone_android_rounded),
                ('RFC', _profile?.rfc ?? 'N/A', Icons.assignment_ind_outlined),
                ('CURP', _profile?.curp ?? 'N/A', Icons.fingerprint_rounded),
                (
                  'Sesión Activa',
                  'Única (${kIsWeb ? "Web" : "App Móvil"})',
                  Icons.devices_rounded,
                ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado del perfil con botón de bloqueo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Información del Titular',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '2FA activo con Google Authenticator y PIN criptográfico',
                                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _profileSecurityUnlocked = false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.lock_outline_rounded, size: 16),
                              label: const Text('Bloquear', style: TextStyle(fontSize: 12.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        if (isNarrow)
                          Column(
                            children: [
                              for (int i = 0; i < infoItems.length; i++) ...[
                                _profileInfoTile(infoItems[i].$1, infoItems[i].$2, infoItems[i].$3),
                                if (i < infoItems.length - 1) const SizedBox(height: 12),
                              ],
                            ],
                          )
                        else
                          Column(
                            children: [
                              for (int i = 0; i < infoItems.length; i += 2) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _profileInfoTile(
                                        infoItems[i].$1,
                                        infoItems[i].$2,
                                        infoItems[i].$3,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: i + 1 < infoItems.length
                                          ? _profileInfoTile(
                                              infoItems[i + 1].$1,
                                              infoItems[i + 1].$2,
                                              infoItems[i + 1].$3,
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                                if (i + 2 < infoItems.length) const SizedBox(height: 14),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actualizar PIN
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actualizar PIN de Seguridad (4 dígitos)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Solicitado al abrir Seguridad y Perfil y antes de autorizar compras en GestoPago.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: isNarrow ? double.infinity : 280,
                              child: TextField(
                                controller: pinCtrl,
                                obscureText: true,
                                maxLength: 4,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'Nuevo PIN de 4 dígitos',
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.pin_outlined),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
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
                                      backgroundColor: const Color(0xFF8B3A3A),
                                    ),
                                  );
                                  return;
                                }
                                final messenger = ScaffoldMessenger.of(context);
                                final res = await ApiService.actualizarPin(pinCtrl.text);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res.message),
                                    backgroundColor: res.success
                                        ? const Color(0xFF236B51)
                                        : const Color(0xFF8B3A3A),
                                  ),
                                );
                                if (res.success) {
                                  pinCtrl.clear();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Actualizar PIN'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Cambiar Contraseña
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cambiar Contraseña de Acceso',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Debe contener entre 8 y 13 caracteres, sin espacios, con mayúscula, minúscula, número y símbolo.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: isNarrow ? double.infinity : 265,
                              child: TextField(
                                controller: passActualCtrl,
                                obscureText: _obscurePassActual,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña Actual',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassActual
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                    ),
                                    tooltip: _obscurePassActual ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                    onPressed: () =>
                                        setState(() => _obscurePassActual = !_obscurePassActual),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: isNarrow ? double.infinity : 265,
                              child: TextField(
                                controller: passNuevaCtrl,
                                obscureText: _obscurePassNueva,
                                maxLength: 13,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                  LengthLimitingTextInputFormatter(13),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Nueva Contraseña (8-13)',
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassNueva
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                    ),
                                    tooltip: _obscurePassNueva ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                    onPressed: () =>
                                        setState(() => _obscurePassNueva = !_obscurePassNueva),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: isNarrow ? double.infinity : 265,
                              child: TextField(
                                controller: passConfirmCtrl,
                                obscureText: _obscurePassConfirm,
                                maxLength: 13,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                  LengthLimitingTextInputFormatter(13),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Confirmar Contraseña',
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                    ),
                                    tooltip: _obscurePassConfirm ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                    onPressed: () =>
                                        setState(() => _obscurePassConfirm = !_obscurePassConfirm),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: isNarrow ? Alignment.center : Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () async {
                              if (SecurityValidators.containsInjectionAttempt(passActualCtrl.text) ||
                                  SecurityValidators.containsInjectionAttempt(passConfirmCtrl.text)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Se detectaron caracteres no permitidos por seguridad.'),
                                    backgroundColor: Color(0xFF8B3A3A),
                                  ),
                                );
                                return;
                              }
                              final err = SecurityValidators.validateStrongPassword(
                                passNuevaCtrl.text,
                              );
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor: const Color(0xFF8B3A3A),
                                  ),
                                );
                                return;
                              }
                              final messenger = ScaffoldMessenger.of(context);
                              final res = await ApiService.cambiarPassword(
                                passwordActual: passActualCtrl.text,
                                passwordNueva: passNuevaCtrl.text,
                                passwordConfirmacion: passConfirmCtrl.text,
                              );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success
                                      ? const Color(0xFF236B51)
                                      : const Color(0xFF8B3A3A),
                                ),
                              );
                              if (res.success) {
                                passActualCtrl.clear();
                                passNuevaCtrl.clear();
                                passConfirmCtrl.clear();
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.key_rounded, size: 18),
                            label: const Text('Actualizar Contraseña'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChipCircuitsPainter extends CustomPainter {
  const _ChipCircuitsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF785203)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), paint);
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


