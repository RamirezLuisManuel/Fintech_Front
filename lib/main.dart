import 'package:flutter/material.dart';
import 'screens/home_shell_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initServerHost();
  // Por seguridad Fintech, al abrir la app siempre se inicia con sesión limpia (token caducado al cerrar)
  await ApiService.clearLocalSession();
  runApp(const FintechGestoPagoApp(startLoggedIn: false));
}

class FintechGestoPagoApp extends StatelessWidget {
  final bool startLoggedIn;
  const FintechGestoPagoApp({super.key, this.startLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fintech GestoPago - Ecosistema Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF0F766E),
          surface: Colors.white,
          error: const Color(0xFF991B1B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF8FAFC),
          selectedColor: const Color(0xFF0F172A),
          checkmarkColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: WidgetStateTextStyle.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF0F172A),
            );
          }),
          secondaryLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFF0F172A).withValues(alpha: 0.10),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            );
          }),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          errorMaxLines: 6,
          errorStyle: TextStyle(
            color: Color(0xFF991B1B),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: startLoggedIn ? const HomeShellScreen() : const LoginScreen(),
    );
  }
}
