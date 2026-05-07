import 'package:flutter/material.dart';

/// Pantalla de selección de modo para la terapia de Recuperación Espaciada.
/// Se navega a esta pantalla desde el menú antes de [SRExercisesScreen].
///
/// Uso en rutas:
///   '/sr' → SRModeSelectionScreen
///   '/sr-exercises' → SRExercisesScreen  (recibe arguments: {'withImages': bool})
class SRModeSelectionScreen extends StatelessWidget {
  const SRModeSelectionScreen({super.key});

  static const _background = Color(0xFFFFF7F2);
  static const _orange = Color(0xFFF48A63);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Recuperación Espaciada",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Ícono central
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE8DD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: _orange,
                  size: 48,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                "¿Cómo quieres practicar?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Elige si quieres ver imágenes de apoyo durante el ejercicio o practicar solo con texto.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Opción CON imágenes
              _ModeCard(
                icon: Icons.image_rounded,
                title: "Con imágenes",
                description:
                    "Las palabras clave mostrarán imágenes de apoyo visual al tocarlas.",
                onTap: () => Navigator.pushNamed(
                  context,
                  '/sr-exercises',
                  arguments: {'withImages': true},
                ),
              ),

              const SizedBox(height: 16),

              // Opción SIN imágenes
              _ModeCard(
                icon: Icons.text_fields_rounded,
                title: "Sin imágenes",
                description:
                    "Practica solo con el texto de las preguntas, sin apoyo visual.",
                onTap: () => Navigator.pushNamed(
                  context,
                  '/sr-exercises',
                  arguments: {'withImages': false},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tarjeta de modo
// ─────────────────────────────────────────────────────────────
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  static const _orange = Color(0xFFF48A63);

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE8DD),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _orange, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}