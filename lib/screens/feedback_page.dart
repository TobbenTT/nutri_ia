import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _textController = TextEditingController();
  String _type = 'bug'; // Puede ser 'bug' o 'suggestion'
  bool _isLoading = false;

  Future<void> _sendReport() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'type': _type, // 'bug' o 'suggestion'
        'description': text,
        'user_id': user?.uid ?? 'anon',
        'user_email': user?.email ?? 'anon',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'open', // Para que tú sepas cuáles has revisado
        'app_version': '1.0.0+1', // Útil para saber en qué versión falló
      });

      if (mounted) {
        // Limpiar y avisar
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_type == 'bug'
                ? "¡Gracias! Cazaremos ese bug 🐛"
                : "¡Gracias! Tu idea ha sido anotada 💡"
            ),
            backgroundColor: const Color(0xFF00FF88),
          ),
        );
        Navigator.pop(context); // Volver a ajustes
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al enviar: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBug = _type == 'bug';
    final neonColor = isBug ? Colors.redAccent : const Color(0xFF00FF88);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Centro de Feedback", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¿Qué quieres enviarnos?",
              style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // SELECTOR TIPO TOGGLE
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'bug'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: isBug ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF1E1E1E),
                        border: Border.all(color: isBug ? Colors.redAccent : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.bug_report, color: isBug ? Colors.redAccent : Colors.grey),
                          const SizedBox(height: 5),
                          Text("Reportar Error", style: TextStyle(color: isBug ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'suggestion'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: !isBug ? const Color(0xFF00FF88).withOpacity(0.2) : const Color(0xFF1E1E1E),
                        border: Border.all(color: !isBug ? const Color(0xFF00FF88) : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lightbulb, color: !isBug ? const Color(0xFF00FF88) : Colors.grey),
                          const SizedBox(height: 5),
                          Text("Sugerencia", style: TextStyle(color: !isBug ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // CAMPO DE TEXTO
            Text(
              isBug ? "Describe el error:" : "Tu idea millonaria:",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: isBug
                    ? "Ej: Al abrir el calendario se cierra la app..."
                    : "Ej: Me gustaría que agregaran modo oscuro automático...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: neonColor)),
              ),
            ),

            const SizedBox(height: 30),

            // BOTÓN ENVIAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_isLoading ? "ENVIANDO..." : "ENVIAR INFORME", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}