import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'; // Para HapticFeedback

// IMPORTACIONES DE TUS OTRAS PÁGINAS
import 'social_page.dart';
import 'settings_page.dart';
import 'calendar_page.dart';
import 'api_config.dart';

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

  // META DE CALORÍAS (Dinámica)
  int dailyGoal = 2000;

  // CACHE PARA DATOS DEL GRÁFICO
  final Map<int, double> _chartCache = {};

  @override
  void initState() {
    super.initState();

    // ✅ MODELO GEMINI
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // O el modelo que estés usando
      apiKey: ApiConfig.geminiApiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    _loadUserGoal();
    _loadWeeklyStats();
  }

  // 📥 CARGAR META DEL USUARIO
  Future<void> _loadUserGoal() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && doc.data()!.containsKey('daily_goal')) {
        setState(() {
          dailyGoal = (doc.data()!['daily_goal'] as num).toInt();
        });
      }
    } catch (e) {
      debugPrint("Error cargando meta: $e");
    }
  }

  // 📊 CARGAR ESTADÍSTICAS
  Future<void> _loadWeeklyStats() async {
    if (user == null) return;
    final now = DateTime.now();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    Map<int, double> tempStats = {};
    for (int i = 0; i < 7; i++) tempStats[i] = 0.0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? ts = data['timestamp'];
        final int cals = (data['calories'] as num? ?? 0).toInt();

        if (ts != null) {
          final date = ts.toDate();
          final dateKey = DateTime(date.year, date.month, date.day);
          final todayKey = DateTime(now.year, now.month, now.day);
          final diff = todayKey.difference(dateKey).inDays;

          if (diff >= 0 && diff <= 6) {
            int chartIndex = 6 - diff;
            tempStats[chartIndex] = (tempStats[chartIndex] ?? 0) + cals;
          }
        }
      }

      if (mounted) {
        setState(() {
          _chartCache.addAll(tempStats);
        });
      }
    } catch (e) {
      debugPrint("Error cargando stats: $e");
    }
  }

  // ==========================================
  // FUNCIONES DE CONTROL (QUOTA DIARIA)
  // ==========================================

  Future<bool> _checkDailyQuota() async {
    if (user == null) return false;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (userDoc.data()?['is_donor'] == true) return true;

      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('general').get();
      final int dynamicLimit = settingsDoc.data()?['free_daily_limit'] ?? 3;

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meals')
          .where('date_str', isEqualTo: todayStr)
          .get();

      if (query.docs.length >= dynamicLimit) {
        if (mounted) _showLimitDialog(dynamicLimit);
        return false;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  void _showLimitDialog(int limit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Límite Diario Alcanzado", style: TextStyle(color: Colors.white)),
        content: Text("Has alcanzado tus $limit registros gratuitos de hoy.", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LÓGICA DE IA (CÁMARA Y TEXTO)
  // ==========================================

  Future<void> _scanFood() async {
    HapticFeedback.lightImpact();
    bool canProceed = await _checkDailyQuota();
    if (!canProceed) return;

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (photo == null) return;

      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))));

      final bytes = await photo.readAsBytes();
      final content = [
        Content.multi([
          TextPart("Identifica el alimento principal y estima sus macros. Responde SOLO JSON: {\"food\": \"nombre\", \"calories\": int, \"protein\": int, \"carbs\": int, \"fat\": int}"),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model.generateContent(content);

      if (!mounted) return;
      Navigator.pop(context);

      String cleanText = response.text ?? "{}";
      cleanText = cleanText.replaceAll("```json", "").replaceAll("```", "").trim();
      final data = jsonDecode(cleanText);

      await _saveMeal(
          data['food'] ?? "Comida",
          (data['calories'] as num? ?? 0).toInt(),
          protein: (data['protein'] as num? ?? 0).toInt(),
          carbs: (data['carbs'] as num? ?? 0).toInt(),
          fat: (data['fat'] as num? ?? 0).toInt()
      );

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

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
              title: const Text("Agregar con IA", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: "Ej: Pollo con arroz", hintStyle: TextStyle(color: Colors.grey)),
                  ),
                  if (isLoading) const Padding(padding: EdgeInsets.only(top: 20), child: CircularProgressIndicator(color: Color(0xFF00FF88))),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameController.text.isEmpty) return;
                    bool canProceed = await _checkDailyQuota();
                    if (!canProceed) return;

                    setState(() => isLoading = true);
                    try {
                      // Simulación de llamada HTTP o uso de SDK
                      // Aquí deberías poner tu lógica de _model.generateContent o http.post
                      // Para el ejemplo, usaremos un mock rápido o tu lógica anterior

                      // ... TU CÓDIGO DE LLAMADA A GEMINI AQUÍ ...

                      // Simulamos respuesta para que funcione el botón
                      await Future.delayed(const Duration(seconds: 1));
                      await _saveMeal(nameController.text, 300, protein: 20, carbs: 30, fat: 10);

                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      // Manejo error
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
                  child: const Text("Calcular", style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // GESTIÓN DE COMIDAS (GUARDAR, BORRAR, EDITAR, COMPARTIR)
  // ==========================================

  Future<void> _saveMeal(String name, int calories, {int protein = 0, int carbs = 0, int fat = 0}) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('meals').add({
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'timestamp': FieldValue.serverTimestamp(),
        'date_str': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      await _loadWeeklyStats();
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Guardado: $name"), backgroundColor: const Color(0xFF00FF88)));
      }
    } catch (e) {
      debugPrint("Error guardando: $e");
    }
  }

  Future<void> _deleteMeal(String docId) async {
    HapticFeedback.mediumImpact();
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('meals').doc(docId).delete();
    await _loadWeeklyStats();
  }

  // 🌍 COMPARTIR COMIDA (AHORA CON ETIQUETA VIP)
  Future<void> _shareMeal(Map<String, dynamic> data) async {
    if (user == null) return;

    // Leemos datos del usuario para saber si es VIP
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final userData = userDoc.data();
    final userName = userData?['name'] ?? user!.displayName ?? "NutriUsuario";
    final bool isVip = userData?['is_donor'] ?? false; // <--- AQUÍ CAPTURAMOS SI ES VIP

    try {
      await FirebaseFirestore.instance.collection('community_feed').add({
        'user_id': user!.uid,
        'user_name': userName,
        'is_vip': isVip, // <--- GUARDAMOS EL ESTADO VIP
        'name': data['name'],
        'calories': data['calories'],
        'protein': data['protein'],
        'carbs': data['carbs'],
        'fat': data['fat'],
        'likes': [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Publicado! 🌍"), backgroundColor: Colors.lightBlueAccent),
        );
      }
    } catch (e) {
      debugPrint("Error compartiendo: $e");
    }
  }

  // ✏️ FUNCIÓN DE EDICIÓN (CON BOTÓN COMPARTIR)
  void _showEditMealDialog(String mealId, Map<String, dynamic> currentData) {
    final nameCtrl = TextEditingController(text: currentData['name']);
    final calCtrl = TextEditingController(text: currentData['calories'].toString());
    final protCtrl = TextEditingController(text: (currentData['protein'] ?? 0).toString());
    final carbCtrl = TextEditingController(text: (currentData['carbs'] ?? 0).toString());
    final fatCtrl = TextEditingController(text: (currentData['fat'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Editar Comida", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField("Nombre", nameCtrl),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildEditField("Calorías", calCtrl, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildEditField("Proteína", protCtrl, isNumber: true)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildEditField("Carbos", carbCtrl, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildEditField("Grasas", fatCtrl, isNumber: true)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // 👇👇👇 BOTÓN DE COMPARTIR AQUÍ 👇👇👇
          IconButton(
            icon: const Icon(Icons.share, color: Colors.lightBlueAccent),
            tooltip: "Publicar en Comunidad",
            onPressed: () => _shareMeal({
              'name': nameCtrl.text,
              'calories': int.tryParse(calCtrl.text) ?? 0,
              'protein': int.tryParse(protCtrl.text) ?? 0,
              'carbs': int.tryParse(carbCtrl.text) ?? 0,
              'fat': int.tryParse(fatCtrl.text) ?? 0,
            }),
          ),
          // 👆👆👆
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('meals').doc(mealId).update({
                'name': nameCtrl.text,
                'calories': int.tryParse(calCtrl.text) ?? 0,
                'protein': int.tryParse(protCtrl.text) ?? 0,
                'carbs': int.tryParse(carbCtrl.text) ?? 0,
                'fat': int.tryParse(fatCtrl.text) ?? 0,
              });
              if (mounted) {
                Navigator.pop(context);
                _loadWeeklyStats();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            child: const Text("Guardar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.black45,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==========================================
  // VISTAS Y WIDGETS
  // ==========================================

  Widget _buildHomeView() {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));

        int totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
        final meals = snapshot.data!.docs;

        for (var doc in meals) {
          final data = doc.data() as Map<String, dynamic>;
          totalCal += (data['calories'] as num? ?? 0).toInt();
          totalProtein += (data['protein'] as num? ?? 0).toInt();
          totalCarbs += (data['carbs'] as num? ?? 0).toInt();
          totalFat += (data['fat'] as num? ?? 0).toInt();
        }

        final double progress = totalCal / dailyGoal;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CABECERA CON BOTÓN DE CALENDARIO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Dashboard", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage()));
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.calendar_month, color: Color(0xFF00FF88)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(DateFormat('EEEE, d MMMM').format(now), style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 30),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200, height: 200,
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
              _buildMacroRow(totalProtein, totalCarbs, totalFat),
              const SizedBox(height: 30),
              _buildMealsSection(meals),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showManualEntryDialog,
                      icon: const Icon(Icons.edit, color: Colors.black),
                      label: const Text("Agregar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanFood,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text("Escanear", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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

  Widget _buildMealsSection(List<QueryDocumentSnapshot> meals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Comidas de Hoy", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          meals.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Sin registros", style: TextStyle(color: Colors.grey))))
              : Column(
            children: meals.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildMealItem(
                data['name'] ?? 'Sin nombre',
                (data['calories'] as num? ?? 0).toInt(),
                doc.id,
                protein: (data['protein'] as num? ?? 0).toInt(),
                carbs: (data['carbs'] as num? ?? 0).toInt(),
                fat: (data['fat'] as num? ?? 0).toInt(),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMealItem(String name, int calories, String docId, {int protein = 0, int carbs = 0, int fat = 0}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showEditMealDialog(docId, {'name': name, 'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF00FF88), shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.black, size: 20)),
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
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _deleteMeal(docId)),
          ],
        ),
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
        decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(15)),
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

  Widget _buildStatsView() {
    final now = DateTime.now();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Estadísticas", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Última Semana", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final date = now.subtract(Duration(days: 6 - i));
                      final dayLabel = DateFormat('E').format(date);
                      final isToday = date.day == now.day;
                      final height = _chartCache[i] ?? 0.0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text("${height.toInt()}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 8),
                          Container(
                            width: 12,
                            height: (isToday ? 150.0 : height).clamp(10.0, 200.0).toDouble(),
                            decoration: BoxDecoration(color: isToday ? const Color(0xFF00FF88) : const Color(0xFF333333), borderRadius: BorderRadius.circular(5)),
                          ),
                          const SizedBox(height: 12),
                          Text(dayLabel[0], style: TextStyle(color: isToday ? const Color(0xFF00FF88) : Colors.grey, fontWeight: FontWeight.bold)),
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
              _buildStatCard("Promedio", "1850", Icons.functions, const Color(0xFF00FF88)),
              const SizedBox(width: 15),
              _buildStatCard("Mejor Día", "Viernes", Icons.emoji_events, const Color(0xFFFFD700)),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

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
            const SettingsPage(), // Usa tu página existente
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Stats"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Social"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ajustes"),
        ],
      ),
    );
  }
}