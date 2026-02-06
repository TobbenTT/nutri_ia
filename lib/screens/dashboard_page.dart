import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'social_page.dart';
import 'settings_page.dart'; // <--- ESTO ES CRUCIAL
import 'calendar_page.dart';
import 'dart:convert';

// ==========================================
// CLASE PRINCIPAL: DASHBOARD OPTIMIZADO
// ==========================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // VARIABLES DE IA Y NAVEGACIÓN
  late final GenerativeModel _model;
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;

  // META DE CALORÍAS
  final int dailyGoal = 2000;

  // CACHE PARA DATOS DEL GRÁFICO (evita recalcular en cada build)
  final Map<int, double> _chartCache = {};

  @override
  void initState() {
    super.initState();

    const apiKey = 'PON_TU_API_KEY_AQUI';

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      // ESTA ES LA LÍNEA QUE FALTA Y QUE SOLUCIONA EL ERROR "NOT FOUND"
      requestOptions: const RequestOptions(apiVersion: 'v1'),

      // Mantenemos la configuración de seguridad para evitar bloqueos
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );

    _loadWeeklyStats();
  }


  Future<void> _loadWeeklyStats() async {
    if (user == null) return;

    final now = DateTime.now();
    // Calculamos la fecha de hace 7 días (al inicio del día)
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    // 1. Inicializamos el gráfico en 0
    Map<int, double> tempStats = {};
    for (int i = 0; i < 7; i++) {
      tempStats[i] = 0.0;
    }

    try {
      // 2. Pedimos a Firebase las comidas desde hace 7 días hasta hoy
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();

      // 3. Procesamos y sumamos
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? ts = data['timestamp'];
        final int cals = (data['calories'] as num? ?? 0).toInt();

        if (ts != null) {
          final date = ts.toDate();
          // Normalizamos fechas para ignorar horas/minutos
          final dateKey = DateTime(date.year, date.month, date.day);
          final todayKey = DateTime(now.year, now.month, now.day);

          final diff = todayKey.difference(dateKey).inDays;

          // Si la comida es de los últimos 7 días (diff entre 0 y 6)
          if (diff >= 0 && diff <= 6) {
            // El índice 6 es HOY, el índice 0 es hace 6 días
            int chartIndex = 6 - diff;
            tempStats[chartIndex] = (tempStats[chartIndex] ?? 0) + cals;
          }
        }
      }

      // 4. Actualizamos el gráfico
      if (mounted) {
        setState(() {
          _chartCache.addAll(tempStats);
        });
      }
    } catch (e) {
      debugPrint("Error cargando stats: $e");
    }
  }
