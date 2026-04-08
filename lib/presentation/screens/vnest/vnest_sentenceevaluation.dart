import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// ===========================================================
//  PALABRAS con imagen: se leen dinámicamente del pubspec.yaml
//  Convierte "pista_de_atletismo.png" → "pista de atletismo"
//  Así no hay lista hardcodeada — agrega un PNG a assets/images/
//  y automáticamente se reconoce en el texto.
// ===========================================================
List<String> _imageWords = [];

Future<void> _loadImageWords(void Function(VoidCallback) setState) async {
  if (_imageWords.isNotEmpty) return;
  try {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final regex = RegExp(r'assets/images/([^"]+)\.png');
    final matches = regex.allMatches(manifest);
    final words = matches
        .map((m) => m.group(1)!.replaceAll('_', ' '))
        .toList();
    words.sort((a, b) => b.length.compareTo(a.length));
    setState(() => _imageWords = words);
  } catch (_) {}
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[áàäâ]'), 'a')
    .replaceAll(RegExp(r'[éèëê]'), 'e')
    .replaceAll(RegExp(r'[íìïî]'), 'i')
    .replaceAll(RegExp(r'[óòöô]'), 'o')
    .replaceAll(RegExp(r'[úùüû]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z\s]'), '')
    .trim();

String _toAssetName(String phrase) => _normalize(phrase).replaceAll(' ', '_');

// ===========================================================
//  SEGMENTO: trozo de texto, con o sin imagen
// ===========================================================
class _Segment {
  final String text;
  final bool hasImage;
  final String imageKey;
  const _Segment(this.text, {this.hasImage = false, this.imageKey = ''});
}

List<_Segment> _tokenize(String text) {
  final sorted = List<String>.from(_imageWords)
    ..sort((a, b) => b.length.compareTo(a.length));

  final normalizedText = _normalize(text);
  final segments = <_Segment>[];
  int cursor = 0;

  while (cursor < normalizedText.length) {
    bool found = false;

    for (final phrase in sorted) {
      final normPhrase = _normalize(phrase);
      if (normalizedText.startsWith(normPhrase, cursor)) {
        final original = text.substring(cursor, cursor + normPhrase.length);
        segments.add(_Segment(original, hasImage: true, imageKey: _toAssetName(phrase)));
        cursor += normPhrase.length;
        if (cursor < normalizedText.length && normalizedText[cursor] == ' ') cursor++;
        found = true;
        break;
      }
    }

    if (!found) {
      final start = cursor;
      while (cursor < normalizedText.length) {
        bool willMatch = false;
        for (final phrase in sorted) {
          if (normalizedText.startsWith(_normalize(phrase), cursor)) {
            willMatch = true;
            break;
          }
        }
        if (willMatch) break;
        cursor++;
      }
      final rawText = text.substring(start, cursor).trimRight();
      if (rawText.isNotEmpty) segments.add(_Segment(rawText));
      if (cursor < normalizedText.length && normalizedText[cursor] == ' ') cursor++;
    }
  }

  return segments;
}

// ===========================================================
//  DIALOG imagen
// ===========================================================
void _showImageDialog(BuildContext context, String imageKey) {
  final path = "assets/images/$imageKey.png";
  final size = MediaQuery.of(context).size;

  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: size.width * 0.85,
        height: size.height * 0.70,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text("Imagen no disponible"),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE8DD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "Cerrar",
                    style: TextStyle(
                      color: Color(0xFFF48A63),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ===========================================================
//  WIDGET de texto con palabras interactivas
// ===========================================================
class _SentenceWithImages extends StatefulWidget {
  final String text;
  final Color textColor;
  final double fontSize;

  const _SentenceWithImages({
    required this.text,
    this.textColor = Colors.black87,
    this.fontSize = 22,
  });

  @override
  State<_SentenceWithImages> createState() => _SentenceWithImagesState();
}

class _SentenceWithImagesState extends State<_SentenceWithImages> {
  String? _hoveringKey;

  @override
  Widget build(BuildContext context) {
    final segments = _tokenize(widget.text);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: _buildWidgets(segments),
    );
  }

  List<Widget> _buildWidgets(List<_Segment> segments) {
    final widgets = <Widget>[];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isLast = i == segments.length - 1;
      final displayText = isLast ? seg.text : '${seg.text} ';

      if (!seg.hasImage) {
        widgets.add(Text(
          displayText,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: widget.textColor,
            height: 1.4,
          ),
        ));
      } else {
        final isHovering = _hoveringKey == seg.imageKey;

        widgets.add(
          MouseRegion(
            onEnter: (_) => setState(() => _hoveringKey = seg.imageKey),
            onExit: (_) => setState(() => _hoveringKey = null),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showImageDialog(context, seg.imageKey),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 3),
                decoration: BoxDecoration(
                  color: isHovering
                      ? Colors.amber.withOpacity(0.35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border(
                    bottom: BorderSide(
                      color: widget.textColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}

// ===========================================================
//  PANTALLA PRINCIPAL
// ===========================================================
class VnestSentenceEvaluationScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const VnestSentenceEvaluationScreen({super.key, required this.exercise});

  @override
  State<VnestSentenceEvaluationScreen> createState() =>
      _VnestSentenceEvaluationScreenState();
}

class _VnestSentenceEvaluationScreenState
    extends State<VnestSentenceEvaluationScreen> {
  final background = const Color(0xFFFEF9F4);
  final orange = const Color(0xFFF48A63);

  late List<Map<String, dynamic>> sentences;
  int index = 0;
  double deltaX = 0.0;
  bool dragging = false;
  Offset startPos = Offset.zero;

  String? feedback;
  bool showError = false;
  bool showExpandedInfo = false;

  // Flash solo se activa cuando la respuesta es correcta
  String? _cardFlash; // 'accepted' | 'rejected' | null

  @override
  void initState() {
    super.initState();
    _loadImageWords(setState);
    final oraciones = (widget.exercise['oraciones'] as List?) ?? [];
    sentences = _shuffle(oraciones.asMap().entries.map((e) {
      final o = e.value as Map<String, dynamic>;
      return {
        "id": e.key,
        "text": o['oracion'] ?? "",
        "correcta": o['correcta'] ?? false,
        "explicacion": o['explicacion'] ?? "",
        "status": "pending",
      };
    }).toList());
  }

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

  bool get showDone => index >= sentences.length;

  // Valida primero:
  //   ✅ correcto  → activa flash del color de la decisión, luego avanza
  //   ❌ incorrecto → sin flash, muestra error y explicación
  void handleDecision(String decision) async {
    if (showDone) return;
    final current = sentences[index];
    final userCorrect = decision == 'accepted';
    final systemCorrect = current['correcta'] == true;
    final isRight = userCorrect == systemCorrect;

    if (isRight) {
      setState(() {
        current['status'] = decision;
        _cardFlash = decision;
        showError = false;
        feedback = null;
        deltaX = 0.0;
        dragging = false;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _cardFlash = null;
          index++;
        });
      }
    } else {
      setState(() {
        current['status'] = decision;
        _cardFlash = null; // sin flash en error
        deltaX = 0.0;
        dragging = false;
        showError = true;
        feedback = current['explicacion'] ??
            "Revisa bien la oración antes de continuar.";
      });
    }
  }

  void handleAccept() => handleDecision('accepted');
  void handleReject() => handleDecision('rejected');

  void onStart(DragStartDetails details) {
    if (showDone) return;
    startPos = details.globalPosition;
    dragging = true;
  }

  void onUpdate(DragUpdateDetails details) {
    if (!dragging) return;
    setState(() {
      deltaX = details.globalPosition.dx - startPos.dx;
    });
  }

  void onEnd(DragEndDetails details) {
    const threshold = 80;
    if (deltaX > threshold) {
      handleAccept();
    } else if (deltaX < -threshold) {
      handleReject();
    } else {
      setState(() => deltaX = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = !showDone ? sentences[index] : null;

    final reviewed = sentences.where((s) => s['status'] != 'pending').toList();
    final ok = reviewed.where((s) {
      final userCorrect = s['status'] == 'accepted';
      return userCorrect == s['correcta'];
    }).length;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Evalúa las oraciones",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Paso 3 de 5",
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.6,
                  backgroundColor: Colors.grey.shade200,
                  color: orange,
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 20),

              _buildInstructions(),
              if (showExpandedInfo) _buildExpandedInfo(),

              const SizedBox(height: 20),

              Expanded(
                child: Center(
                  child: !showDone && current != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Error feedback
                            if (showError)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red.shade600, size: 20),
                                    const SizedBox(width: 6),
                                    const Text(
                                      "Respuesta incorrecta",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Tarjeta con swipe
                            Expanded(
                              flex: 6,
                              child: GestureDetector(
                                onHorizontalDragStart: onStart,
                                onHorizontalDragUpdate: onUpdate,
                                onHorizontalDragEnd: onEnd,
                                child: Transform.translate(
                                  offset: Offset(deltaX, 0),
                                  child: Transform.rotate(
                                    angle: deltaX * 0.01,
                                    child: _buildLargeCard(
                                        current['text'], deltaX, _cardFlash),
                                  ),
                                ),
                              ),
                            ),

                            // Explicación
                            if (feedback != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(top: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  border: Border.all(
                                      color: orange.withOpacity(0.6)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline,
                                        color: orange, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        feedback!,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : _buildSummary(reviewed, ok),
                ),
              ),

              const SizedBox(height: 16),

              // ── Botones Bien / Mal ──────────────────────────────────────
              if (!showDone)
                Row(
                  children: [
                    // Botón MAL
                    Expanded(
                      child: ElevatedButton(
                        onPressed: handleReject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: Colors.red.shade200, width: 1.5),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 17),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Mal",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Botón BIEN
                    Expanded(
                      child: ElevatedButton(
                        onPressed: handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: Colors.green.shade200, width: 1.5),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.green.shade500,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 17),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Bien",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Anterior / Siguiente
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Anterior"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: showDone
                          ? () => Navigator.pushNamed(
                                context,
                                '/vnest-phase4',
                                arguments: widget.exercise,
                              )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            showDone ? orange : orange.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Siguiente",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildInstructions() => Row(
        children: [
          Expanded(
            child: Text(
              "Desliza a la derecha si es correcta y a la izquierda si es incorrecta.",
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
          "Lee cada oración con atención. Decide si la oración tiene sentido y es correcta. "
          "Las palabras subrayadas tienen una imagen — tócalas para verla. "
          "Puedes deslizar la tarjeta o usar los botones de abajo.",
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      );

  Widget _buildLargeCard(String text, double? deltaX, [String? flash]) {
    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;

    // Flash solo si la respuesta fue correcta (controlado desde handleDecision)
    if (flash == 'accepted') {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
    } else if (flash == 'rejected') {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
    } else if (deltaX != null && deltaX > 0) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
    } else if (deltaX != null && deltaX < 0) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: _SentenceWithImages(
          text: text,
          textColor: textColor,
          fontSize: 22,
        ),
      ),
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> reviewed, int ok) {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Text(
          "¡Listo!",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Aciertos: $ok / ${sentences.length}",
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: reviewed.length,
            itemBuilder: (context, i) {
              final s = reviewed[i];
              final userSaysCorrect = s['status'] == 'accepted';
              final acertaste = userSaysCorrect == s['correcta'];

              final bg = acertaste ? Colors.green.shade50 : Colors.red.shade50;
              final border =
                  acertaste ? Colors.green.shade300 : Colors.red.shade300;
              final tagBg =
                  acertaste ? Colors.green.shade100 : Colors.red.shade100;
              final tagText =
                  acertaste ? Colors.green.shade700 : Colors.red.shade700;
              final title = acertaste ? "Acertaste" : "Te equivocaste";

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: tagText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SentenceWithImages(
                      text: s['text'] ?? "",
                      textColor: Colors.black87,
                      fontSize: 15,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sistema: ${s['correcta'] ? "Correcta" : "Incorrecta"} · "
                      "Tú marcaste: ${userSaysCorrect ? "Bien" : "Mal"}",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

