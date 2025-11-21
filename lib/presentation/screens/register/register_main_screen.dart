import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'register_viewmodel.dart';

class RegisterMainScreen extends StatefulWidget {
  final bool showSuccess;
  const RegisterMainScreen({super.key, this.showSuccess = false});

  @override
  State<RegisterMainScreen> createState() => _RegisterMainScreenState();
}

class _RegisterMainScreenState extends State<RegisterMainScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // ---------------- LOGO (80px) ----------------
              Image.asset(
                'assets/icons/brain_logo.png',
                height: 80,
              ),

              const SizedBox(height: 24),

              Expanded(
                child: widget.showSuccess
                    ? _buildSuccessContent(context)
                    : _buildIntroContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================
  //                   REGISTRO (INTRO)
  // ===========================================================
  Widget _buildIntroContent(BuildContext context) {
    final registerVM = Provider.of<RegisterViewModel>(context, listen: false);
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Registro de paciente',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'Completa tu correo y contraseña para continuar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 40),

        // ---------------- CAMPO EMAIL ----------------
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            hintText: 'ejemplo@correo.com',
            filled: true,
            fillColor: const Color(0xFFE8EBF3),
            labelStyle: TextStyle(color: Colors.grey.shade700),
            hintStyle: TextStyle(color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ---------------- CAMPO CONTRASEÑA ----------------
        TextField(
          controller: _passwordCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            hintText: 'Mínimo 6 caracteres',
            filled: true,
            fillColor: const Color(0xFFE8EBF3),
            labelStyle: TextStyle(color: Colors.grey.shade700),
            hintStyle: TextStyle(color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFFF48A63),
              ),
              onPressed: () {
                setState(() => _showPassword = !_showPassword);
              },
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ---------------- BOTÓN CONTINUAR ----------------
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final email = _emailCtrl.text.trim();
              final password = _passwordCtrl.text.trim();

              if (email.isEmpty || !emailRegex.hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor ingresa un correo válido.')),
                );
                return;
              }
              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
                );
                return;
              }

              registerVM.setAuthData(email: email, password: password);
              Navigator.pushNamed(context, '/register-personal');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF48A63),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continuar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ---------------- BOTÓN CANCELAR ----------------
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              color: Color(0xFFF48A63),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================
  //                REGISTRO EXITOSO
  // ===========================================================
  Widget _buildSuccessContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EBF3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFFF48A63),
            size: 60,
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          '¡Registro completado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Tu cuenta ha sido creada con éxito.\nYa puedes comenzar tus ejercicios.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/menu');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF48A63),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Ir a ejercicios',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
