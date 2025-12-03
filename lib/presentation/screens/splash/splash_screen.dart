import 'package:flutter/material.dart';
import 'package:aphasia_mobile/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../register/register_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    debugPrint('🟢 [Splash] Iniciando _checkLogin');

    bool isLogged;
    try {
      isLogged = await _authService.isUserLoggedIn();
    } catch (e) {
      debugPrint('❌ [Splash] Error en isUserLoggedIn: $e');
      isLogged = false;
    }

    debugPrint('🟢 [Splash] isLogged = $isLogged');
    debugPrint('🟢 [Splash] FirebaseAuth.currentUser = ${FirebaseAuth.instance.currentUser}');

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (isLogged && FirebaseAuth.instance.currentUser != null) {
      // Recuperar datos del usuario
      final userId = await _authService.getUserId();
      final email = await _authService.getUserEmail();

      debugPrint('🟢 [Splash] userId desde prefs: $userId');
      debugPrint('🟢 [Splash] email desde prefs: $email');

      if (userId == null || email == null) {
        debugPrint('⚠️ [Splash] userId o email nulos, mandando a /login');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final registerVM = Provider.of<RegisterViewModel>(context, listen: false);
      registerVM.userId = userId;
      registerVM.userEmail = email;

      debugPrint('🟢 [Splash] Navegando a /menu');
      Navigator.pushNamedAndRemoveUntil(context, '/menu', (route) => false);

    } else {
      debugPrint('🟡 [Splash] No logueado, navegando a /login');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
