import 'package:flutter/material.dart';
import 'screens/home_shell_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initServerHost();
  final hasSession = await ApiService.hasActiveLocalSession();
  runApp(FintechGestoPagoApp(startLoggedIn: hasSession));
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
          seedColor: const Color(0xFF1E3A8A),
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF0F766E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: startLoggedIn ? const HomeShellScreen() : const LoginScreen(),
    );
  }
}
