import 'dart:math';
import 'package:flutter/material.dart';

class VnestSentenceEvaluationScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const VnestSentenceEvaluationScreen({super.key, required this.exercise});

  @override
  State<VnestSentenceEvaluationScreen> createState() => _VnestSentenceEvaluationScreenState();
}

class _VnestSentenceEvaluationScreenState extends State<VnestSentenceEvaluationScreen> {
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

  @override
  void initState() {
    super.initState();
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

  void handleDecision(String decision) {
    if (showDone) return;
    final current = sentences[index];
    final userCorrect = decision == 'accepted';
    final systemCorrect = current['correcta'] == true;

    setState(() {
      current['status'] = decision;
      deltaX = 0.0;
      dragging = false;

      if (userCorrect != systemCorrect) {
        showError = true;
        feedback = current['explicacion'] ?? "Revisa bien la oración antes de continuar.";
      } else {
        showError = false;
        feedback = null;
        index++;
      }
    });
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
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
                child: Text("Paso 3 de 5",
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    )),
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

              // --- Contenido principal ---
              Expanded(
                child: Center(
                  child: !showDone && current != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // --- Mensaje de error ---
                            if (showError)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
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

                            // --- Tarjeta grande ---
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
                                    child: _buildLargeCard(current['text'], deltaX),
                                  ),
                                ),
                              ),
                            ),

                            // --- Explicación ---
                            if (feedback != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(top: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  border: Border.all(color: orange.withOpacity(0.6)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline, color: orange, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        feedback!,
                                        textAlign: TextAlign.left,
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

              // --- Botones de acción ---
              if (!showDone)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: handleReject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Mal"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Bien"),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // --- Navegación ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        backgroundColor: showDone ? orange : orange.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Siguiente",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          "Lee cada oración con atención. Decide si la oración tiene sentido y es correcta. Puedes deslizar la tarjeta o usar los botones de abajo.",
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      );

  Widget _buildLargeCard(String text, double? deltaX) {
    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;

    if (deltaX != null && deltaX > 0) {
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
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.4,
          ),
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
              final border = acertaste ? Colors.green.shade300 : Colors.red.shade300;
              final tagBg = acertaste ? Colors.green.shade100 : Colors.red.shade100;
              final tagText = acertaste ? Colors.green.shade700 : Colors.red.shade700;
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    Text(
                      s['text'] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sistema: ${s['correcta'] ? "Correcta" : "Incorrecta"} · Tú marcaste: ${userSaysCorrect ? "Bien" : "Mal"}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
