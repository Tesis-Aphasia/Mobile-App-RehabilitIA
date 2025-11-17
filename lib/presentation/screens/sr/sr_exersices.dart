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
  String mode = "question"; // question | timer | doneCard
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

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      await _speech.initialize();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor habilita el micrófono para usar voz.")),
      );
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

  Future<void> _loadCards() async {
    final userId = Provider.of<RegisterViewModel>(context, listen: false).userId;
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
          .get();

      final data = ejerciciosSnap.docs
          .map((d) => {"id": d.id, ...d.data()})
          .toList()
          .cast<Map<String, dynamic>>();

      if (data.isEmpty) {
        setState(() => loading = false);
        return;
      }

      final first = data.first;

      setState(() {
        cards = data;
        currentCard = first;
        cardState = {
          ...first,
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

  void handleSubmit() async {
    if (currentCard == null || cardState == null) return;

    final userAns = answerCtrl.text.trim().toLowerCase();
    final correctAns = (currentCard!["rta_correcta"] ?? "").trim().toLowerCase();
    final isCorrect = userAns == correctAns;

    answerCtrl.clear();
    recognizedText = "";

    final intervals = List<int>.from(
      currentCard!["intervals_sec"] ?? [15, 30, 60, 120, 240],
    );

    final nextIndex = isCorrect
        ? (cardState!["interval_index"] + 1).clamp(0, intervals.length - 1)
        : 0;

    final updated = {
      ...cardState!,
      "interval_index": nextIndex,
      "success_streak": isCorrect ? (cardState!["success_streak"] + 1) : 0,
      "lapses": isCorrect ? cardState!["lapses"] : (cardState!["lapses"] + 1),
      "last_answer_correct": isCorrect,
      "next_due": DateTime.now().millisecondsSinceEpoch +
          intervals[nextIndex] * 1000,
    };

    setState(() {
      cardState = updated;
      secondsLeft = intervals[nextIndex];
      feedback = isCorrect
          ? "✅ ¡Correcto!"
          : "❌ Incorrecto\nRespuesta: ${currentCard!["rta_correcta"]}";
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

  void handleNextCard() {
    if (currentCard == null) return;
    final currentIndex = cards.indexWhere((c) => c["id"] == currentCard!["id"]);
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

  // ---------------------------------------
  //                 UI
  // ---------------------------------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: CircularProgressIndicator(color: orange),
        ),
      );
    }

    if (cards.isEmpty) {
      return Scaffold(
        backgroundColor: background,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "No hay ejercicios aún 😄",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Cuando tu terapeuta te asigne ejercicios de memoria,\nlos verás aquí.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Volver",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final intervals = List<int>.from(
      currentCard!["intervals_sec"] ?? [15, 30, 60, 120, 240],
    );

    final intervalLabel = mode == "timer"
        ? "Intervalo actual: ${intervals[cardState!["interval_index"]]} s"
        : "Próximo intervalo: ${intervals[(cardState!["interval_index"] + 1)
            .clamp(0, intervals.length - 1)]} s";

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
        title: const Text(
          "Recuperación Espaciada",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Subtexto con el intervalo
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                intervalLabel,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --------- CARD PRINCIPAL ----------
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
                      offset: const Offset(0, 4),
                    ),
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

  // ---------------------------------------
  //       CONTENIDO SEGÚN EL MODO
  // ---------------------------------------
  Widget _buildCardContent() {
    if (mode == "question") {
      return Column(
        key: const ValueKey("question"),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            currentCard!["pregunta"] ?? "",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 22),

          // Input amigable
          TextField(
            controller: answerCtrl,
            decoration: InputDecoration(
              hintText: "Escribe o di tu respuesta...",
              filled: true,
              fillColor: const Color(0xFFFFE8DD),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: _isListening ? Colors.red : Colors.grey.shade700,
                ),
                onPressed: () {
                  _isListening ? _stopListening() : _startListening();
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          ElevatedButton(
            onPressed: handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Enviar",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              feedback,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: feedback.startsWith("✅")
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      );
    }

    if (mode == "timer") {
      return Column(
        key: const ValueKey("timer"),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            feedback,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: feedback.startsWith("✅")
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Repetimos esta pregunta en",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$secondsLeft segundos...",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: orange,
            ),
          ),
        ],
      );
    }

    // doneCard
    return Column(
      key: const ValueKey("doneCard"),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "🎉 ¡Completaste esta tarjeta!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: handleNextCard,
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            elevation: 0,
          ),
          child: const Text(
            "Siguiente",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
