import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../register/register_viewmodel.dart';

class VnestSelectContextScreen extends StatefulWidget {
  const VnestSelectContextScreen({super.key});

  @override
  State<VnestSelectContextScreen> createState() =>
      _VnestSelectContextScreenState();
}

class _VnestSelectContextScreenState extends State<VnestSelectContextScreen> {
  // 🎨 Mismos colores que el resto de la app
  final background = const Color(0xFFFFF7F2);
  final orange = const Color(0xFFF48A63);

final Map<String, IconData> contextIcons = {
  "Educación": Icons.school_rounded,
  "Actividades domésticas": Icons.cleaning_services_rounded,
  "Trabajo": Icons.work_rounded,
  "Deportes": Icons.sports_soccer_rounded,
  "Hacer mercado": Icons.shopping_basket_rounded,
  "Ir de compras": Icons.shopping_bag_rounded,
  "Ir a un restaurante": Icons.restaurant_rounded,
  "Festividades": Icons.celebration_rounded,
  "Reunión social": Icons.groups_rounded,
  "Viajes": Icons.flight_takeoff_rounded,
  "Servicios de transporte": Icons.local_taxi_rounded,
  "Contexto libre": Icons.lightbulb_rounded,
  "Cita médica": Icons.local_hospital_rounded,
};



  String? selectedContext;
  String customContext = "";
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> contextos = [];
  bool showExpandedInfo = false;

  @override
  void initState() {
    super.initState();
    fetchContextos();
  }

  /// 🔥 Trae los contextos desde Firebase
  Future<void> fetchContextos() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final registerVM = Provider.of<RegisterViewModel>(context, listen: false);
      final email = registerVM.userEmail;
      final uid = registerVM.userId;

      // 1️⃣ Traer contextos disponibles
      final snapshot =
          await FirebaseFirestore.instance.collection('contextos').get();
      final contextosData = snapshot.docs.map((doc) {
        final d = doc.data();
        final nombre = d['contexto'] ?? d['nombre'] ?? 'Sin título';
        return {
          'id': doc.id,
          'contexto': d['contexto'] ?? d['nombre'] ?? 'Sin título',
          'icon': Icons.article_rounded,
          'highlight': false,
          'count': 0,
        };
      }).toList();

      // 2️⃣ Resolver paciente
      final pacienteDocId = await _resolvePacienteDocId(uid: uid, email: email);

      if (pacienteDocId != null) {
        // 3️⃣ Leer asignados personalizados pendientes
        final asignadosSnap = await FirebaseFirestore.instance
            .collection('pacientes')
            .doc(pacienteDocId)
            .collection('ejercicios_asignados')
            .where('tipo', isEqualTo: 'VNEST')
            .where('personalizado', isEqualTo: true)
            .where('estado', isEqualTo: 'pendiente')
            .get();

        // Agrupar por contexto y contar
        final contextCounts = <String, int>{};
        for (final doc in asignadosSnap.docs) {
          final ctx = (doc.data()['contexto'] ?? '').toString();
          if (ctx.isNotEmpty) {
            contextCounts[ctx] = (contextCounts[ctx] ?? 0) + 1;
          }
        }

        // Marcar contextos con ejercicios personalizados
        for (final c in contextosData) {
          final ctx = c['contexto'] as String;
          if (contextCounts.containsKey(ctx)) {
            c['highlight'] = true;
            c['count'] = contextCounts[ctx];
          }
        }
      }

      setState(() {
        contextos = contextosData;
      });
    } catch (e) {
      debugPrint("Error cargando contextos: $e");
      setState(() {
        error = "No se pudieron cargar los contextos.";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  // ============================
  // 🔹 Resolver doc del paciente (uid/email/campo email)
  // ============================
  Future<String?> _resolvePacienteDocId({String? uid, String? email}) async {
    final col = FirebaseFirestore.instance.collection('pacientes');

    if (email != null && email.isNotEmpty) {
      final byEmailId = await col.doc(email).get();
      if (byEmailId.exists) return byEmailId.id;
    }

    if (uid != null && uid.isNotEmpty) {
      final byUid = await col.doc(uid).get();
      if (byUid.exists) return byUid.id;
    }

    if (email != null && email.isNotEmpty) {
      final q = await col.where('email', isEqualTo: email).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first.id;
    }

    return null;
  }

  void handleNext() {
    final selected =
        selectedContext == "custom" ? customContext.trim() : selectedContext;
    if (selected == null || selected.isEmpty) return;

    Navigator.pushNamed(
      context,
      '/vnest-verb',
      arguments: {
        'context': selected,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Selecciona un contexto",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: loading
              ? _buildLoading()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInstructions(),
                    const SizedBox(height: 16),
                    if (error != null) _buildError(),
                  Expanded(
                      child: contextos.isEmpty
                          ? Center(
                              child: Text(
                                "No hay contextos disponibles por ahora.",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView(
                              children: [
                                for (var c in contextos)
                                  _buildOption(
                                    id: c['contexto'],
                                    icon: c['icon'],
                                    title: c['contexto'],
                                    highlight: c['highlight'] ?? false,
                                    count: c['count'] ?? 0,
                                  )
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    _buildNextButton(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: orange,
              strokeWidth: 4,
            ),
            const SizedBox(height: 16),
            const Text(
              "Cargando contextos…",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );

  Widget _buildInstructions() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Selecciona un contexto (situación) para empezar.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => showExpandedInfo = !showExpandedInfo),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    showExpandedInfo ? Icons.info : Icons.info_outline,
                    color: orange,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (showExpandedInfo) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                "Un contexto es una situación de la vida diaria, como estar en la cocina, el supermercado o el parque. Vamos a practicar verbos y formar oraciones en ese contexto.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      );

  Widget _buildError() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error ?? "Error cargando contextos",
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: fetchContextos,
                child: const Text(
                  "Reintentar",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildOption({
    required String id,
    required IconData icon,
    required String title,
    required bool highlight,
    required int count,
  }) {
    final isSelected = selectedContext == id;

    return InkWell(
      onTap: () => setState(() => selectedContext = id),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFE8DD)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? orange
                : highlight
                    ? const Color(0xFFFFD4C4)
                    : Colors.grey.shade300,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? orange
                    : const Color(0xFFFFE8DD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            if (highlight && count > 0)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE57348),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isEnabled =
        (selectedContext == "custom" && customContext.trim().isNotEmpty) ||
            (selectedContext != null && selectedContext != "custom");

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled && !loading ? handleNext : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          disabledBackgroundColor: orange.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(
          loading ? "Cargando…" : "Siguiente",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
