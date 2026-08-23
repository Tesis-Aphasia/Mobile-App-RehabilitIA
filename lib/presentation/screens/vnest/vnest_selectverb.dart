import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../screens/register/register_viewmodel.dart';
import 'vnest_shared_widgets.dart';

// ===========================================================
//  VnestSelectVerbScreen
//
//  Las imágenes se cargan desde URLs de Firebase Storage
//  almacenadas en el campo "imagenes.verbo.url" del documento
//  ejercicios_VNEST. No se usan assets locales.
// ===========================================================

class VnestSelectVerbScreen extends StatefulWidget {
  final String vnestContext;

  const VnestSelectVerbScreen({super.key, required this.vnestContext});

  @override
  State<VnestSelectVerbScreen> createState() => _VnestSelectVerbScreenState();
}

class _VnestSelectVerbScreenState extends State<VnestSelectVerbScreen> {
  final background = const Color(0xFFFFF7F2);
  final orange = const Color(0xFFF48A63);

  bool loading = false;
  bool loadingExercise = false;
  String? error;

  /// Cada entrada: { verbo, highlight, count, id_ejercicio_general, imageUrl? }
  List<Map<String, dynamic>> verbs = [];
  String? selectedVerb;
  bool showExpandedInfo = false;

  @override
  void initState() {
    super.initState();
    fetchVerbs();
  }

