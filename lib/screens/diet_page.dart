import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Si da error, usa Text normal o instala este paquete
import '../services/ai_service.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  String _dietPlan = "";
  bool _isLoading = false;

  Future<void> _generateDiet() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 1. Obtenemos datos del usuario
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() as Map<String, dynamic>;

      // Calculamos calorías base (simple)
      double weight = (data['weight'] ?? 70).toDouble();
      int targetCals = (weight * 30).round(); // Estimado rápido

      // 2. Llamamos a la IA
      final ai = AiService();
      final plan = await ai.generateDietPlan(targetCals, "Mantenerse en forma y ganar músculo");

      setState(() {
        _dietPlan = plan ?? "Error al conectar con la IA.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chef IA 👨‍🍳")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_dietPlan.isEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text("¿No sabes qué comer hoy?", style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text("GENERAR MENÚ INTELIGENTE"),
                        onPressed: _generateDiet,
                      )
                    ],
                  ),
                ),
              ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))),

            if (_dietPlan.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                    ),
                    // Usamos Text simple por si no tienes flutter_markdown
                    child: Text(_dietPlan, style: const TextStyle(fontSize: 16, height: 1.5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}