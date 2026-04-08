import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../register/register_viewmodel.dart';

class SRExercisesScreen extends StatefulWidget {
  const SRExercisesScreen({super.key});

  @override
  State<SRExercisesScreen> createState() => _SRExercisesScreenState();
}

class _SRExercisesScreenState extends State<SRExercisesScreen> {
  final background = const Color(0xFFFFF7F2);
  final orange = const Color(0xFFF48A63);

  bool loading = true;
  List<Map<String, dynamic>> cards = [];
  Map<String, dynamic>? currentCard;
  Map<String, dynamic>? cardState;
  String mode = "question";
  String feedback = "";
  int secondsLeft = 0;
  TextEditingController answerCtrl = TextEditingController();
  Timer? timer;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String recognizedText = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    Future.microtask(() async {
      await _initSpeech();
      await _loadCards();
    });
  }

  // ── Normalización ────────────────────────────────────────────

  String _normalizeToken(String s) {
    var v = s.toLowerCase().trim();
    for (final pair in [
      ['á', 'a'], ['é', 'e'], ['í', 'i'], ['ó', 'o'], ['ú', 'u'], ['ñ', 'n']
    ]) {
      v = v.replaceAll(pair[0], pair[1]);
    }
    return v.replaceAll(RegExp(r'[^a-z]'), '');
  }

  // ── Helpers de imagen ────────────────────────────────────────

  String? _getRtaImageUrl() {
    final imagenes = currentCard?["imagenes"];
    if (imagenes == null || imagenes is! Map) return null;
    for (final key in imagenes.keys) {
      if (key.toString().endsWith("_rta")) {
        return imagenes[key]?["url"] as String?;
      }
    }
    return null;
  }

  /// Abre modal popup con la imagen — igual que _ClickableWord
  void _showHintModal(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20)
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      size: 60,
                      color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Toca para cerrar",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón de pista reutilizable
  Widget _buildHintButton(String imageUrl) {
    return GestureDetector(
      onTap: () => _showHintModal(context, imageUrl),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: orange.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("💡", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              "Ver pista",
              style: TextStyle(
                  color: orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String url, {double size = 130}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        height: size,
        width: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: size,
            width: size,
            child: Center(
              child: CircularProgressIndicator(
                color: orange,
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Map<String, String> _buildTokenUrlMap(String pregunta) {
    final imagenes = currentCard?["imagenes"];
    if (imagenes == null || imagenes is! Map) return {};

    final Map<String, String> tokenToUrl = {};
    final preguntaTokens = pregunta.split(' ');

    for (final entry in (imagenes as Map).entries) {
      final url = entry.value?["url"] as String?;
      final word = entry.value?["word"] as String?;
      if (url == null || word == null) continue;

      final wordTokens = word
          .toLowerCase()
          .split(' ')
          .map(_normalizeToken)
          .where((t) => t.length > 2)
          .toList();

      for (final rawPregToken in preguntaTokens) {
        final pregToken = _normalizeToken(rawPregToken);
        if (pregToken.length <= 2) continue;

        for (final wt in wordTokens) {
          final root = wt.length >= 3 ? wt.substring(0, 3) : wt;
          if (pregToken == wt || pregToken.startsWith(root)) {
            tokenToUrl[pregToken] = url;
            break;
          }
        }
      }
    }

    return tokenToUrl;
  }

  Widget _buildClickablePregunta(String pregunta) {
    final tokenToUrl = _buildTokenUrlMap(pregunta);

    if (tokenToUrl.isEmpty) {
      return Text(
        pregunta,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87),
      );
    }

    final words = pregunta.split(' ');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < words.length; i++) {
      final rawWord = words[i];
      final cleanToken = _normalizeToken(rawWord);
      final imageUrl = tokenToUrl[cleanToken];

      if (imageUrl != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _ClickableWord(
            word: rawWord,
            imageUrl: imageUrl,
            orange: orange,
          ),
        ));
        if (i < words.length - 1) {
          spans.add(
              const TextSpan(text: ' ', style: TextStyle(fontSize: 22)));
        }
      } else {
        spans.add(TextSpan(
          text: i < words.length - 1 ? '$rawWord ' : rawWord,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87),
        ));
      }
    }

    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }

  // ── Voz ─────────────────────────────────────────────────────

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      await _speech.initialize();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Por favor habilita el micrófono para usar voz.")),
        );
      }
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        localeId: 'es_ES',
        onResult: (result) {
          setState(() {
            recognizedText = result.recognizedWords;
            answerCtrl.text = recognizedText;
          });
        },
      );
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  // ── Cargar tarjetas ──────────────────────────────────────────

  Future<void> _loadCards() async {
    final userId =
        Provider.of<RegisterViewModel>(context, listen: false).userId;
    if (userId == null || userId.isEmpty) {
      setState(() => loading = false);
      return;
    }

    try {
      final asignadosSnap = await FirebaseFirestore.instance
          .collection("pacientes")
          .doc(userId)
          .collection("ejercicios_asignados")
          .get();

      final idsAsignados = asignadosSnap.docs
          .where((d) {
            final estado =
                d.data()["estado"]?.toString() ?? "pendiente";
            return estado != "completado";
          })
          .map((d) => d.data()["id_ejercicio"] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toList();

      if (idsAsignados.isEmpty) {
        setState(() => loading = false);
        return;
      }

      final ejerciciosSnap = await FirebaseFirestore.instance
          .collection("ejercicios_SR")
          .where("id_ejercicio_general", whereIn: idsAsignados)
          .where("aprobado", isEqualTo: true)
          .get();

      final data = ejerciciosSnap.docs
          .map((d) => {"id": d.id, ...d.data()})
          .toList()
          .cast<Map<String, dynamic>>();

      if (data.isEmpty) {
        setState(() => loading = false);
        return;
      }

      setState(() {
        cards = data;
        currentCard = data.first;
        cardState = {
          ...data.first,
          "interval_index": 0,
          "success_streak": 0,
          "lapses": 0,
          "last_answer_correct": null,
        };
        loading = false;
      });
    } catch (e) {
      debugPrint("Error cargando ejercicios SR: $e");
      setState(() => loading = false);
    }
  }

  // ── Lógica ───────────────────────────────────────────────────

  void handleSubmit() async {
    if (currentCard == null || cardState == null) return;

    final userAns = answerCtrl.text.trim().toLowerCase();
    final correctAns =
        (currentCard!["rta_correcta"] ?? "").trim().toLowerCase();
    final isCorrect = userAns == correctAns;

    answerCtrl.clear();
    recognizedText = "";

    final intervals = List<int>.from(
        currentCard!["intervals_sec"] ?? [15, 30, 60, 120, 240]);
    final nextIndex = isCorrect
        ? (cardState!["interval_index"] + 1)
            .clamp(0, intervals.length - 1)
        : 0;

    setState(() {
      cardState = {
        ...cardState!,
        "interval_index": nextIndex,
        "success_streak":
            isCorrect ? (cardState!["success_streak"] + 1) : 0,
        "lapses": isCorrect
            ? cardState!["lapses"]
            : (cardState!["lapses"] + 1),
        "last_answer_correct": isCorrect,
        "next_due": DateTime.now().millisecondsSinceEpoch +
            intervals[nextIndex] * 1000,
      };
      secondsLeft = intervals[nextIndex];
      // Solo feedback de correcto/incorrecto, sin revelar la respuesta
      feedback = isCorrect ? "✅ ¡Correcto!" : "❌ Inténtalo de nuevo";
      mode = "timer";
    });

    _startCountdown();
  }

  void _startCountdown() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 1) {
        t.cancel();
        onTimerFinished();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void onTimerFinished() {
    final intervals = List<int>.from(currentCard!["intervals_sec"]);
    if (cardState!["interval_index"] >= intervals.length - 1 &&
        cardState!["last_answer_correct"] == true) {
      setState(() => mode = "doneCard");
      return;
    }
    setState(() {
      mode = "question";
      feedback = "";
    });
  }

  Future<void> _markExerciseAsCompleted() async {
    if (currentCard == null) return;
    final userId =
        Provider.of<RegisterViewModel>(context, listen: false).userId;
    if (userId == null || userId.isEmpty) return;

    try {
      final idEjercicioGeneral = currentCard!["id_ejercicio_general"];
      if (idEjercicioGeneral == null ||
          idEjercicioGeneral.toString().isEmpty) return;

      final query = await FirebaseFirestore.instance
          .collection("pacientes")
          .doc(userId)
          .collection("ejercicios_asignados")
          .where("id_ejercicio",
              isEqualTo: idEjercicioGeneral.toString())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          "estado": "completado",
          "ultima_fecha_realizado": FieldValue.serverTimestamp(),
          "veces_realizado": FieldValue.increment(1),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Ejercicio guardado como completado"),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Error al guardar el ejercicio"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void handleNextCard() async {
    if (currentCard == null) return;
    await _markExerciseAsCompleted();
    final currentIndex =
        cards.indexWhere((c) => c["id"] == currentCard!["id"]);
    final nextIndex = (currentIndex + 1) % cards.length;
    setState(() {
      currentCard = cards[nextIndex];
      cardState = {
        ...cards[nextIndex],
        "interval_index": 0,
        "success_streak": 0,
        "lapses": 0,
        "last_answer_correct": null,
      };
      mode = "question";
      feedback = "";
      secondsLeft = 0;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    answerCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: orange)),
      );
    }

    if (cards.isEmpty) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: orange),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 80, color: Colors.green.shade400),
                const SizedBox(height: 20),
                const Text("¡Todo completado! 🎉",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87)),
                const SizedBox(height: 12),
                Text(
                  "No tienes ejercicios de memoria pendientes.\n\nSi tu terapeuta te asigna nuevos, los verás aquí.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text("Volver al menú",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final intervals = List<int>.from(
        currentCard!["intervals_sec"] ?? [15, 30, 60, 120, 240]);
    final intervalLabel = mode == "timer"
        ? "Intervalo actual: ${intervals[cardState!["interval_index"]]} s"
        : "Próximo intervalo: ${intervals[(cardState!["interval_index"] + 1).clamp(0, intervals.length - 1)]} s";

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Recuperación Espaciada",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(intervalLabel,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildCardContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    if (mode == "question") return _buildQuestionMode();
    if (mode == "timer") return _buildTimerMode();
    return _buildDoneCard();
  }

  // ── Modo pregunta ────────────────────────────────────────────

  Widget _buildQuestionMode() {
    final pregunta = currentCard!["pregunta"] ?? "";
    final rtaUrl = _getRtaImageUrl();

    return SingleChildScrollView(
      key: const ValueKey("question"),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildClickablePregunta(pregunta),
          const SizedBox(height: 22),

          TextField(
            controller: answerCtrl,
            decoration: InputDecoration(
              hintText: "Escribe o di tu respuesta...",
              filled: true,
              fillColor: const Color(0xFFFFE8DD),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening
                      ? Icons.stop_rounded
                      : Icons.mic_none_rounded,
                  color: _isListening
                      ? Colors.red
                      : Colors.grey.shade700,
                ),
                onPressed: () =>
                    _isListening ? _stopListening() : _startListening(),
              ),
            ),
          ),
          const SizedBox(height: 18),

          ElevatedButton(
            onPressed: handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              elevation: 0,
            ),
            child: const Text("Enviar",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),

          // Botón pista en modo pregunta
          if (rtaUrl != null) ...[
            const SizedBox(height: 14),
            _buildHintButton(rtaUrl),
          ],

          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(feedback,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: feedback.startsWith("✅")
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ],
      ),
    );
  }

  // ── Modo timer ───────────────────────────────────────────────

  Widget _buildTimerMode() {
    final rtaUrl = _getRtaImageUrl();
    final isCorrect = feedback.startsWith("✅");

    return Column(
      key: const ValueKey("timer"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(feedback,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: isCorrect
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 16),

        // Imagen directa cuando fue correcta
        if (rtaUrl != null && isCorrect) ...[
          _buildImage(rtaUrl, size: 120),
          const SizedBox(height: 16),
        ],

        // Botón pista cuando fue incorrecta (abre modal, no revela texto)
        if (rtaUrl != null && !isCorrect) ...[
          _buildHintButton(rtaUrl),
          const SizedBox(height: 16),
        ],

        Text("Repetimos esta pregunta en",
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey.shade700, fontSize: 15)),
        const SizedBox(height: 6),
        Text("$secondsLeft segundos...",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: orange)),
      ],
    );
  }

  // ── Done card ────────────────────────────────────────────────

  Widget _buildDoneCard() {
    return Column(
      key: const ValueKey("doneCard"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_rounded,
            color: Colors.green.shade600, size: 80),
        const SizedBox(height: 20),
        const Text("¡Ejercicio Completado!",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
        const SizedBox(height: 12),
        Text("Has completado todos los intervalos de esta tarjeta.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4)),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                elevation: 0,
              ),
              child: const Text("Volver al menú",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: handleNextCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                elevation: 0,
              ),
              child: const Text("Siguiente ejercicio",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Widget palabra tocable ───────────────────────────────────

class _ClickableWord extends StatefulWidget {
  final String word;
  final String imageUrl;
  final Color orange;

  const _ClickableWord({
    required this.word,
    required this.imageUrl,
    required this.orange,
  });

  @override
  State<_ClickableWord> createState() => _ClickableWordState();
}

class _ClickableWordState extends State<_ClickableWord> {
  bool _pressed = false;

  void _showImageModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20)
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Image.network(
                      widget.imageUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.word
                          .replaceAll(RegExp(r'[¿?¡!.,;:]'), ''),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.orange),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text("Toca para cerrar",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _showImageModal(context);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Text(
        widget.word,
        style: TextStyle(
          fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _pressed
                ? Colors.black87          // oscurece al presionar
                : Colors.black54,         // gris normal
            decoration: TextDecoration.underline,
            decorationColor: _pressed
                ? const Color(0xFFFFEB3B) // amarillo al presionar
                : Colors.black38,         // gris suave normal
            decorationThickness: 2,
            decorationStyle: TextDecorationStyle.solid,
          ),
        ),
      
    );
  }
}