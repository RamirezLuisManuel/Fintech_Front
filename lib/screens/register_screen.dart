import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/security_validators.dart';
import 'account_created_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Wizard de 3 Pasos
  int _currentStep = 0;
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  // Paso 1: Datos Personales
  final _nombreCtrl = TextEditingController();
  final _segundoNombreCtrl = TextEditingController();
  final _apellidoPaternoCtrl = TextEditingController();
  final _apellidoMaternoCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _nombreFocus = FocusNode();
  final _segundoNombreFocus = FocusNode();
  final _apellidoPaternoFocus = FocusNode();
  final _apellidoMaternoFocus = FocusNode();
  final _curpFocus = FocusNode();
  final _rfcFocus = FocusNode();
  String _sexo = 'M';
  final String _estadoCivil = 'Soltero';

  // Selector desplegable de fecha (Año, Mes, Día)
  int _selectedYear = 2000;
  int _selectedMonth = 5;
  int _selectedDay = 15;

  // Paso 2: Contacto, Empresa y Ocupación
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ingresoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _correoFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _telefonoFocus = FocusNode();
  final _empresaFocus = FocusNode();
  final _ingresoFocus = FocusNode();
  CatalogItem? _selectedOcupacion;
  List<CatalogItem> _ocupaciones = [];

  // Paso 3: Domicilio Oficial (Catálogos Relacionales en Cascada)
  final _ocupacionFieldKey = GlobalKey<FormFieldState<CatalogItem>>();
  final _paisFieldKey = GlobalKey<FormFieldState<CatalogItem>>();
  final _estadoFieldKey = GlobalKey<FormFieldState<CatalogItem>>();
  final _municipioFieldKey = GlobalKey<FormFieldState<CatalogItem>>();
  final _coloniaFieldKey = GlobalKey<FormFieldState<CatalogItem>>();
  List<CatalogItem> _paises = [];
  List<CatalogItem> _estados = [];
  List<CatalogItem> _municipios = [];
  List<CatalogItem> _colonias = [];
  CatalogItem? _selectedPais;
  CatalogItem? _selectedEstado;
  CatalogItem? _selectedMunicipio;
  CatalogItem? _selectedColonia;
  bool _loadingEstados = false;
  bool _loadingMunicipios = false;
  bool _loadingColonias = false;

  final _calleCtrl = TextEditingController();
  final _numExtCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _cpFocus = FocusNode();
  final _calleFocus = FocusNode();
  final _numExtFocus = FocusNode();

  bool _obscurePass = true;
  bool _isLoading = false;

  static const List<String> _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    final paisesList = await ApiService.getPaises();
    final ocupacionesList = await ApiService.getOcupaciones();
    if (!mounted) return;
    setState(() {
      _paises = paisesList;
      _ocupaciones = ocupacionesList;
    });
  }

  Future<void> _onPaisChanged(CatalogItem? pais) async {
    setState(() {
      _selectedPais = pais;
      _selectedEstado = null;
      _selectedMunicipio = null;
      _selectedColonia = null;
      _estados = [];
      _municipios = [];
      _colonias = [];
      _loadingEstados = pais != null;
    });
    _estadoFieldKey.currentState?.didChange(null);
    _municipioFieldKey.currentState?.didChange(null);
    _coloniaFieldKey.currentState?.didChange(null);
    if (pais == null) return;
    final estadosList = await ApiService.getEstados(pais.id);
    if (!mounted) return;
    setState(() {
      _estados = estadosList;
      _loadingEstados = false;
      if (pais.isOtro && _estados.isNotEmpty) {
        _selectedEstado = _estados.first;
        _municipios = const [CatalogItem(id: -1, nombre: 'Otro')];
        _selectedMunicipio = _municipios.first;
        _colonias = const [CatalogItem(id: -1, nombre: 'Otra')];
        _selectedColonia = _colonias.first;
      }
    });
    if (pais.isOtro && _selectedEstado != null) {
      _estadoFieldKey.currentState?.didChange(_selectedEstado);
      _municipioFieldKey.currentState?.didChange(_selectedMunicipio);
      _coloniaFieldKey.currentState?.didChange(_selectedColonia);
    }
  }

  Future<void> _onEstadoChanged(CatalogItem? estado) async {
    setState(() {
      _selectedEstado = estado;
      _selectedMunicipio = null;
      _selectedColonia = null;
      _municipios = [];
      _colonias = [];
      _loadingMunicipios = estado != null;
    });
    _municipioFieldKey.currentState?.didChange(null);
    _coloniaFieldKey.currentState?.didChange(null);
    if (estado == null) return;
    final municipiosList = await ApiService.getMunicipios(estado.id);
    if (!mounted) return;
    setState(() {
      _municipios = municipiosList;
      _loadingMunicipios = false;
      if (estado.isOtro && _municipios.isNotEmpty) {
        _selectedMunicipio = _municipios.first;
        _colonias = const [CatalogItem(id: -1, nombre: 'Otra')];
        _selectedColonia = _colonias.first;
      }
    });
    if (estado.isOtro && _selectedMunicipio != null) {
      _municipioFieldKey.currentState?.didChange(_selectedMunicipio);
      _coloniaFieldKey.currentState?.didChange(_selectedColonia);
    }
  }

  Future<void> _onMunicipioChanged(CatalogItem? municipio) async {
    setState(() {
      _selectedMunicipio = municipio;
      _selectedColonia = null;
      _colonias = [];
      _loadingColonias = municipio != null;
    });
    _coloniaFieldKey.currentState?.didChange(null);
    if (municipio == null) return;
    final coloniasList = await ApiService.getColonias(municipio.id);
    if (!mounted) return;
    setState(() {
      _colonias = coloniasList;
      _loadingColonias = false;
      if (municipio.isOtro && _colonias.isNotEmpty) {
        _selectedColonia = _colonias.first;
      }
    });
    if (municipio.isOtro && _selectedColonia != null) {
      _coloniaFieldKey.currentState?.didChange(_selectedColonia);
    }
  }

  void _onColoniaChanged(CatalogItem? colonia) {
    setState(() {
      _selectedColonia = colonia;
      if (colonia != null &&
          colonia.codigoPostal != null &&
          colonia.codigoPostal!.length == 5) {
        _cpCtrl.text = colonia.codigoPostal!;
      } else if (colonia != null && colonia.isOtro) {
        _cpCtrl.clear();
      }
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _segundoNombreCtrl.dispose();
    _apellidoPaternoCtrl.dispose();
    _apellidoMaternoCtrl.dispose();
    _curpCtrl.dispose();
    _rfcCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _ingresoCtrl.dispose();
    _empresaCtrl.dispose();
    _calleCtrl.dispose();
    _numExtCtrl.dispose();
    _cpCtrl.dispose();
    _nombreFocus.dispose();
    _segundoNombreFocus.dispose();
    _apellidoPaternoFocus.dispose();
    _apellidoMaternoFocus.dispose();
    _curpFocus.dispose();
    _rfcFocus.dispose();
    _correoFocus.dispose();
    _passwordFocus.dispose();
    _telefonoFocus.dispose();
    _empresaFocus.dispose();
    _ingresoFocus.dispose();
    _cpFocus.dispose();
    _calleFocus.dispose();
    _numExtFocus.dispose();
    super.dispose();
  }

  int _maxDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _advanceToStep2() {
    final isFormValid = _step1Key.currentState?.validate() ?? false;
    final ageErr = SecurityValidators.validateAge18Plus(
      _selectedYear,
      _selectedMonth,
      _selectedDay,
    );

    if (!isFormValid || ageErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ageErr ?? 'Por favor corrige los datos personales antes de continuar.'),
          backgroundColor: const Color(0xFF8B3A3A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _currentStep = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _correoFocus.requestFocus();
    });
  }

  void _advanceToStep3() {
    final isFormValid = _step2Key.currentState?.validate() ?? false;
    if (!isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor corrige tus credenciales y datos de contacto antes de continuar.'),
          backgroundColor: Color(0xFF8B3A3A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _currentStep = 2);
  }

  Future<void> _submitRegister() async {
    final isFormValid = _step3Key.currentState?.validate() ?? false;
    if (!isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa los datos de tu domicilio antes de registrarte.'),
          backgroundColor: Color(0xFF8B3A3A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final birthDateStr =
        '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}';

    final tieneEmpresa = _empresaCtrl.text.trim().isNotEmpty;
    final empresaVal = tieneEmpresa ? SecurityValidators.sanitize(_empresaCtrl.text) : null;
    final ocupacionVal = _selectedOcupacion?.nombre;
    final ingresoRaw = _ingresoCtrl.text.replaceAll(',', '').trim();
    final ingresoVal = (_selectedOcupacion != null && ingresoRaw.isNotEmpty)
        ? (double.tryParse(ingresoRaw) ?? 0.0)
        : 0.0;

    final paisVal = _selectedPais?.nombre ?? '';
    final estadoVal = _selectedEstado?.nombre ?? '';
    final municipioVal = _selectedMunicipio?.nombre ?? '';
    final coloniaVal = _selectedColonia?.nombre ?? '';

    final payload = {
      'nombre': SecurityValidators.sanitize(_nombreCtrl.text),
      'segundoNombre': SecurityValidators.sanitize(_segundoNombreCtrl.text),
      'apellidoPaterno': SecurityValidators.sanitize(_apellidoPaternoCtrl.text),
      'apellidoMaterno': SecurityValidators.sanitize(_apellidoMaternoCtrl.text),
      'fechaNacimiento': birthDateStr,
      'curp': _curpCtrl.text.trim().toUpperCase(),
      'rfc': _rfcCtrl.text.trim().toUpperCase(),
      'sexo': _sexo,
      'nacionalidad': 'Mexicana',
      'estadoCivil': _estadoCivil,
      'correo': SecurityValidators.sanitize(_correoCtrl.text),
      'telefonoMovil': _telefonoCtrl.text.trim(),
      'ocupacion': ocupacionVal,
      'empresa': empresaVal,
      'ingresoMensual': ingresoVal,
      'password': _passwordCtrl.text,
      'domicilio': {
        'calle': SecurityValidators.sanitize(_calleCtrl.text),
        'numeroExterior': SecurityValidators.sanitize(_numExtCtrl.text),
        'colonia': coloniaVal,
        'municipio': municipioVal,
        'estado': estadoVal,
        'codigoPostal': _cpCtrl.text.trim(),
        'pais': paisVal,
      },
    };

    final res = await ApiService.registrarCliente(payload);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success && res.data != null) {
      final numCuenta = (res.data!['numero_cuenta'] ?? 'N/A').toString();
      final pin = (res.data!['pin'] ?? 'N/A').toString();
      final totpSecret = (res.data!['totp_secret'] ?? '').toString();
      final totpUri = (res.data!['totp_uri'] ?? '').toString();
      final aviso = (res.data!['aviso_seguridad'] ??
              'Guarda tus credenciales de acceso y clave de Google Authenticator.')
          .toString();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AccountCreatedScreen(
            correo: _correoCtrl.text.trim(),
            numCuenta: numCuenta,
            pin: pin,
            totpSecret: totpSecret,
            totpUri: totpUri,
            aviso: aviso,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF8B3A3A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1020;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 14,
              vertical: isWide ? 32 : 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1200 : 640),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: isWide
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF0F172A),
                                            Color(0xFF1E3A8A),
                                            Color(0xFF0F766E),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 7,
                                    child: ColoredBox(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildRegisterHeroPanel()),
                              Expanded(flex: 7, child: _buildRegisterWizardPanel(isWide: true)),
                            ],
                          ),
                        ],
                      )
                    : _buildRegisterWizardPanel(isWide: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== PANEL INFORMATIVO IZQUIERDO ====================

  Widget _buildRegisterHeroPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Volver al Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 24),
              const Text(
                'Apertura de Cuenta Digital por Pasos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Registro guiado en 3 etapas seguras: Datos Personales, Contacto con Google Authenticator y Domicilio Oficial.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5EEAD4).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: Color(0xFF5EEAD4),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bono de Apertura: \$1,000.00 MXN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Saldo inicial acreditado de inmediato en tu cuenta para recargas y pagos.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildFeatureBullet(
                icon: Icons.phonelink_lock_rounded,
                title: '2FA con Google Authenticator',
                desc: 'Protección con códigos OTP dinámicos de 6 dígitos compatibles con Google Authenticator.',
              ),
              const SizedBox(height: 16),
              _buildFeatureBullet(
                icon: Icons.badge_rounded,
                title: 'Validación Oficial CURP y RFC',
                desc: 'Verificación estricta de formato oficial y mayoría de edad (+18 años).',
              ),
              const SizedBox(height: 16),
              _buildFeatureBullet(
                icon: Icons.list_alt_rounded,
                title: 'Catálogos Oficiales',
                desc: 'Selección de ocupaciones principales y los 30 países más representativos.',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF5EEAD4)),
              const SizedBox(width: 8),
              Text(
                'Cifrado HTTPS • API REST GestoPago Oficial',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF5EEAD4), size: 18),
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
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== WIZARD DE REGISTRO EN 3 PASOS ====================

  Widget _buildRegisterWizardPanel({required bool isWide}) {
    return Container(
      color: isWide ? Colors.transparent : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 20,
        vertical: isWide ? 36 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWide) ...[
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E3A8A)),
                  tooltip: 'Volver al Login',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Apertura de Cuenta Digital',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2E4B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildStepProgressBar(),
          const SizedBox(height: 20),
          if (_currentStep == 0) _buildStep1Form(isWide),
          if (_currentStep == 1) _buildStep2Form(isWide),
          if (_currentStep == 2) _buildStep3Form(isWide),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '¿Ya tienes una cuenta registrada? ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressBar() {
    return Column(
      children: [
        Row(
          children: [
            _stepBadge(0, '1. Personales', Icons.person_outline),
            Expanded(child: _stepDivider(0)),
            _stepBadge(1, '2. Contacto', Icons.contact_mail_outlined),
            Expanded(child: _stepDivider(1)),
            _stepBadge(2, '3. Domicilio', Icons.home_outlined),
          ],
        ),
      ],
    );
  }

  Widget _stepBadge(int stepIndex, String title, IconData icon) {
    final isDone = _currentStep > stepIndex;
    final isActive = _currentStep == stepIndex;

    Color bgColor = const Color(0xFFF1F5F9);
    Color fgColor = const Color(0xFF64748B);

    if (isActive) {
      bgColor = const Color(0xFF1E3A8A);
      fgColor = Colors.white;
    } else if (isDone) {
      bgColor = const Color(0xFF236B51);
      fgColor = Colors.white;
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: bgColor,
          child: Icon(
            isDone ? Icons.check_rounded : icon,
            color: fgColor,
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? const Color(0xFF1E3A8A)
                : (isDone ? const Color(0xFF236B51) : const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _stepDivider(int priorStepIndex) {
    final isPassed = _currentStep > priorStepIndex;
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      color: isPassed ? const Color(0xFF236B51) : const Color(0xFFE2E8F0),
    );
  }

  // ==================== PASO 1: DATOS PERSONALES ====================

  Widget _buildStep1Form(bool isWide) {
    return Form(
      key: _step1Key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. Datos Personales e Identificación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B2E4B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ingresa tus datos como aparecen en tu identificación oficial. Debes ser mayor de 18 años.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              _responsivePair(
                isNarrow: isNarrow,
                first: TextFormField(
                  controller: _nombreCtrl,
                  focusNode: _nombreFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _segundoNombreFocus.requestFocus(),
                  maxLength: 50,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  validator: (v) => SecurityValidators.validatePersonName(v, 'El nombre'),
                  decoration: _inputDeco('Nombre (mínimo 3 letras) *', Icons.person_outline)
                      .copyWith(counterText: ''),
                ),
                second: TextFormField(
                  controller: _segundoNombreCtrl,
                  focusNode: _segundoNombreFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _apellidoPaternoFocus.requestFocus(),
                  maxLength: 50,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  validator: (v) => SecurityValidators.validatePersonName(
                    v,
                    'El segundo nombre',
                    required: false,
                  ),
                  decoration: _inputDeco('Segundo Nombre (opcional)', Icons.person_outline)
                      .copyWith(counterText: ''),
                ),
              ),
              const SizedBox(height: 16),

              _responsivePair(
                isNarrow: isNarrow,
                first: TextFormField(
                  controller: _apellidoPaternoCtrl,
                  focusNode: _apellidoPaternoFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _apellidoMaternoFocus.requestFocus(),
                  maxLength: 50,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  validator: (v) => SecurityValidators.validatePersonName(v, 'El apellido paterno'),
                  decoration: _inputDeco('Apellido Paterno (mínimo 3 letras) *', Icons.badge_outlined)
                      .copyWith(counterText: ''),
                ),
                second: TextFormField(
                  controller: _apellidoMaternoCtrl,
                  focusNode: _apellidoMaternoFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _curpFocus.requestFocus(),
                  maxLength: 50,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  validator: (v) => SecurityValidators.validatePersonName(v, 'El apellido materno'),
                  decoration: _inputDeco('Apellido Materno (mínimo 3 letras) *', Icons.badge_outlined)
                      .copyWith(counterText: ''),
                ),
              ),
              const SizedBox(height: 16),

              _responsivePair(
                isNarrow: isNarrow,
                first: _buildBirthDateSelector(),
                second: DropdownButtonFormField<String>(
                  initialValue: _sexo,
                  decoration: _inputDeco('Sexo *', Icons.wc_rounded),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Masculino (M)')),
                    DropdownMenuItem(value: 'F', child: Text('Femenino (F)')),
                  ],
                  onChanged: (v) => setState(() => _sexo = v ?? 'M'),
                ),
              ),
              const SizedBox(height: 16),

              _responsivePair(
                isNarrow: isNarrow,
                first: TextFormField(
                  controller: _curpCtrl,
                  focusNode: _curpFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _rfcFocus.requestFocus(),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 18,
                  inputFormatters: [
                    _UpperCaseAlphanumericFormatter(),
                    LengthLimitingTextInputFormatter(18),
                  ],
                  validator: SecurityValidators.validateCurp,
                  decoration: _inputDeco('CURP Oficial (18 caracteres) *', Icons.fingerprint)
                      .copyWith(counterText: ''),
                ),
                second: TextFormField(
                  controller: _rfcCtrl,
                  focusNode: _rfcFocus,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _advanceToStep2(),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 13,
                  inputFormatters: [
                    _UpperCaseAlphanumericFormatter(),
                    LengthLimitingTextInputFormatter(13),
                  ],
                  validator: SecurityValidators.validateRfc,
                  decoration: _inputDeco('RFC con Homoclave (13 caracteres) *', Icons.assignment_ind)
                      .copyWith(counterText: ''),
                ),
              ),

              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _advanceToStep2,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text(
                  'Continuar a Contacto (Paso 2)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== PASO 2: CONTACTO Y SEGURIDAD ====================

  Widget _buildStep2Form(bool isWide) {
    return Form(
      key: _step2Key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '2. Credenciales de Acceso, Contacto y Ocupación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B2E4B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Configura tu correo electrónico, contraseña segura, teléfono y selecciona tu ocupación del catálogo.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _correoCtrl,
                focusNode: _correoFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                keyboardType: TextInputType.emailAddress,
                maxLength: 100,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(100),
                ],
                validator: SecurityValidators.validateEmail,
                decoration: _inputDeco('Correo Electrónico (máximo 100 caracteres) *', Icons.email_outlined)
                    .copyWith(counterText: ''),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _telefonoFocus.requestFocus(),
                obscureText: _obscurePass,
                maxLength: 13,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: SecurityValidators.validateStrongPassword,
                decoration: _inputDeco(
                  'Contraseña Segura (8 a 13 caracteres) *',
                  Icons.lock_outline,
                ).copyWith(
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _responsivePair(
                isNarrow: isNarrow,
                first: TextFormField(
                  controller: _telefonoCtrl,
                  focusNode: _telefonoFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _empresaFocus.requestFocus(),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: SecurityValidators.validatePhone,
                  decoration: _inputDeco('Teléfono Móvil (10 dígitos) *', Icons.phone_android)
                      .copyWith(counterText: ''),
                ),
                second: TextFormField(
                  controller: _empresaCtrl,
                  focusNode: _empresaFocus,
                  textInputAction: _selectedOcupacion != null
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_selectedOcupacion != null) {
                      _ingresoFocus.requestFocus();
                    } else {
                      _advanceToStep3();
                    }
                  },
                  maxLength: 100,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final requiereEmpresa = _selectedOcupacion != null &&
                        _selectedOcupacion!.nombre.toLowerCase() != 'estudiante';
                    if (v == null || v.trim().isEmpty) {
                      return requiereEmpresa
                          ? '• Para esta ocupación es obligatorio ingresar una empresa'
                          : null;
                    }
                    return SecurityValidators.validateSafeText(v, 'La empresa', min: 2, max: 100);
                  },
                  decoration: _inputDeco(
                    (_selectedOcupacion != null &&
                            _selectedOcupacion!.nombre.toLowerCase() != 'estudiante')
                        ? 'Empresa *'
                        : 'Empresa (opcional)',
                    Icons.business_outlined,
                  ).copyWith(counterText: '', hintText: 'Deja vacío si no aplica'),
                ),
              ),
              const SizedBox(height: 16),

              _responsivePair(
                isNarrow: isNarrow,
                first: _buildSearchableCatalogField(
                  fieldKey: _ocupacionFieldKey,
                  label: _empresaCtrl.text.trim().isNotEmpty
                      ? 'Ocupación *'
                      : 'Ocupación (opcional)',
                  hint: 'Buscar o seleccionar ocupación',
                  icon: Icons.work_outline,
                  items: _ocupaciones,
                  selected: _selectedOcupacion,
                  enabled: true,
                  allowClear: _empresaCtrl.text.trim().isEmpty,
                  onSelected: (v) {
                    setState(() {
                      _selectedOcupacion = v;
                      if (v == null) {
                        _ingresoCtrl.clear();
                      }
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _step2Key.currentState?.validate();
                    });
                  },
                  validator: (v) {
                    final tieneEmpresa = _empresaCtrl.text.trim().isNotEmpty;
                    final tieneIngreso = _ingresoCtrl.text.replaceAll(',', '').trim().isNotEmpty;
                    if (tieneEmpresa && v == null) {
                      return '• Si ingresas una empresa, primero selecciona una ocupación';
                    }
                    if (tieneIngreso && v == null) {
                      return '• Para registrar ingresos debes seleccionar primero una ocupación';
                    }
                    return null;
                  },
                ),
                second: TextFormField(
                  controller: _ingresoCtrl,
                  focusNode: _ingresoFocus,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _advanceToStep3(),
                  enabled: _selectedOcupacion != null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 15,
                  inputFormatters: [
                    _ThousandsSeparatorInputFormatter(),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: (v) {
                    final tieneEmpresa = _empresaCtrl.text.trim().isNotEmpty;
                    final tieneOcupacion = _selectedOcupacion != null;
                    final esEstudiante =
                        _selectedOcupacion?.nombre.toLowerCase() == 'estudiante';
                    final requiereIngreso =
                        (tieneOcupacion && !esEstudiante) || (tieneEmpresa && !esEstudiante);
                    final raw = (v ?? '').replaceAll(',', '').trim();
                    if (tieneEmpresa && !tieneOcupacion) {
                      return '• Primero selecciona tu ocupación antes del ingreso';
                    }
                    if (requiereIngreso) {
                      if (raw.isEmpty) {
                        return '• Para esta ocupación el ingreso mensual es obligatorio';
                      }
                      return SecurityValidators.validateAmount(v);
                    }
                    if (raw.isEmpty) return null;
                    if (!tieneOcupacion) {
                      return '• Selecciona una ocupación para registrar ingresos';
                    }
                    return SecurityValidators.validateAmount(v);
                  },
                  decoration: _inputDeco(
                    ((_selectedOcupacion != null &&
                                _selectedOcupacion!.nombre.toLowerCase() != 'estudiante') ||
                            (_empresaCtrl.text.trim().isNotEmpty &&
                                _selectedOcupacion?.nombre.toLowerCase() != 'estudiante'))
                        ? 'Ingreso Mensual Estimado (MXN) *'
                        : 'Ingreso Mensual Estimado (opcional)',
                    Icons.attach_money,
                  ).copyWith(
                    counterText: '',
                    hintText: _selectedOcupacion == null
                        ? 'Selecciona primero una ocupación'
                        : 'Ej. 15,000',
                  ),
                ),
              ),

              const SizedBox(height: 28),
              if (isNarrow) ...[
                FilledButton.icon(
                  onPressed: _advanceToStep3,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text(
                    'Continuar a Domicilio (Paso 3)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 0),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Anterior', textAlign: TextAlign.center),
                ),
              ] else
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep = 0),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Anterior', textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _advanceToStep3,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: const Text(
                          'Continuar a Domicilio (Paso 3)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  // ==================== PASO 3: DOMICILIO OFICIAL ====================

  Widget _buildStep3Form(bool isWide) {
    return Form(
      key: _step3Key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '3. Domicilio Oficial del Titular',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B2E4B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Busca y selecciona tu país, estado, municipio y colonia o comunidad desde los catálogos oficiales.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              _responsivePair(
                isNarrow: isNarrow,
                first: _buildSearchableCatalogField(
                  fieldKey: _paisFieldKey,
                  label: 'País *',
                  hint: 'Buscar país...',
                  icon: Icons.public_outlined,
                  items: _paises,
                  selected: _selectedPais,
                  enabled: true,
                  onSelected: _onPaisChanged,
                  validator: (v) => v == null ? '• Selecciona un país' : null,
                ),
                second: _buildSearchableCatalogField(
                  fieldKey: _estadoFieldKey,
                  label: _loadingEstados ? 'Cargando estados...' : 'Estado o Entidad *',
                  hint: _selectedPais == null
                      ? 'Selecciona primero un país'
                      : 'Buscar estado o entidad...',
                  icon: Icons.map_outlined,
                  items: _estados,
                  selected: _selectedEstado,
                  enabled: _selectedPais != null && !_loadingEstados,
                  onSelected: _onEstadoChanged,
                  validator: (v) => v == null ? '• Selecciona un estado o entidad' : null,
                ),
              ),
              const SizedBox(height: 16),

              _responsivePair(
                isNarrow: isNarrow,
                first: _buildSearchableCatalogField(
                  fieldKey: _municipioFieldKey,
                  label: _loadingMunicipios ? 'Cargando municipios...' : 'Municipio o Alcaldía *',
                  hint: _selectedEstado == null
                      ? 'Selecciona primero un estado'
                      : 'Buscar municipio o alcaldía...',
                  icon: Icons.location_city_outlined,
                  items: _municipios,
                  selected: _selectedMunicipio,
                  enabled: _selectedEstado != null && !_loadingMunicipios,
                  onSelected: _onMunicipioChanged,
                  validator: (v) => v == null ? '• Selecciona un municipio o alcaldía' : null,
                ),
                second: _buildSearchableCatalogField(
                  fieldKey: _coloniaFieldKey,
                  label: _loadingColonias ? 'Cargando colonias...' : 'Colonia o Comunidad *',
                  hint: _selectedMunicipio == null
                      ? 'Selecciona primero un municipio'
                      : 'Buscar colonia o comunidad...',
                  icon: Icons.holiday_village_outlined,
                  items: _colonias,
                  selected: _selectedColonia,
                  enabled: _selectedMunicipio != null && !_loadingColonias,
                  showPostalCode: true,
                  onSelected: _onColoniaChanged,
                  validator: (v) => v == null ? '• Selecciona una colonia o comunidad' : null,
                ),
              ),
              const SizedBox(height: 16),

              _responsivePair(
                isNarrow: isNarrow,
                first: TextFormField(
                  controller: _cpCtrl,
                  focusNode: _cpFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _calleFocus.requestFocus(),
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  validator: SecurityValidators.validatePostalCode,
                  decoration: _inputDeco('Código Postal (5 dígitos) *', Icons.markunread_mailbox_outlined)
                      .copyWith(counterText: ''),
                ),
                second: TextFormField(
                  controller: _calleCtrl,
                  focusNode: _calleFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _numExtFocus.requestFocus(),
                  maxLength: 100,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  validator: (v) => SecurityValidators.validateSafeText(v, 'La calle', min: 3, max: 100),
                  decoration: _inputDeco('Calle y Avenida (mínimo 3 caracteres) *', Icons.home_outlined)
                      .copyWith(counterText: ''),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _numExtCtrl,
                focusNode: _numExtFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isLoading) _submitRegister();
                },
                maxLength: 20,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                validator: (v) => SecurityValidators.validateSafeText(v, 'Número exterior', max: 20),
                decoration: _inputDeco('Número Exterior e Interior *', Icons.pin_drop_outlined)
                    .copyWith(counterText: ''),
              ),

              const SizedBox(height: 28),
              if (isNarrow) ...[
                FilledButton.icon(
                  onPressed: _isLoading ? null : _submitRegister,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF236B51),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _isLoading
                        ? 'Aperturando cuenta...'
                        : 'Finalizar y Aperturar Cuenta',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Anterior', textAlign: TextAlign.center),
                ),
              ] else
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep = 1),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Anterior', textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _submitRegister,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF236B51),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          _isLoading
                              ? 'Aperturando y generando PIN / 2FA...'
                              : 'Finalizar y Aperturar Cuenta Digital',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  // ==================== COMPONENTES RESPONSIVOS Y FECHA ====================

  Widget _responsivePair({
    required bool isNarrow,
    required Widget first,
    required Widget second,
  }) {
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: 16),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 14),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildBirthDateSelector() {
    final now = DateTime.now();
    final maxLegalYear = now.year - 18;
    final years = List<int>.generate(maxLegalYear - 1939, (i) => maxLegalYear - i);
    final maxDays = _maxDaysInMonth(_selectedYear, _selectedMonth);
    final ageErr = SecurityValidators.validateAge18Plus(_selectedYear, _selectedMonth, _selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ageErr != null ? const Color(0xFF8B3A3A) : const Color(0xFFCBD5E1),
              width: ageErr != null ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cake_outlined, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'Fecha de Nacimiento (Mayor de 18 años) *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedDay > maxDays ? maxDays : _selectedDay,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: InputBorder.none,
                        labelText: 'Día',
                        labelStyle: TextStyle(fontSize: 11),
                      ),
                      items: [
                        for (int d = 1; d <= maxDays; d++)
                          DropdownMenuItem(
                            value: d,
                            child: Text(d.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 13.5)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedDay = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedMonth,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: InputBorder.none,
                        labelText: 'Mes',
                        labelStyle: TextStyle(fontSize: 11),
                      ),
                      items: [
                        for (int m = 1; m <= 12; m++)
                          DropdownMenuItem(
                            value: m,
                            child: Text(_meses[m - 1], style: const TextStyle(fontSize: 13.5)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedMonth = v;
                            final newMax = _maxDaysInMonth(_selectedYear, _selectedMonth);
                            if (_selectedDay > newMax) _selectedDay = newMax;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedYear,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: InputBorder.none,
                        labelText: 'Año',
                        labelStyle: TextStyle(fontSize: 11),
                      ),
                      items: [
                        for (final y in years)
                          DropdownMenuItem(
                            value: y,
                            child: Text(y.toString(), style: const TextStyle(fontSize: 13.5)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedYear = v;
                            final newMax = _maxDaysInMonth(_selectedYear, _selectedMonth);
                            if (_selectedDay > newMax) _selectedDay = newMax;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (ageErr != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 6),
            child: Text(
              ageErr,
              style: const TextStyle(
                color: Color(0xFF8B3A3A),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// Normaliza texto removiendo acentos y mayúsculas para búsqueda flexible
  String _normalizeSearch(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  /// Selector de catálogo con buscador flexible en tiempo real (insensible a acentos/mayúsculas)
  Widget _buildSearchableCatalogField({
    required GlobalKey<FormFieldState<CatalogItem>> fieldKey,
    required String label,
    required String hint,
    required IconData icon,
    required List<CatalogItem> items,
    required CatalogItem? selected,
    required bool enabled,
    required ValueChanged<CatalogItem?> onSelected,
    String? Function(CatalogItem?)? validator,
    bool allowClear = false,
    bool showPostalCode = false,
  }) {
    return FormField<CatalogItem>(
      key: fieldKey,
      initialValue: selected,
      validator: validator,
      builder: (field) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled
              ? () async {
                  final picked = await _openCatalogSearchDialog(
                    title: label.replaceAll(' *', ''),
                    items: items,
                    selected: selected,
                    showPostalCode: showPostalCode,
                  );
                  if (picked != null) {
                    onSelected(picked);
                    field.didChange(picked);
                  }
                }
              : null,
          child: InputDecorator(
            isEmpty: selected == null,
            decoration: _inputDeco(label, icon).copyWith(
              enabled: enabled,
              errorText: field.errorText,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allowClear && selected != null && enabled)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      tooltip: 'Limpiar selección',
                      onPressed: () {
                        onSelected(null);
                        field.didChange(null);
                      },
                    ),
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            child: selected != null
                ? Text(
                    selected.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Future<CatalogItem?> _openCatalogSearchDialog({
    required String title,
    required List<CatalogItem> items,
    required CatalogItem? selected,
    bool showPostalCode = false,
  }) async {
    final searchCtrl = TextEditingController();
    final result = await showDialog<CatalogItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final queryTokens = _normalizeSearch(searchCtrl.text)
              .split(RegExp(r'\s+'))
              .where((t) => t.isNotEmpty)
              .toList();

          final filtered = items.where((item) {
            if (item.isOtro) return true;
            if (queryTokens.isEmpty) return true;
            final haystack = _normalizeSearch(
              '${item.nombre} ${item.codigoPostal ?? ''}',
            );
            return queryTokens.every((t) => haystack.contains(t));
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    maxLength: 60,
                    inputFormatters: [
                      SecurityValidators.safeSearchFormatter,
                      LengthLimitingTextInputFormatter(60),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Escribe letras para filtrar...',
                      prefixIcon: const Icon(Icons.filter_list_rounded, size: 20),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron coincidencias',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (_, idx) {
                              final item = filtered[idx];
                              final isSelected = selected == item;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: const Color(0xFFEFF6FF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                title: Text(
                                  item.nombre,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected || item.isOtro ? FontWeight.w600 : FontWeight.normal,
                                    color: item.isOtro ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: showPostalCode &&
                                        item.codigoPostal != null &&
                                        item.codigoPostal!.isNotEmpty
                                    ? Text(
                                        'CP ${item.codigoPostal}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      )
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E3A8A), size: 18)
                                    : null,
                                onTap: () => Navigator.of(ctx).pop(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
    searchCtrl.dispose();
    return result;
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      errorMaxLines: 6,
      errorStyle: const TextStyle(
        color: Color(0xFF8B3A3A),
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1B2E4B), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8B3A3A), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8B3A3A), width: 1.8),
      ),
    );
  }
}

/// Formatea montos numéricos automáticamente con separadores de miles (ej. 15,000.50)
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) {
      return const TextEditingValue();
    }
    // Solo permitir dígitos y a lo sumo un punto decimal con hasta 2 decimales
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(raw)) {
      return oldValue;
    }

    final parts = raw.split('.');
    final intPart = parts[0];
    final hasDot = parts.length > 1;
    final decPart = hasDot ? parts[1] : '';

    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final reverseIndex = intPart.length - i;
      buffer.write(intPart[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    final formatted = hasDot ? '${buffer.toString()}.$decPart' : buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Solo permite letras A-Z (convertidas a mayúsculas) y números 0-9, sin signos ni espacios
class _UpperCaseAlphanumericFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }
}