  Future<String?> _resolvePacienteDocId(
      {String? uid, String? email}) async {
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
      final q =
          await col.where('email', isEqualTo: email).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first.id;
    }
    return null;
  }

  Future<bool> _isEjercicioRevisado(String? idEjercicioGeneral) async {
  if (idEjercicioGeneral == null || idEjercicioGeneral.isEmpty) return false;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('ejercicios')
        .doc(idEjercicioGeneral)
        .get();
    if (!doc.exists) return false;
    return (doc.data()?['aprobado'] ?? false) == true; // ← cambiar 'revisado' por 'aprobado'
  } catch (_) {
    return false;
  }
}

  // ============================
  // 🔹 Extrae la URL de imagen del verbo desde el campo "imagenes"
  //    Firestore: imagenes.verbo.url
  // ============================
  String? _extractVerbImageUrl(Map<String, dynamic> ejercicioData) {
    final imagenes = ejercicioData['imagenes'];
    if (imagenes == null || imagenes is! Map) return null;

    final verboEntry = imagenes['verbo'];
    if (verboEntry == null || verboEntry is! Map) return null;

    final url = verboEntry['url']?.toString();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  Future<void> fetchVerbs() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final registerVM =
          Provider.of<RegisterViewModel>(context, listen: false);
      final email = registerVM.userEmail;
      final uid = registerVM.userId;

      final vnestSnap = await FirebaseFirestore.instance
          .collection('ejercicios_VNEST')
          .where('contexto', isEqualTo: widget.vnestContext)
          .get();

      final allVnestList = vnestSnap.docs.map((d) {
        final m = d.data();
        return {
          ...m,
          '_id': d.id,
          'verbo': m['verbo'],
          'id_ejercicio_general': m['id_ejercicio_general'] ?? d.id,
        };
      }).where((e) => (e['verbo'] ?? '').toString().isNotEmpty).toList();

      // Filtrar solo revisados
      final vnestList = <Map<String, dynamic>>[];
      for (final ex in allVnestList) {
        final isRevisado = await _isEjercicioRevisado(
          ex['id_ejercicio_general']?.toString(),
        );
        if (isRevisado) vnestList.add(ex);
      }

      // Construir dict de verbos con URL de imagen desde Firebase
      final Map<String, Map<String, dynamic>> verbsDict = {};
      for (final ex in vnestList) {
        // El campo "verbo" puede ser String o Map {word, key, url}
        final verboRaw = ex['verbo'];
        final String verboWord;
        String? imageUrl;

        if (verboRaw is Map) {
          verboWord = verboRaw['word']?.toString() ?? '';
          imageUrl = verboRaw['url']?.toString();
        } else {
          verboWord = verboRaw?.toString() ?? '';
          // Intentar extraer URL desde imagenes.verbo
          imageUrl = _extractVerbImageUrl(ex);
        }

        if (verboWord.isEmpty) continue;

        if (!verbsDict.containsKey(verboWord)) {
          verbsDict[verboWord] = {
            'verbo': verboWord,
            'highlight': false,
            'count': 0,
            'id_ejercicio_general': ex['id_ejercicio_general'],
            'imageUrl': imageUrl, // ← URL de Firebase Storage
          };
        }
      }

      // Marcar highlights con ejercicios asignados personalizados
      final pacienteDocId =
          await _resolvePacienteDocId(uid: uid, email: email);

      if (pacienteDocId != null) {
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
          final verbosPendientesCount = <String, int>{};
          for (final ex in vnestList) {
            final ids = {ex['_id'], ex['id_ejercicio_general']}
                .whereType<String>()
                .toSet();
            if (ids.any((id) => pendientesIds.contains(id))) {
              final verboRaw = ex['verbo'];
              final v = verboRaw is Map
                  ? verboRaw['word']?.toString()
                  : verboRaw?.toString();
              if (v != null && v.isNotEmpty) {
                verbosPendientesCount[v] =
                    (verbosPendientesCount[v] ?? 0) + 1;
              }
            }
          }
          for (final vb in verbosPendientesCount.keys) {
            if (verbsDict.containsKey(vb)) {
              verbsDict[vb]!['highlight'] = true;
              verbsDict[vb]!['count'] = verbosPendientesCount[vb];
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
  // 🔹 Diálogo imagen desde URL de Firebase Storage
  // ============================
  void _showVerbImage(BuildContext context, String imageUrl) {
    showNetworkImageDialog(context, imageUrl);
  }

  // ============================
  // 🔹 Abrir ejercicio
  // ============================
  Future<void> openExercise(String verbo) async {
    setState(() {
      loadingExercise = true;
      error = null;
    });

    try {
      final registerVM =
          Provider.of<RegisterViewModel>(context, listen: false);
      final userId = registerVM.userId;
      final fs = FirebaseFirestore.instance;

      final pacienteRef = fs.collection("pacientes").doc(userId);
      final asignadosRef = pacienteRef.collection("ejercicios_asignados");

      Future<bool> isPersonalizedForVnestDoc(
          DocumentSnapshot<Map<String, dynamic>> vnDoc) async {
        final data = vnDoc.data() ?? {};
        final generalId = (data['id_ejercicio_general'] ?? '') as String;
        if (generalId.isEmpty) {
          return (data['personalizado'] ?? false) == true;
        }
        final base =
            await fs.collection('ejercicios').doc(generalId).get();
        if (!base.exists) return (data['personalizado'] ?? false) == true;
        return (base.data()?['personalizado'] ?? false) == true;
      }

      int priorityOf(Map<String, dynamic> a) {
        final p = a['prioridad'];
        if (p is int) return p;
        if (p is num) return p.toInt();
        return 999999;
      }

      // Normaliza el verbo para comparar (soporta String y Map)
      String _extractVerboWord(dynamic verboRaw) {
        if (verboRaw is Map) return verboRaw['word']?.toString() ?? '';
        return verboRaw?.toString() ?? '';
      }

      final asignadosSnap = await asignadosRef
          .where("contexto", isEqualTo: widget.vnestContext)
          .where("tipo", isEqualTo: "VNEST")
          .get();

      final asignados = <Map<String, dynamic>>[];
      for (final d in asignadosSnap.docs) {
        final m = d.data();
        final exId = (m['id_ejercicio'] ?? '').toString();
        if (exId.isEmpty) continue;
        final vnDoc =
            await fs.collection('ejercicios_VNEST').doc(exId).get();
        if (!vnDoc.exists) continue;
        final vn = vnDoc.data() ?? {};
        if (_extractVerboWord(vn['verbo']) != verbo) continue;

        final idEjercicioGeneral =
            vn['id_ejercicio_general']?.toString();
        final isRevisado =
            await _isEjercicioRevisado(idEjercicioGeneral);
        if (!isRevisado) continue;

        bool personalizado = (m['personalizado'] ?? false) == true;
        if (!personalizado) {
          personalizado = await isPersonalizedForVnestDoc(vnDoc);
        }

        asignados.add({
          ...m,
          '_vn': vn,
          '_vnId': vnDoc.id,
          '_personalizado': personalizado,
        });
      }

      final pendientes =
          asignados.where((e) => e['estado'] == 'pendiente').toList()
            ..sort((a, b) {
              final ap = (a['_personalizado'] == true) ? 0 : 1;
              final bp = (b['_personalizado'] == true) ? 0 : 1;
              if (ap != bp) return ap - bp;
              return priorityOf(a).compareTo(priorityOf(b));
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

      final allVnestSnap = await fs
          .collection('ejercicios_VNEST')
          .where('contexto', isEqualTo: widget.vnestContext)
          .get();

      // Filtra por verbo soportando Map y String
      final vnestPorVerbo = allVnestSnap.docs.where((doc) {
        final data = doc.data();
        final vRaw = data['verbo'];
        final vWord = vRaw is Map
            ? vRaw['word']?.toString() ?? ''
            : vRaw?.toString() ?? '';
        return vWord == verbo;
      }).toList();

      final vnestRevisadosDocs =
          <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in vnestPorVerbo) {
        final data = doc.data();
        final idEjercicioGeneral =
            data['id_ejercicio_general']?.toString();
        final isRevisado =
            await _isEjercicioRevisado(idEjercicioGeneral);
        if (isRevisado) vnestRevisadosDocs.add(doc);
      }

      if (vnestRevisadosDocs.isEmpty) {
        throw Exception(
            "No se encontró ejercicio revisado de '$verbo' en este contexto.");
      }

      final asignadosIds = asignadosSnap.docs
          .map((d) => d.data()['id_ejercicio'].toString())
          .toSet();
      final noAsignadosDocs = vnestRevisadosDocs
          .where((d) => !asignadosIds.contains(d.id))
          .toList();

      Future<List<DocumentSnapshot<Map<String, dynamic>>>>
          sortPersonalizedFirst(
        List<DocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
        final withFlag = <Map<String, dynamic>>[];
        for (final d in docs) {
          withFlag.add({
            'doc': d,
            'personalizado': await isPersonalizedForVnestDoc(d),
          });
        }
        withFlag.sort((a, b) {
          final ap = (a['personalizado'] == true) ? 0 : 1;
          final bp = (b['personalizado'] == true) ? 0 : 1;
          return ap - bp;
        });
        return withFlag
            .map((e) =>
                e['doc'] as DocumentSnapshot<Map<String, dynamic>>)
            .toList();
      }

      if (noAsignadosDocs.isNotEmpty) {
        final ordered = await sortPersonalizedFirst(noAsignadosDocs);
        final chosenDoc = ordered.first;
        final chosenData = chosenDoc.data() ?? {};
        final idEjercicio = chosenDoc.id;
        final contexto =
            chosenData['contexto'] ?? widget.vnestContext;

        final allAsg = await asignadosRef.get();
        final prioridades = allAsg.docs
            .map((d) => d.data()['prioridad'])
            .whereType<num>()
            .map((n) => n.toInt())
            .toList();
        final nextPriority = prioridades.isEmpty
            ? 1
            : (prioridades.reduce((a, b) => a > b ? a : b) + 1);

        final personalizedFlag =
            await isPersonalizedForVnestDoc(chosenDoc);
        final existe =
            await asignadosRef.doc(idEjercicio).get();
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

      final completados =
          asignados.where((e) => e['estado'] == 'completado').toList()
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
        final oldVnDoc =
            await fs.collection('ejercicios_VNEST').doc(oldId).get();
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

      final fallback = vnestRevisadosDocs.first;
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
    final verbsWithImage = verbs
    .where((v) => v['imageUrl'] != null && v['imageUrl'].toString().isNotEmpty)
    .toList();

    final verbsWithoutImage = verbs
    .where((v) => v['imageUrl'] == null || v['imageUrl'].toString().isEmpty)
    .toList();

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
                    _buildInstructions(),
                    const SizedBox(height: 20),
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
                          : ListView(
                            children: [
                              // 🔹 Sección con imagen
                              if (verbsWithImage.isNotEmpty) ...[
                                _buildSectionTitle("🖼️ Verbos con imagen"),
                                ...verbsWithImage.map((v) => _buildVerbOption(v)).toList(),
                              ],

                              // 🔹 Sección sin imagen
                              if (verbsWithoutImage.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildSectionTitle("🔤 Verbos sin imagen"),
                                ...verbsWithoutImage.map((v) => _buildVerbOption(v)).toList(),
                              ],
                            ],
                          )
                            
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
            CircularProgressIndicator(color: orange, strokeWidth: 4),
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

  Widget _buildInstructions() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Contexto: ",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                widget.vnestContext,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Elige un verbo (acción) para formar oraciones.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(
                    () => showExpandedInfo = !showExpandedInfo),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Vamos a formar oraciones completas usando este verbo. Por ejemplo, con el verbo COCINAR podemos construir: \"La mamá cocina pasta en la cocina\".",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  if (_hasPersonalizedExercises()) ...[
                    const SizedBox(height: 10),
                    Divider(color: Colors.grey.shade300, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE57348),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              "!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Ejercicios personalizados para ti",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );

  bool _hasPersonalizedExercises() =>
      verbs.any((v) => v['highlight'] == true && v['count'] > 0);

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
                  color: Colors.red, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: fetchVerbs,
                child: const Text("Reintentar",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );

  Widget _buildVerbOption(Map<String, dynamic> verbData) {
    final verbo = (verbData["verbo"] ?? "").toString();
    final highlight = (verbData["highlight"] ?? false) == true;
    final count = (verbData["count"] ?? 0) as int;
    final isSelected = selectedVerb == verbo;
    final imageUrl = verbData["imageUrl"] as String?;

    return InkWell(
      onTap: () => setState(() => selectedVerb = verbo),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE8DD) : Colors.white,
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
                color: highlight
                    ? const Color(0xFFFFF0EB)
                    : const Color(0xFFFFE8DD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                highlight
                    ? Icons.lightbulb_rounded
                    : Icons.play_arrow_rounded,
                color: orange,
                size: highlight ? 24 : 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      verbo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // Botón imagen: visible solo si hay URL de Firebase
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          _showVerbImage(context, imageUrl),
                    ),
                ],
              ),
            ),
            if (highlight && count > 0)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFE57348),
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

  Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    ),
  );
}

  Widget _buildNextButton() {
    final isEnabled =
        selectedVerb != null && selectedVerb!.isNotEmpty;

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