// ----------------------------------------------------------
// LÓGICA DE IA (TEXTO) CON DIAGNÓSTICO DETALLADO
// ----------------------------------------------------------
  void _showManualEntryDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Agregar con IA Pro", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Gemini calculará los macros automáticamente.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ej: Pollo con arroz",
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (isLoading) const Padding(padding: EdgeInsets.only(top: 20), child: CircularProgressIndicator(color: Color(0xFF00FF88))),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      // Prompt simplificado porque forzamos el modo JSON abajo
                      final prompt = "Analiza nutricionalmente: '${nameController.text}'. "
                          "Calcula calorias, proteinas, carbohidratos y grasas. "
                          "Responde usando este esquema JSON: {\"calories\": int, \"protein\": int, \"carbs\": int, \"fat\": int}";

                      final content = [Content.text(prompt)];

                      // MAGIA AQUÍ: responseMimeType fuerza a Gemini a devolver SOLO JSON válido.
                      final response = await _model.generateContent(
                        content,
                        generationConfig: GenerationConfig(
                            responseMimeType: 'application/json',
                            temperature: 0.2 // Baja temperatura para datos precisos
                        ),
                      );

                      // Ya no necesitamos Regex complejo porque la respuesta es JSON puro
                      final cleanText = response.text ?? "{}";
                      final data = jsonDecode(cleanText);

                      await _saveMeal(
                          nameController.text,
                          data['calories'] ?? 0,
                          protein: data['protein'] ?? 0,
                          carbs: data['carbs'] ?? 0,
                          fat: data['fat'] ?? 0
                      );
                      if (mounted) Navigator.pop(context);

                    } catch (e) {
                      debugPrint("ERROR IA: $e");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: Verificaste tu API Key? $e"), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
                  child: const Text("Calcular", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------
  // LÓGICA DE IA (CÁMARA): FOTO -> CALORÍAS
  // ----------------------------------------------------------
  Future<void> _scanFood() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (photo == null) return;

      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))));

      final bytes = await photo.readAsBytes();
      final content = [
        Content.multi([
          TextPart("Identifica el alimento principal y estima sus macros. "
              "Responde usando este esquema JSON: {\"food\": \"nombre corto\", \"calories\": int, \"protein\": int, \"carbs\": int, \"fat\": int}"),
          DataPart('image/jpeg', bytes),
        ])
      ];

      // MAGIA AQUÍ TAMBIÉN: Forzar JSON
      final response = await _model.generateContent(
        content,
        generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.2
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);

      final cleanText = response.text ?? "{}";
      final data = jsonDecode(cleanText);

      await _saveMeal(
          data['food'] ?? "Comida escaneada",
          data['calories'] ?? 0,
          protein: data['protein'] ?? 0,
          carbs: data['carbs'] ?? 0,
          fat: data['fat'] ?? 0
      );

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cierra el loader si hay error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al escanear: $e")));
      }
    }
  }

  // ----------------------------------------------------------
  // VISTAS DE LA APLICACIÓN
  // ----------------------------------------------------------

  Widget _buildHomeView() {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    return StreamBuilder<QuerySnapshot>(
      // OPTIMIZACIÓN: Una sola query con índices
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        // OPTIMIZACIÓN: Calcular totales una sola vez
        int totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
        final meals = snapshot.data!.docs;

        for (var doc in meals) {
          final data = doc.data() as Map<String, dynamic>;
          totalCal += (data['calories'] ?? 0) as int;
          totalProtein += (data['protein'] ?? 0) as int;
          totalCarbs += (data['carbs'] ?? 0) as int;
          totalFat += (data['fat'] ?? 0) as int;
        }

        final double progress = totalCal / dailyGoal;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text("Dashboard", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("${DateFormat('EEEE, d MMMM').format(now)}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 30),

              // Progreso Circular
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 15,
                        backgroundColor: Colors.grey.shade800,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("$totalCal", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        Text("de $dailyGoal kcal", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Macronutrientes
              _buildMacroRow(totalProtein, totalCarbs, totalFat),
              const SizedBox(height: 30),

              // Comidas del día (OPTIMIZADA - sin StreamBuilder anidado)
              _buildMealsSection(meals),
              const SizedBox(height: 30),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showManualEntryDialog,
                      icon: const Icon(Icons.edit, color: Colors.black),
                      label: const Text("Agregar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanFood,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text("Escanear", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget optimizado para mostrar comidas (sin StreamBuilder anidado)
  Widget _buildMealsSection(List<QueryDocumentSnapshot> meals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Comidas de Hoy", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          meals.isEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text("No hay comidas registradas", style: TextStyle(color: Colors.grey))),
          )
              : Column(
            children: meals.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildMealItem(
                data['name'] ?? 'Sin nombre',
                data['calories'] ?? 0,
                doc.id,
                protein: data['protein'] ?? 0,
                carbs: data['carbs'] ?? 0,
                fat: data['fat'] ?? 0,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(int protein, int carbs, int fat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMacroCard("Proteína", protein, Icons.fitness_center, const Color(0xFFFF6B6B)),
        _buildMacroCard("Carbohidratos", carbs, Icons.grain, const Color(0xFF4ECDC4)),
        _buildMacroCard("Grasas", fat, Icons.water_drop, const Color(0xFFFFD93D)),
      ],
    );
  }

  Widget _buildMacroCard(String name, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text("${value}g", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(name, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(String name, int calories, String docId, {int protein = 0, int carbs = 0, int fat = 0}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF00FF88),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("P: ${protein}g • C: ${carbs}g • G: ${fat}g", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$calories", style: const TextStyle(color: Color(0xFF00FF88), fontSize: 16, fontWeight: FontWeight.bold)),
              const Text("kcal", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => _deleteMeal(docId),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeal(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('meals')
        .doc(docId)
        .delete();
  }

  // ----------------------------------------------------------
  // VISTA DE ESTADÍSTICAS (OPTIMIZADA)
  // ----------------------------------------------------------
  Widget _buildStatsView() {
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Estadísticas", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),

          // Gráfico de Barras (OPTIMIZADO - datos pre-calculados)
          // Gráfico de Barras (CORREGIDO)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Última Semana", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // CAMBIO 1: Aumentamos la altura de 250 a 300 para dar más aire
                SizedBox(
                  height: 300,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final date = now.subtract(Duration(days: 6 - i));
                      final dayLabel = DateFormat('E').format(date);
                      final isToday = date.day == now.day;

                      final height = _chartCache[i] ?? 100.0;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Texto de calorías (arriba de la barra)
                          Text(
                              "${(height * 10).toInt()}",
                              style: const TextStyle(color: Colors.grey, fontSize: 10)
                          ),
                          const SizedBox(height: 8),

                          // Barra visual
                          Container(
                            width: 12,
                            // CAMBIO 2: Limitamos la altura máxima de la barra para que no rompa el diseño
                            height: (isToday ? 150.0 : height).clamp(10.0, 200.0).toDouble(),
                            decoration: BoxDecoration(
                              color: isToday ? const Color(0xFF00FF88) : const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Letra del día (abajo)
                          Text(
                              dayLabel[0],
                              style: TextStyle(
                                  color: isToday ? const Color(0xFF00FF88) : Colors.grey,
                                  fontWeight: FontWeight.bold
                              )
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              _buildStatCard("Promedio", "1850", Icons.functions),
              const SizedBox(width: 15),
              _buildStatCard("Mejor Día", "Viernes", Icons.emoji_events),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.grey, size: 20),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // NAVEGACIÓN
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeView(),
            _buildStatsView(),
            const SocialPage(),
            const SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: const Color(0xFF0A0A0A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00FF88),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Stats"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Social"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ajustes"),
        ],
      ),
    );
  }
  // ==========================================
  // FUNCIÓN FALTANTE: GUARDAR EN FIREBASE
  // ==========================================
  Future<void> _saveMeal(String name, int calories, {int protein = 0, int carbs = 0, int fat = 0}) async {
    // Verificamos si el usuario está logueado
    if (user == null) return;

    try {
      // Guardamos en la sub-colección 'meals' del usuario
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meals')
          .add({
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'timestamp': FieldValue.serverTimestamp(), // Marca de tiempo del servidor
        'date_str': DateFormat('yyyy-MM-dd').format(DateTime.now()), // Fecha string para búsquedas fáciles
      });

      // Actualizamos el gráfico localmente para ver el cambio inmediato
      await _loadWeeklyStats();

      // Mostramos confirmación visual
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Guardado: $name (Cal: $calories)"),
            backgroundColor: const Color(0xFF00FF88),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error guardando comida: $e");
    }
  }

}

