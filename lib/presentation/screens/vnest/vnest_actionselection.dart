import 'dart:math';
import 'package:flutter/material.dart';
import 'vnest_shared_widgets.dart'; 


class VnestActionSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const VnestActionSelectionScreen({super.key, required this.exercise});

  @override
  State<VnestActionSelectionScreen> createState() =>
      _VnestActionSelectionScreenState();
}

class _VnestActionSelectionScreenState
    extends State<VnestActionSelectionScreen> {
  final background = const Color(0xFFFFF7F2);
  final orange = const Color(0xFFF48A63);
  final darkText = const Color(0xFF222222);

  late String verbo;
  late List<_WordOption> sujetos;
  late List<_WordOption> objetos;
  late Set<String> validPairs;

  String? selectedWho;
  String? selectedWhat;
  bool showExpandedInfo = false;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;

    // ── Verbo ──────────────────────────────────────────────
    final verboRaw = exercise['verbo'];
    verbo = (verboRaw is Map)
        ? (verboRaw['word'] as String? ?? '')
        : (verboRaw as String? ?? 'Acción');

    // ── Pares ──────────────────────────────────────────────
    final pares = (exercise['pares'] as List?) ?? [];

    // ── Imagenes (mapa plano de Firebase) ──────────────────
    // Estructura: { "pares_0_sujeto": { "url": "...", "word": "..." }, ... }
    final imagenes = _asMap(exercise['imagenes']);

    final seenSujetos = <String>{};
    final seenObjetos = <String>{};
    final sujetosList = <_WordOption>[];
    final objetosList = <_WordOption>[];
    final vp = <String>{};

    for (int i = 0; i < pares.length; i++) {
      final p = pares[i];
      final sujeto = p['sujeto'] as String?;
      final objeto = p['objeto'] as String?;

      if (sujeto != null && !seenSujetos.contains(sujeto)) {
        seenSujetos.add(sujeto);
        // Buscar URL: primero por clave compuesta, luego fallback por word
        final url = _getUrlFromImagenes(imagenes, i, 'sujeto') ??
            _getUrlByWord(imagenes, sujeto);
        sujetosList.add(_WordOption(word: sujeto, imageUrl: url));
      }

      if (objeto != null && !seenObjetos.contains(objeto)) {
        seenObjetos.add(objeto);
        final url = _getUrlFromImagenes(imagenes, i, 'objeto') ??
            _getUrlByWord(imagenes, objeto);
        objetosList.add(_WordOption(word: objeto, imageUrl: url));
      }

      if (sujeto != null && objeto != null) {
        vp.add('$sujeto|||$objeto');
      }
    }

    sujetos = _shuffle(sujetosList);
    objetos = _shuffle(objetosList);
    validPairs = vp;
  }

  // ── Helpers de imagen ────────────────────────────────────

  /// Busca por clave compuesta: "pares_#_sujeto" o "pares_#_objeto"
  String? _getUrlFromImagenes(
      Map<String, dynamic> imagenes, int index, String tipo) {
    final key = 'pares_${index}_$tipo';
    final entry = imagenes[key];
    if (entry is Map) return entry['url'] as String?;
    return null;
  }

  /// Fallback: recorre el mapa buscando coincidencia por 'word' o 'key'
  String? _getUrlByWord(Map<String, dynamic> imagenes, String word) {
    final normalized = word.replaceAll(' ', '_');
    // Intento directo por clave normalizada
    final direct = imagenes[normalized] ?? imagenes[word];
    if (direct is Map) return direct['url'] as String?;
    // Búsqueda por campo 'word' o 'key'
    for (final entry in imagenes.values) {
      if (entry is Map) {
        if (entry['word'] == word ||
            entry['key'] == word ||
            entry['key'] == normalized) {
          return entry['url'] as String?;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      (v is Map) ? Map<String, dynamic>.from(v) : {};

  List<T> _shuffle<T>(List<T> items) {
    final rand = Random();
    for (int i = items.length - 1; i > 0; i--) {
      int j = rand.nextInt(i + 1);
      final temp = items[i];
      items[i] = items[j];
      items[j] = temp;
    }
    return items;
  }

  // ── Lógica de navegación ────────────────────────────────

  bool get pairIsValid {
    if (selectedWho == null || selectedWhat == null) return false;
    return validPairs.contains('$selectedWho|||$selectedWhat');
  }

  void handleNext() {
    if (!pairIsValid) return;
    Navigator.pushNamed(
      context,
      '/vnest-phase2',
      arguments: {
        "who": selectedWho ?? "",
        "what": selectedWhat ?? "",
        "verbo": verbo,
        "pares": widget.exercise["pares"],
        "imagenes": widget.exercise["imagenes"],
        "oraciones": widget.exercise["oraciones"],
        "context": widget.exercise["context"],
        "id_ejercicio_general": widget.exercise["id_ejercicio_general"],
      },
    );
  }

  // ── Modal de imagen ─────────────────────────────────────

  void _showImageDialog(String word, String? imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── Imagen desde Firebase ──
                    if (imageUrl != null)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        height: 220,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: orange,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _noImagePlaceholder(),
                      )
                    else
                      _noImagePlaceholder(),
                    const SizedBox(height: 12),
                    Text(
                      _capitalize(word),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "Cerrar",
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noImagePlaceholder() => SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded,
                  color: Colors.grey.shade400, size: 48),
              const SizedBox(height: 8),
              Text(
                "Imagen no disponible",
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Build ────────────────────────────────────────────────

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
          "Elige ¿Quién y Qué?",
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Paso 1 de 5",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.2,
                  backgroundColor: Colors.grey.shade200,
                  color: orange,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),
              _buildInstructions(),
              if (showExpandedInfo) _buildExpandedInfo(),
              const SizedBox(height: 20),

              // Verbo central
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: orange,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  verbo.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Columnas ¿Quién? / ¿Qué?
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildColumnSelector(
                        title: "¿Quién?",
                        options: sujetos,
                        selectedValue: selectedWho,
                        onSelect: (s) =>
                            setState(() => selectedWho = s),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _buildColumnSelector(
                        title: "¿Qué?",
                        options: objetos,
                        selectedValue: selectedWhat,
                        onSelect: (s) =>
                            setState(() => selectedWhat = s),
                      ),
                    ),
                  ],
                ),
              ),

              // Error de combinación inválida
              if (selectedWho != null &&
                  selectedWhat != null &&
                  !pairIsValid) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.red.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Combinación inválida. Prueba con otra persona u objeto.",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Botones Anterior / Siguiente
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Anterior",
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: pairIsValid ? handleNext : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pairIsValid
                            ? orange
                            : orange.withOpacity(0.4),
                        disabledBackgroundColor:
                            orange.withOpacity(0.4),
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Siguiente",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets auxiliares ───────────────────────────────────

  Widget _buildInstructions() => Row(
        children: [
          Expanded(
            child: Text(
              "Crea una oración inicial con tu verbo!",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                setState(() => showExpandedInfo = !showExpandedInfo),
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
      );

  Widget _buildExpandedInfo() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          "Selecciona un par sujeto-objeto que tengan sentido con el verbo elegido, para formar una oración coherente. Si la combinación no tiene sentido, te lo indicaremos para que pruebes con otra opción.",
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      );

  Widget _buildColumnSelector({
    required String title,
    required List<_WordOption> options,
    required String? selectedValue,
    required Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, index) {
              final item = options[index];
              final isSelected = selectedValue == item.word;
              return _buildOptionButton(item, isSelected, onSelect);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(
    _WordOption option,
    bool isSelected,
    Function(String) onSelect,
  ) {
    return GestureDetector(
      onTap: () => onSelect(option.word),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE8DD) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? orange : Colors.grey.shade300,
            width: 1.6,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.word,
                style: TextStyle(
                  color: isSelected ? orange : Colors.black87,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            // ── Ícono de imagen con URL de Firebase ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showImageDialog(option.word, option.imageUrl),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: option.imageUrl != null
                      ? orange.withOpacity(0.7)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modelo interno: palabra + URL de imagen de Firebase
class _WordOption {
  final String word;
  final String? imageUrl;
  const _WordOption({required this.word, this.imageUrl});
}