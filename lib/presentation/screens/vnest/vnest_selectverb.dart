import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../screens/register/register_viewmodel.dart';

class VnestSelectVerbScreen extends StatefulWidget {
  final String vnestContext;

  const VnestSelectVerbScreen({super.key, required this.vnestContext});

  @override
  State<VnestSelectVerbScreen> createState() => _VnestSelectVerbScreenState();
}

class _VnestSelectVerbScreenState extends State<VnestSelectVerbScreen> {
  // 🎨 Colores consistentes con Rehabilita
  final background = const Color(0xFFFFF7F2);
  final orange = const Color(0xFFF48A63);

  bool loading = false;
  bool loadingExercise = false;
  String? error;
  List<Map<String, dynamic>> verbs = [];
  String? selectedVerb;

  @override
  void initState() {
    super.initState();
    fetchVerbs(); // directo desde Firestore
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

  // ============================
  // 🔹 Obtener verbos + marcar highlight
  // ============================
  Future<void> fetchVerbs() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final registerVM = Provider.of<RegisterViewModel>(context, listen: false);
      final email = registerVM.userEmail;
      final uid = registerVM.userId;

      // 1️⃣ Traer ejercicios VNEST del contexto
      final vnestSnap = await FirebaseFirestore.instance
          .collection('ejercicios_VNEST')
          .where('contexto', isEqualTo: widget.vnestContext)
          .get();

      final vnestList = vnestSnap.docs.map((d) {
        final m = d.data();
        return {
          ...m,
          '_id': d.id,
          'verbo': m['verbo'],
          'id_ejercicio_general': m['id_ejercicio_general'] ?? d.id,
        };
      }).where((e) => (e['verbo'] ?? '').toString().isNotEmpty).toList();

      final Map<String, Map<String, dynamic>> verbsDict = {
        for (final ex in vnestList)
          ex['verbo']: {
            'verbo': ex['verbo'],
            'highlight': false,
            'id_ejercicio_general': ex['id_ejercicio_general'],
          }
      };

      // 2️⃣ Resolver paciente
      final pacienteDocId = await _resolvePacienteDocId(uid: uid, email: email);

      if (pacienteDocId != null) {
        // 3️⃣ Leer asignados pendientes del contexto VNEST
        final asignadosSnap = await FirebaseFirestore.instance
            .collection('pacientes')
            .doc(pacienteDocId)
            .collection('ejercicios_asignados')
            .where('tipo', isEqualTo: 'VNEST')
            .where('contexto', isEqualTo: widget.vnestContext)
            .where('personalizado', isEqualTo: true)
            .where('estado', isEqualTo: 'pendiente')
            .get();

        final pendientesIds = asignadosSnap.docs
            .map((d) => (d.data()['id_ejercicio'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet();

        if (pendientesIds.isNotEmpty) {
          final verbosPendientes = <String>{};
          for (final ex in vnestList) {
            final ids = {ex['_id'], ex['id_ejercicio_general']}
                .whereType<String>()
                .toSet();
            if (ids.any((id) => pendientesIds.contains(id))) {
              final verbo = ex['verbo'];
              if (verbo is String && verbo.isNotEmpty) {
                verbosPendientes.add(verbo);
              }
            }
          }
          for (final vb in verbosPendientes) {
            if (verbsDict.containsKey(vb)) {
              verbsDict[vb]!['highlight'] = true;
            }
          }
        }
      }

      setState(() {
        verbs = verbsDict.values.toList();
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  // ============================
  // 🔹 Obtener ejercicio directamente desde Firestore
  // ============================
  Future<void> openExercise(String verbo) async {
    setState(() {
      loadingExercise = true;
      error = null;
    });

    try {
      final registerVM = Provider.of<RegisterViewModel>(context, listen: false);
      final userId = registerVM.userId;
      final fs = FirebaseFirestore.instance;

      final pacienteRef = fs.collection("pacientes").doc(userId);
      final asignadosRef = pacienteRef.collection("ejercicios_asignados");

      // ========== Helpers ==========
      Future<bool> _isPersonalizedForVnestDoc(
          DocumentSnapshot<Map<String, dynamic>> vnDoc) async {
        final data = vnDoc.data() ?? {};
        final generalId = (data['id_ejercicio_general'] ?? '') as String;
        if (generalId.isEmpty) return (data['personalizado'] ?? false) == true;
        final base = await fs.collection('ejercicios').doc(generalId).get();
        if (!base.exists) return (data['personalizado'] ?? false) == true;
        final baseData = base.data() ?? {};
        return (baseData['personalizado'] ?? false) == true;
      }

      int _priorityOf(Map<String, dynamic> a) {
        final p = a['prioridad'];
        if (p is int) return p;
        if (p is num) return p.toInt();
        return 999999;
      }

      // 1) Buscar asignados del contexto (tipo VNEST)
      final asignadosSnap = await asignadosRef
          .where("contexto", isEqualTo: widget.vnestContext)
          .where("tipo", isEqualTo: "VNEST")
          .get();

      final asignados = <Map<String, dynamic>>[];
      for (final d in asignadosSnap.docs) {
        final m = d.data();
        final exId = (m['id_ejercicio'] ?? '').toString();
        if (exId.isEmpty) continue;
        final vnDoc = await fs.collection('ejercicios_VNEST').doc(exId).get();
        if (!vnDoc.exists) continue;
        final vn = vnDoc.data() ?? {};
        if ((vn['verbo'] ?? '') != verbo) continue;

        bool personalizado = (m['personalizado'] ?? false) == true;
        if (!personalizado) {
          personalizado = await _isPersonalizedForVnestDoc(vnDoc);
        }

        asignados.add({
          ...m,
          '_vn': vn,
          '_vnId': vnDoc.id,
          '_personalizado': personalizado,
        });
      }

      // 2) Pendientes: personalizados primero, luego prioridad asc
      final pendientes = asignados.where((e) => e['estado'] == 'pendiente').toList()
        ..sort((a, b) {
          final ap = (a['_personalizado'] == true) ? 0 : 1;
          final bp = (b['_personalizado'] == true) ? 0 : 1;
          if (ap != bp) return ap - bp;
          return _priorityOf(a).compareTo(_priorityOf(b));
        });

      if (pendientes.isNotEmpty) {
        final chosen = pendientes.first;
        final vn = Map<String, dynamic>.from(chosen['_vn'] as Map);
        final vnId = chosen['_vnId'] as String;

        Navigator.pushNamed(context, '/vnest-action', arguments: {
          ...vn,
          'context': widget.vnestContext,
          'verbo': verbo,
          'id_ejercicio_general': vn['id_ejercicio_general'] ?? vnId,
        });
        return;
      }

      // 3) Buscar VNEST del verbo en el contexto
      final allVnestSnap = await fs
          .collection('ejercicios_VNEST')
          .where('contexto', isEqualTo: widget.vnestContext)
          .where('verbo', isEqualTo: verbo)
          .get();

      if (allVnestSnap.docs.isEmpty) {
        throw Exception("No se encontró ejercicio de '$verbo' en este contexto.");
      }

      final asignadosIds =
          asignadosSnap.docs.map((d) => d.data()['id_ejercicio'].toString()).toSet();
      final noAsignadosDocs =
          allVnestSnap.docs.where((d) => !asignadosIds.contains(d.id)).toList();

      Future<List<DocumentSnapshot<Map<String, dynamic>>>> _sortPersonalizedFirst(
        List<DocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
        final withFlag = <Map<String, dynamic>>[];
        for (final d in docs) {
          withFlag.add({
            'doc': d,
            'personalizado': await _isPersonalizedForVnestDoc(d),
          });
        }
        withFlag.sort((a, b) {
          final ap = (a['personalizado'] == true) ? 0 : 1;
          final bp = (b['personalizado'] == true) ? 0 : 1;
          return ap - bp;
        });
        return withFlag
            .map((e) => e['doc'] as DocumentSnapshot<Map<String, dynamic>>)
            .toList();
      }

      // 4) Si hay no asignados → personalizados primero
      if (noAsignadosDocs.isNotEmpty) {
        final ordered = await _sortPersonalizedFirst(noAsignadosDocs);

        final chosenDoc = ordered.first;
        final chosenData = chosenDoc.data() ?? {};
        final idEjercicio = chosenDoc.id;
        final contexto = chosenData['contexto'] ?? widget.vnestContext;

        final allAsg = await asignadosRef.get();
        final prioridades = allAsg.docs
            .map((d) => d.data()['prioridad'])
            .whereType<num>()
            .map((n) => n.toInt())
            .toList();
        final nextPriority =
            prioridades.isEmpty ? 1 : (prioridades.reduce((a, b) => a > b ? a : b) + 1);

        final personalizedFlag = await _isPersonalizedForVnestDoc(chosenDoc);

        final existe = await asignadosRef.doc(idEjercicio).get();
        if (!existe.exists) {
          await asignadosRef.doc(idEjercicio).set({
            "id_ejercicio": idEjercicio,
            "contexto": contexto,
            "tipo": "VNEST",
            "estado": "pendiente",
            "prioridad": nextPriority,
            "ultima_fecha_realizado": null,
            "veces_realizado": 0,
            "fecha_asignacion": FieldValue.serverTimestamp(),
            "personalizado": personalizedFlag,
          });
        }

        Navigator.pushNamed(context, '/vnest-action', arguments: {
          ...chosenData,
          'context': widget.vnestContext,
          'verbo': verbo,
          'id_ejercicio_general':
              chosenData['id_ejercicio_general'] ?? idEjercicio,
        });
        return;
      }

      // 5) Completado más antiguo (personalizado primero)
      final completados = asignados.where((e) => e['estado'] == 'completado').toList()
        ..sort((a, b) {
          final ap = (a['_personalizado'] == true) ? 0 : 1;
          final bp = (b['_personalizado'] == true) ? 0 : 1;
          if (ap != bp) return ap - bp;
          final ta = a['ultima_fecha_realizado'];
          final tb = b['ultima_fecha_realizado'];
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return (ta as Timestamp).compareTo(tb as Timestamp);
        });

      if (completados.isNotEmpty) {
        final old = completados.first;
        final oldId = (old['id_ejercicio'] ?? '').toString();
        final oldVnDoc = await fs.collection('ejercicios_VNEST').doc(oldId).get();
        if (oldVnDoc.exists) {
          final vn = oldVnDoc.data() ?? {};
          Navigator.pushNamed(context, '/vnest-action', arguments: {
            ...vn,
            'context': widget.vnestContext,
            'verbo': verbo,
            'id_ejercicio_general':
                vn['id_ejercicio_general'] ?? oldVnDoc.id,
          });
          return;
        }
      }

      // 6) Fallback
      final fallback = allVnestSnap.docs.first;
      final fb = fallback.data() ?? {};
      Navigator.pushNamed(context, '/vnest-action', arguments: {
        ...fb,
        'context': widget.vnestContext,
        'verbo': verbo,
        'id_ejercicio_general': fb['id_ejercicio_general'] ?? fallback.id,
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loadingExercise = false);
    }
  }

  // ============================
  // 🔹 INTERFAZ
  // ============================
  @override
  Widget build(BuildContext context) {
    final isLoading = loading || loadingExercise;
    final loadingText = loading
        ? "Cargando verbos…"
        : (loadingExercise ? "Abriendo ejercicio…" : "");

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
          "Selecciona un verbo",
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
          child: isLoading
              ? _buildLoading(loadingText)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Contexto: ${widget.vnestContext}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Elige un verbo para practicar oraciones con la terapia VNeST.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (error != null) _buildError(),
                    Expanded(
                      child: verbs.isEmpty
                          ? Center(
                              child: Text(
                                "No hay verbos disponibles para este contexto.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: verbs.length,
                              itemBuilder: (context, index) =>
                                  _buildVerbOption(verbs[index]),
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

  Widget _buildLoading(String text) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: orange,
              strokeWidth: 4,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(
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
              error ?? "Error cargando verbos",
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
                onPressed: fetchVerbs,
                child: const Text(
                  "Reintentar",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );

  // ============================
  // 🔹 OPCIÓN DE VERBO
  // ============================
  Widget _buildVerbOption(Map<String, dynamic> verbData) {
    final verbo = (verbData["verbo"] ?? "").toString();
    final highlight = (verbData["highlight"] ?? false) == true;
    final isSelected = selectedVerb == verbo;

    return InkWell(
      onTap: () => setState(() => selectedVerb = verbo),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFE8DD)
              : highlight
                  ? const Color(0xFFFFF4D2)
                  : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? orange
                : highlight
                    ? Colors.amber
                    : Colors.grey.shade300,
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
                color: highlight
                    ? Colors.amber.withOpacity(0.15)
                    : const Color(0xFFFFE8DD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                highlight ? Icons.lightbulb_rounded : Icons.play_arrow_rounded,
                color: highlight ? Colors.amber.shade700 : orange,
                size: highlight ? 26 : 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                verbo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color:
                      highlight ? Colors.amber.shade800 : Colors.black87,
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

  // ============================
  // 🔹 BOTÓN SIGUIENTE
  // ============================
  Widget _buildNextButton() {
    final isEnabled = selectedVerb != null && selectedVerb!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled && !loadingExercise
            ? () async {
                if (selectedVerb != null) {
                  await openExercise(selectedVerb!);
                }
              }
            : null,
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
          loadingExercise ? "Cargando…" : "Siguiente",
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
