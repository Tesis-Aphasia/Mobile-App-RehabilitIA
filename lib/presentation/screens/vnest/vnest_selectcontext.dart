import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  String? selectedContext;
  String customContext = "";
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> contextos = [];

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
      final snapshot =
          await FirebaseFirestore.instance.collection('contextos').get();
      final data = snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'contexto': d['contexto'] ?? d['nombre'] ?? 'Sin título',
          'icon': Icons.article_rounded, // ícono por defecto
        };
      }).toList();

      setState(() {
        contextos = data;
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
                    // Descripción suave arriba
                    Text(
                      "Elige un contexto para practicar!",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
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
  }) {
    final isSelected = selectedContext == id;

    return InkWell(
      onTap: () => setState(() => selectedContext = id),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE8DD) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? orange : Colors.grey.shade300,
            width: 1.5,
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
                    : const Color(0xFFFFE8DD), // pastel
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
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? orange : Colors.grey.shade400,
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
