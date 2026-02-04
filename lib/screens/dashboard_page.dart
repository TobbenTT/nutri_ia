import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'settings_page.dart'; // Asegúrate de tener esta página o comenta la línea si no

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  late final GenerativeModel _model;
  final ImagePicker _picker = ImagePicker();

  // META DE CALORÍAS DIARIA (Puedes hacerla editable en Ajustes después)
  final int dailyGoal = 2000;

  @override
  void initState() {
    super.initState();
    // ⚠️ REEMPLAZA 'TU_API_KEY_AQUI' CON TU API KEY REAL DE GEMINI
    const apiKey = 'TU_API_KEY_AQUI';

    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // O el modelo que estés usando
      apiKey: apiKey,
    );
  }

  // --- FUNCIÓN 1: ESCANEAR COMIDA CON CÁMARA (IA VISUAL) ---
  Future<void> _scanFood() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
      );

      final imageBytes = await photo.readAsBytes();
      final content = [
        Content.multi([
          TextPart("Identifica este alimento y estima sus calorías totales. Responde SOLO con el siguiente formato JSON: {\"food\": \"Nombre del plato\", \"calories\": 500}. No uses markdown."),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      Navigator.pop(context); // Cerrar cargando

      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? "{}";

      // Parseo manual simple (o puedes usar dart:convert si prefieres)
      // Buscamos el nombre y las calorías en el texto sucio por si la IA falla el JSON exacto
      String foodName = "Alimento detectado";
      int calories = 0;

      // Extracción "a prueba de balas" usando RegExp
      final nameMatch = RegExp(r'"food":\s*"([^"]+)"').firstMatch(text);
      if (nameMatch != null) foodName = nameMatch.group(1) ?? "Comida";

      final calMatch = RegExp(r'"calories":\s*(\d+)').firstMatch(text);
      if (calMatch != null) calories = int.parse(calMatch.group(1)!);

      _saveMeal(foodName, calories);

    } catch (e) {
      if (mounted) Navigator.pop(context); // Cerrar cargando si hay error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al analizar: $e")));
    }
  }

  // --- FUNCIÓN 2: AGREGAR MANUALMENTE (IA DE TEXTO) ---
  // ESTA ES LA QUE ARREGLAMOS: Tú escribes, la IA calcula.
  void _showAddManualDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1F1F1F),
              title: const Text("Agregar Manual", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Escribe qué comiste. La IA calculará las calorías.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ej: 2 completos italianos",
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none
                      ),
                      prefixIcon: const Icon(Icons.edit, color: Color(0xFF00FF88)),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (nameController.text.isEmpty) return;
                    setState(() => isLoading = true);

                    try {
                      // Preguntamos a Gemini solo con texto
                      final content = [
                        Content.text(
                            "Eres un nutricionista experto. Dime SOLO el número entero de calorías totales aproximadas para: '${nameController.text}'. No escribas texto, solo el número (ej: 450).")
                      ];

                      final response = await _model.generateContent(content);

                      // Limpiamos la respuesta para obtener solo números
                      final String resultText = response.text?.trim() ?? "0";
                      final String numbersOnly = resultText.replaceAll(RegExp(r'[^0-9]'), '');
                      final int calories = int.tryParse(numbersOnly) ?? 0;

                      if (calories > 0) {
                        await _saveMeal(nameController.text, calories);
                        if (mounted) Navigator.pop(context);
                      } else {
                        throw "No se pudieron calcular calorías";
                      }

                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: No entendí qué comida es esa.")),
                      );
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("CALCULAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNCIÓN AUXILIAR PARA GUARDAR EN FIREBASE ---
  Future<void> _saveMeal(String name, int calories) async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('meals')
        .add({
      'name': name,
      'calories': calories,
      'timestamp': FieldValue.serverTimestamp(),
      // Guardamos la fecha en formato simple para facilitar filtros después (opcional)
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Agregado: $name ($calories kcal)"),
        backgroundColor: const Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- CERRAR SESIÓN ---
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // Navigator.pop(context) o pushReplacement a Login lo maneja el AuthGate generalmente
    // Pero si no tienes AuthGate, descomenta esto:
    // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el inicio y fin del día para filtrar la base de datos
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Nutri_IA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: _logout,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream que escucha solo las comidas de HOY
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('meals')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThanOrEqualTo: endOfDay)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar datos", style: TextStyle(color: Colors.white)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));

          final docs = snapshot.data!.docs;

          // Calcular total consumido hoy
          int totalCalories = 0;
          for (var doc in docs) {
            totalCalories += (doc['calories'] as num).toInt();
          }

          // Calcular porcentaje para la barra (máximo 1.0)
          double progress = (totalCalories / dailyGoal).clamp(0.0, 1.0);

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TARJETA DE RESUMEN
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Calorías hoy", style: TextStyle(color: Colors.grey)),
                              Text(
                                "$totalCalories / $dailyGoal",
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Icon(Icons.local_fire_department, color: const Color(0xFF00FF88), size: 30),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.black,
                          color: progress > 1.0 ? Colors.red : const Color(0xFF00FF88),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
                const Text("Tus comidas", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // LISTA DE COMIDAS
                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text("Aún no has comido nada hoy.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        color: const Color(0xFF111111),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1F1F1F),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant, color: Color(0xFF00FF88), size: 20),
                          ),
                          title: Text(data['name'] ?? "Comida", style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                              DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()),
                              style: const TextStyle(color: Colors.grey, fontSize: 12)
                          ),
                          trailing: Text(
                            "${data['calories']} kcal",
                            style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btnManual",
            onPressed: _showAddManualDialog,
            backgroundColor: const Color(0xFF1F1F1F),
            child: const Icon(Icons.edit, color: Colors.white),
          ),
          const SizedBox(height: 15),
          FloatingActionButton(
            heroTag: "btnCamara",
            onPressed: _scanFood,
            backgroundColor: const Color(0xFF00FF88),
            child: const Icon(Icons.camera_alt, color: Colors.black),
          ),
        ],
      ),
    );
  }
}