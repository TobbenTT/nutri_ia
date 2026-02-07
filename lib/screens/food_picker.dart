import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // ✅ USA HTTP PURO
import 'api_config.dart';

class FoodPicker extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelected;
  const FoodPicker({super.key, required this.onSelected});

  @override
  State<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<FoodPicker> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _calController = TextEditingController();

  // Color morado de tu screenshot
  final Color _purpleColor = const Color(0xFF9D00FF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // ✅ LÓGICA IA CON HTTP (GEMINI 3 FLASH PREVIEW)
  Future<void> _calculateWithAI_HTTP() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${ApiConfig.geminiApiKey}');

      final body = jsonEncode({
        "contents": [{
          "parts": [{
            "text": "Calcula calorías y macros para: '${_nameController.text}'. Responde SOLO JSON válido: {\"name\": \"${_nameController.text}\", \"calories\": 0, \"protein\": 0, \"carbs\": 0, \"fat\": 0, \"sugar\": 0, \"fiber\": 0, \"sodium\": 0} enteros."
          }]
        }]
      });

      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null) {
          String text = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          text = text.replaceAll("```json", "").replaceAll("```", "").trim();
          final data = jsonDecode(text);
          if (mounted) { widget.onSelected(data); Navigator.pop(context); }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submitManual() {
    if (_calController.text.isEmpty) {
      _calculateWithAI_HTTP(); // Si no hay calorías, usa IA (HTTP)
    } else {
      widget.onSelected({
        'name': _nameController.text,
        'calories': int.tryParse(_calController.text) ?? 0,
        'protein': 0, 'carbs': 0, 'fat': 0, 'sugar': 0, 'fiber': 0, 'sodium': 0
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Fondo oscuro
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),

          TabBar(
            controller: _tabController,
            indicatorColor: _purpleColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "Nuevo", icon: Icon(Icons.edit)),
              Tab(text: "Recientes", icon: Icon(Icons.history)),
              Tab(text: "Favoritos", icon: Icon(Icons.star)),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildManualTab(),
                _buildRecentsTab(),
                _buildFavoritesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. PESTAÑA MANUAL (DISEÑO CAPTURA DE PANTALLA)
  Widget _buildManualTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: _purpleColor));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInput(_nameController, "Nombre (Ej: Manzana)"),
          const SizedBox(height: 15),
          _buildInput(_calController, "Calorías", isNumber: true),
          const SizedBox(height: 30),

          // BOTÓN MORADO
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitManual,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purpleColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text("AGREGAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecentsTab() {
    // (Código de lista de recientes simple, igual que antes)
    return const Center(child: Text("Historial", style: TextStyle(color: Colors.grey)));
  }

  Widget _buildFavoritesTab() {
    // (Código de lista de favoritos simple)
    return const Center(child: Text("Favoritos", style: TextStyle(color: Colors.grey)));
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          labelText: hint, // Para que se vea como en la captura con el label flotante
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}