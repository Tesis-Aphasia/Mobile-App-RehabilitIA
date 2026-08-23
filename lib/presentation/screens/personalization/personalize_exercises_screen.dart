import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/services/api_service.dart';
import '../../screens/register/register_viewmodel.dart';

class PersonalizeExercisesScreen extends StatefulWidget {
  const PersonalizeExercisesScreen({super.key});

  @override
  State<PersonalizeExercisesScreen> createState() =>
      _PersonalizeExercisesScreenState();
}

class _PersonalizeExercisesScreenState
    extends State<PersonalizeExercisesScreen> {
  // ==== Estilos base ====
  final background = const Color(0xFFFEF9F4);
  final purple = const Color(0xFF7C3AED); // morado principal
  final ApiService apiService = ApiService();

  // ==== Datos ====
  List<String> contexts = [];
  String? selectedContext;

  List<Map<String, dynamic>> verbs = [];
  List<Map<String, dynamic>> _allVerbs = [];
  String? selectedVerb; // selección única

  // ==== UI / Estado ====
  bool loading = false;
  bool isGenerating = false;
  bool canGoToExercise = false;
  String? _errorInline;
  final TextEditingController _searchCtrl = TextEditingController();
  final Duration _anim = const Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    fetchContexts();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===========================
  // 🔹 Resolver paciente (email o uid)
  // ===========================
  Future<String?> _resolvePacienteDocId({
    required String? uid,
    required String? email,
  }) async {
    final col = FirebaseFirestore.instance.collection('pacientes');

    if (email != null && email.isNotEmpty) {
      final byEmail = await col.doc(email).get();
      if (byEmail.exists) return byEmail.id;
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

  // ===========================
  // 🔹 Obtener contextos (Firestore)
  // ===========================
  Future<void> fetchContexts() async {
    setState(() {
      loading = true;
      _errorInline = null;
      canGoToExercise = false;
    });

    try {
      final snap =
          await FirebaseFirestore.instance.collection('ejercicios_VNEST').get();

      final setContexts = <String>{};
      for (final d in snap.docs) {
        final ctx = (d.data()['contexto'] ?? '').toString().trim();
        if (ctx.isNotEmpty) setContexts.add(ctx);
      }

      final list = setContexts.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() => contexts = list);
    } catch (e) {
      setState(() => _errorInline = "Error al obtener contextos: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  // ===========================
  // 🔹 Obtener verbos para un contexto (Firestore)
  // ===========================
  Future<void> fetchVerbsForContext(String ctx) async {
    setState(() {
      loading = true;
      _errorInline = null;
      verbs = [];
      _allVerbs = [];
      selectedVerb = null;
      canGoToExercise = false;
      _searchCtrl.clear();
    });

    try {
      final registerVM = Provider.of<RegisterViewModel>(context, listen: false);
      final uid = registerVM.userId;
      final email = registerVM.userEmail;

      // 1) Traer ejercicios VNEST del contexto
      final vnestSnap = await FirebaseFirestore.instance
          .collection('ejercicios_VNEST')
          .where('contexto', isEqualTo: ctx)
          .get();

      final vnestList = vnestSnap.docs.map((d) {
        final m = d.data();
        return {
          ...m,
          '_id': d.id,
          'verbo': m['verbo'],
          'id_ejercicio_general': m['id_ejercicio_general'] ?? d.id,
        };
      }).where((e) =>
          (e['verbo'] ?? '').toString().isNotEmpty && e['aprobado'] == true
      ).toList();

      // Diccionario base {verbo -> objeto}
      final Map<String, Map<String, dynamic>> verbsDict = {
        for (final ex in vnestList)
          ex['verbo']: {
            'verbo': ex['verbo'],
            'highlight': false,
            'id_ejercicio_general': ex['id_ejercicio_general'],
          }
      };

      // 2) Resolver paciente
      final pacienteDocId = await _resolvePacienteDocId(uid: uid, email: email);

      // 3) Leer asignados pendientes personalizados
      if (pacienteDocId != null) {
        final asignadosSnap = await FirebaseFirestore.instance
            .collection('pacientes')
            .doc(pacienteDocId)
            .collection('ejercicios_asignados')
            .where('tipo', isEqualTo: 'VNEST')
            .where('contexto', isEqualTo: ctx)
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
            final ids =
                {ex['_id'], ex['id_ejercicio_general']}.whereType<String>().toSet();
            if (ids.any(pendientesIds.contains)) {
              final v = (ex['verbo'] ?? '').toString();
              if (v.isNotEmpty) verbosPendientes.add(v);
            }
          }
          for (final vb in verbosPendientes) {
            if (verbsDict.containsKey(vb)) {
              verbsDict[vb]!['highlight'] = true;
            }
          }
        }
      }

      _allVerbs = verbsDict.values.toList();
      verbs = List<Map<String, dynamic>>.from(_allVerbs);
      setState(() {});
    } catch (e) {
      setState(() => _errorInline = "Error al obtener verbos: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  // ===========================
  // 🔹 Filtro buscador
  // ===========================
  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => verbs = List<Map<String, dynamic>>.from(_allVerbs));
      return;
    }
    setState(() {
      verbs = _allVerbs.where((v) {
        final verbo = (v["verbo"] ?? "").toString().toLowerCase();
        return verbo.contains(q);
      }).toList();
    });
  }

  // ===========================
  // 🔹 Generar ejercicio personalizado
  // ===========================
  Future<void> generatePersonalized() async {
    if (selectedContext == null || selectedVerb == null) {
      _showSnack("Selecciona un contexto y un verbo.");
      return;
    }

    final registerVM = Provider.of<RegisterViewModel>(context, listen: false);
    final userId = registerVM.userId;

    setState(() {
      isGenerating = true;
      _errorInline = null;
      canGoToExercise = false;
    });

    try {
      final profileSnap =
          await FirebaseFirestore.instance.collection('pacientes').doc(userId).get();
      final profileData = profileSnap.data() ?? {};

      final verboData = _allVerbs.firstWhere(
        (v) => (v["verbo"] as String) == selectedVerb,
        orElse: () => {},
      );
      final exerciseId = verboData["id_ejercicio_general"];

      if (exerciseId == null || (exerciseId is String && exerciseId.isEmpty)) {
        _showSnack("No se encontró el ejercicio para '$selectedVerb'.");
      } else {
        await apiService.post("/personalize-exercise/", {
          "user_id": userId,
          "exercise_id": exerciseId,
          "profile": profileData,
        });

        _showSnack(
            "¡Listo! Se creó el ejercicio de '$selectedVerb' en '$selectedContext'.");
        setState(() {
          canGoToExercise = true;
        });
      }
    } catch (e) {
      _showSnack("Error al personalizar: $e");
    } finally {
      setState(() => isGenerating = false);
    }
  }

  void _goToExercise() {
    if (selectedContext == null) {
      _showSnack("Falta el contexto para abrir el ejercicio.");
      return;
    }
    Navigator.pushNamed(
      context,
      '/vnest-verb',
      arguments: {'context': selectedContext},
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  // ===========================
  // 🔹 UI
  // ===========================
  @override
  Widget build(BuildContext context) {
    final canGenerate =
        !loading && !isGenerating && selectedContext != null && selectedVerb != null;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Personalizar Ejercicio",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: _BottomBar(
        background: background,
        purple: Colors.blue.shade400,
        isGenerating: isGenerating,
        canGoToExercise: canGoToExercise,
        canGenerate: canGenerate,
        onGenerate: generatePersonalized,
        onGo: _goToExercise,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle("Contexto"),
              const SizedBox(height: 8),
              if (loading && contexts.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (_errorInline != null && contexts.isEmpty)
                _InlineError(message: _errorInline!, onRetry: fetchContexts)
              else if (contexts.isEmpty)
                const _EmptyHint("No hay contextos disponibles.")
              else
                _ContextChips(
                  contexts: contexts,
                  selected: selectedContext,
                  purple: Colors.blue.shade400,
                  onTap: (ctx) {
                    setState(() => selectedContext = ctx);
                    fetchVerbsForContext(ctx);
                  },
                ),
              const SizedBox(height: 16),
              _SectionTitle("Verbo"),
              const SizedBox(height: 8),
              if (selectedContext != null)
                _SearchBox(controller: _searchCtrl, hint: "Buscar verbo…"),
              const SizedBox(height: 8),
              Expanded(child: _buildVerbsArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerbsArea() {
    if (selectedContext == null) {
      return const _EmptyHint("Elige un contexto para ver los verbos.");
    }

    if (loading && _allVerbs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorInline != null && _allVerbs.isEmpty) {
      return _InlineError(
          message: _errorInline!,
          onRetry: () => fetchVerbsForContext(selectedContext!));
    }

    if (_allVerbs.isEmpty) {
      return const _EmptyHint("No hay verbos para este contexto.");
    }

    if (verbs.isEmpty) {
      return const _EmptyHint("No se encontraron verbos con ese filtro.");
    }

    return ListView.builder(
      itemCount: verbs.length,
      itemBuilder: (context, index) {
        final verboData = verbs[index];
        final verbo = verboData["verbo"] as String;
        final highlight = verboData["highlight"] ?? false;

        return RadioListTile<String>(
          value: verbo,
          groupValue: selectedVerb,
          onChanged: (isGenerating || loading)
              ? null
              : (val) {
                  setState(() {
                    selectedVerb = val;
                    canGoToExercise = false;
                  });
                },
          activeColor: Colors.blue.shade400,
          title: Row(
            children: [
              Flexible(
                child: Text(verbo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (highlight)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.tips_and_updates, color: Colors.blue.shade400, size: 18),
                ),
            ],
          ),
          subtitle: Text(selectedContext ?? "",
              style: const TextStyle(color: Colors.black54)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Colors.white,
        );
      },
    );
  }
}

// ======== subwidgets ========

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87));
  }
}

class _ContextChips extends StatelessWidget {
  final List<String> contexts;
  final String? selected;
  final Color purple;
  final void Function(String) onTap;
  const _ContextChips(
      {required this.contexts,
      required this.selected,
      required this.purple,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: contexts.map((ctx) {
        final isSelected = selected == ctx;
        return ChoiceChip(
          label: Text(ctx,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700)),
          selected: isSelected,
          onSelected: (_) => onTap(ctx),
          selectedColor: Colors.blue.shade400,
          side:
              BorderSide(color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SearchBox({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(message, style: const TextStyle(color: Colors.black54)));
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _InlineError({required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(message,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text("Reintentar"))
      ]);
}

class _BottomBar extends StatelessWidget {
  final Color background;
  final Color purple;
  final bool isGenerating;
  final bool canGoToExercise;
  final bool canGenerate;
  final VoidCallback onGenerate;
  final VoidCallback onGo;

  const _BottomBar({
    required this.background,
    required this.purple,
    required this.isGenerating,
    required this.canGoToExercise,
    required this.canGenerate,
    required this.onGenerate,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = canGoToExercise ? true : canGenerate;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        color: background,
        child: ElevatedButton(
          onPressed: !enabled || isGenerating
              ? null
              : (canGoToExercise ? onGo : onGenerate),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade400,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.white,
            elevation: 4,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildChild(),
          ),
        ),
      ),
    );
  }

  Widget _buildChild() {
    if (isGenerating) {
      return Row(
        key: const ValueKey("loading"),
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text(
            "Generando…",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    if (canGoToExercise) {
      return Row(
        key: const ValueKey("go"),
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.play_arrow_rounded, size: 22),
          SizedBox(width: 8),
          Text(
            "Ir al ejercicio",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    return Row(
      key: const ValueKey("generate"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.auto_awesome, size: 22),
        SizedBox(width: 8),
        Text(
          "Generar ejercicio",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
