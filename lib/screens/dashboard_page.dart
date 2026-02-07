import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:fl_chart/fl_chart.dart';

// --- IMPORTACIONES PROPIAS ---
import 'social_page.dart';
import 'settings_page.dart';
import 'calendar_page.dart';
import 'hydration_section.dart'; // Asegúrate de tener este archivo
import 'api_config.dart';
import 'barcode_scanner_page.dart'; // ✅ AGREGAR ESTO

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // IA Y UTILIDADES
  late final GenerativeModel _model;
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;

  // ESTADO
  int dailyGoal = 2000;
  final Map<int, double> _chartCache = {};

  @override
  void initState() {
    super.initState();
    // Configuración de Gemini
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: ApiConfig.geminiApiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    _loadUserGoal();
    _loadWeeklyStats();
  }

  // ==========================================
  // 1. LÓGICA DE CARGA Y RACHAS
  // ==========================================

  Future<void> _updateStreak() async {
    if (user == null) return;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    final snapshot = await userDoc.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>;
    int currentStreak = data['current_streak'] ?? 0;
    String lastEntryDate = data['last_entry_date'] ?? "";

    if (lastEntryDate == todayStr) return; // Ya contó hoy

    if (lastEntryDate == yesterdayStr) {
      currentStreak++; // Racha continúa
    } else {
      currentStreak = 1; // Racha rota o nuevo inicio
    }

    await userDoc.update({
      'current_streak': currentStreak,
      'last_entry_date': todayStr,
    });
  }

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

  Future<void> _loadWeeklyStats() async {
    if (user == null) return;
    Map<int, double> tempStats = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    final now = DateTime.now();
    final startOfPeriod = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(user!.uid).collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? ts = data['timestamp'];
        final int cals = (data['calories'] as num? ?? 0).toInt();

        if (ts != null) {
          final date = ts.toDate();
          final diff = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
          if (diff >= 0 && diff <= 6) {
            int chartIndex = 6 - diff;
            tempStats[chartIndex] = (tempStats[chartIndex] ?? 0) + cals;
          }
        }
      }
      if (mounted) setState(() => _chartCache.addAll(tempStats));
    } catch (e) {
      debugPrint("Error stats: $e");
    }
  }

  // ==========================================
  // 2. LÓGICA DE IA (ESCÁNER CON MICROS 🍎)
  // ==========================================

  Future<void> _scanFood() async {
    HapticFeedback.lightImpact();

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (photo == null) return;

      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)));

      final bytes = await photo.readAsBytes();

      // 🔥 PROMPT ACTUALIZADO: Pide Micros (Azúcar, Fibra, Sodio)
      final content = [
        Content.multi([
          TextPart("Analiza esta comida. Responde SOLO JSON: {\"food\": \"nombre corto\", \"calories\": int, \"protein\": int, \"carbs\": int, \"fat\": int, \"sugar\": int, \"fiber\": int, \"sodium\": int}"),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model.generateContent(content);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      String cleanText = response.text ?? "{}";
      cleanText = cleanText.replaceAll("```json", "").replaceAll("```", "").trim();
      final data = jsonDecode(cleanText);

      _showFoodReviewDialog(data, File(photo.path));

    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error IA: $e")));
      }
    }
  }

  void _showFoodReviewDialog(Map<String, dynamic> foodData, File imageFile) {
    final nameCtrl = TextEditingController(text: foodData['food'] ?? "Comida");
    final calCtrl = TextEditingController(text: (foodData['calories'] ?? 0).toString());
    final protCtrl = TextEditingController(text: (foodData['protein'] ?? 0).toString());
    final carbCtrl = TextEditingController(text: (foodData['carbs'] ?? 0).toString());
    final fatCtrl = TextEditingController(text: (foodData['fat'] ?? 0).toString());
    final sugarCtrl = TextEditingController(text: (foodData['sugar'] ?? 0).toString());
    final fiberCtrl = TextEditingController(text: (foodData['fiber'] ?? 0).toString());
    final sodCtrl = TextEditingController(text: (foodData['sodium'] ?? 0).toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Revisar Datos", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(imageFile, height: 120, width: double.infinity, fit: BoxFit.cover)),
              const SizedBox(height: 15),
              _buildEditField("Nombre", nameCtrl),
              const SizedBox(height: 10),
              _buildEditField("Calorías", calCtrl, isNumber: true),
              const SizedBox(height: 10),

              const Text("Macros (g)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Row(children: [
                Expanded(child: _buildEditField("Prot", protCtrl, isNumber: true)),
                const SizedBox(width: 5),
                Expanded(child: _buildEditField("Carb", carbCtrl, isNumber: true)),
                const SizedBox(width: 5),
                Expanded(child: _buildEditField("Grasa", fatCtrl, isNumber: true))
              ]),

              const SizedBox(height: 10),
              const Text("Micros", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Row(children: [
                Expanded(child: _buildEditField("Azúcar(g)", sugarCtrl, isNumber: true)),
                const SizedBox(width: 5),
                Expanded(child: _buildEditField("Fibra(g)", fiberCtrl, isNumber: true))
              ]),
              const SizedBox(height: 5),
              _buildEditField("Sodio(mg)", sodCtrl, isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () {
              _saveMeal(
                nameCtrl.text,
                int.tryParse(calCtrl.text) ?? 0,
                protein: int.tryParse(protCtrl.text) ?? 0,
                carbs: int.tryParse(carbCtrl.text) ?? 0,
                fat: int.tryParse(fatCtrl.text) ?? 0,
                sugar: int.tryParse(sugarCtrl.text) ?? 0,
                fiber: int.tryParse(fiberCtrl.text) ?? 0,
                sodium: int.tryParse(sodCtrl.text) ?? 0,
              );
              FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'total_scans': FieldValue.increment(1)});
              Navigator.pop(context);
            },
            child: const Text("GUARDAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. GESTIÓN DE COMIDAS (CRUD)
  // ==========================================

  Future<void> _saveMeal(String name, int calories, {
    int protein = 0, int carbs = 0, int fat = 0,
    int sugar = 0, int fiber = 0, int sodium = 0
  }) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('meals').add({
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'sugar': sugar,
        'fiber': fiber,
        'sodium': sodium,
        'timestamp': FieldValue.serverTimestamp(),
        'date_str': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      await _updateStreak();
      await _loadWeeklyStats();
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Guardado: $name"), backgroundColor: Theme.of(context).primaryColor));
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

  void _showEditMealDialog(String mealId, Map<String, dynamic> currentData) {
    final nameCtrl = TextEditingController(text: currentData['name']);
    final calCtrl = TextEditingController(text: currentData['calories'].toString());
    final protCtrl = TextEditingController(text: (currentData['protein'] ?? 0).toString());
    final carbCtrl = TextEditingController(text: (currentData['carbs'] ?? 0).toString());
    final fatCtrl = TextEditingController(text: (currentData['fat'] ?? 0).toString());
    final sugarCtrl = TextEditingController(text: (currentData['sugar'] ?? 0).toString());
    final fiberCtrl = TextEditingController(text: (currentData['fiber'] ?? 0).toString());
    final sodCtrl = TextEditingController(text: (currentData['sodium'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Editar Detalles", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField("Nombre", nameCtrl),
              const SizedBox(height: 10),
              _buildEditField("Calorías", calCtrl, isNumber: true),
              const Divider(color: Colors.grey),
              const Text("Macros", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Row(children: [Expanded(child: _buildEditField("P", protCtrl, isNumber: true)), const SizedBox(width: 5), Expanded(child: _buildEditField("C", carbCtrl, isNumber: true)), const SizedBox(width: 5), Expanded(child: _buildEditField("G", fatCtrl, isNumber: true))]),
              const SizedBox(height: 10),
              const Text("Micros", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Row(children: [Expanded(child: _buildEditField("Azúcar", sugarCtrl, isNumber: true)), const SizedBox(width: 5), Expanded(child: _buildEditField("Fibra", fiberCtrl, isNumber: true))]),
              const SizedBox(height: 5),
              _buildEditField("Sodio (mg)", sodCtrl, isNumber: true),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.lightBlueAccent),
            onPressed: () => _shareMeal({'name': nameCtrl.text, 'calories': int.tryParse(calCtrl.text) ?? 0, 'protein': int.tryParse(protCtrl.text) ?? 0, 'carbs': int.tryParse(carbCtrl.text) ?? 0, 'fat': int.tryParse(fatCtrl.text) ?? 0}, false),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('meals').doc(mealId).update({
                'name': nameCtrl.text,
                'calories': int.tryParse(calCtrl.text) ?? 0,
                'protein': int.tryParse(protCtrl.text) ?? 0,
                'carbs': int.tryParse(carbCtrl.text) ?? 0,
                'fat': int.tryParse(fatCtrl.text) ?? 0,
                'sugar': int.tryParse(sugarCtrl.text) ?? 0,
                'fiber': int.tryParse(fiberCtrl.text) ?? 0,
                'sodium': int.tryParse(sodCtrl.text) ?? 0,
              });
              if (mounted) {
                Navigator.pop(context);
                _loadWeeklyStats();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: const Text("Guardar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Agregar Rápido", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField("Nombre", nameCtrl),
              const SizedBox(height: 10),
              _buildEditField("Calorías", calCtrl, isNumber: true),
              const SizedBox(height: 10),
              const Text("Para más detalles (azúcar, fibra), usa el botón de editar después.", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                _saveMeal(nameCtrl.text, int.tryParse(calCtrl.text) ?? 0);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              child: const Text("Guardar", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareMeal(Map<String, dynamic> data, bool isPrivate) async {
    if (user == null) return;
    final userData = (await FirebaseFirestore.instance.collection('users').doc(user!.uid).get()).data();

    try {
      await FirebaseFirestore.instance.collection('community_feed').add({
        'user_id': user!.uid,
        'user_name': userData?['name'] ?? "NutriUsuario",
        'user_photo': userData?['photoUrl'],
        'active_hat': userData?['active_hat'],
        'is_vip': userData?['is_donor'] ?? false,
        'name': data['name'],
        'calories': data['calories'],
        'protein': data['protein'],
        'carbs': data['carbs'],
        'fat': data['fat'],
        'likes': [],
        'is_private': isPrivate,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPrivate ? "Privado 🔒" : "Publicado 🌍"), backgroundColor: Theme.of(context).primaryColor));
      }
    } catch (e) {
      debugPrint("Error compartiendo: $e");
    }
  }

  Future<void> _getDinnerSuggestion(int currentCalories) async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Chef IA 👨‍🍳", style: TextStyle(color: Colors.white)),
          content: const Text("¿Quieres una sugerencia basada en tus calorías restantes?", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("No", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡El Chef está pensando en tu menú!")));
              },
              child: const Text("Sugerir", style: TextStyle(color: Colors.black)),
            )
          ],
        )
    );
  }

  // ==========================================
  // 4. WIDGETS AUXILIARES
  // ==========================================

  Widget _buildEditField(String label, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.black45,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // WIDGET DEL GRÁFICO
  Widget _buildStatsView() {
    final themeColor = Theme.of(context).primaryColor;
    if (_chartCache.isEmpty) return Center(child: CircularProgressIndicator(color: themeColor));

    double maxCal = dailyGoal.toDouble() + 500;
    for(var val in _chartCache.values) if(val > maxCal) maxCal = val + 500;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tu Progreso Semanal", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Container(
            height: 300,
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 0),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCal,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${rod.toY.toInt()} kcal', TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    final date = DateTime.now().subtract(Duration(days: 6 - index));
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(index == 6 ? 'HOY' : "${date.day}/${date.month}", style: TextStyle(color: index == 6 ? themeColor : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)));
                  }, reservedSize: 30)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: _chartCache.entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(toY: e.value, color: e.value > dailyGoal ? Colors.redAccent : themeColor, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)), backDrawRodData: BackgroundBarChartRodData(show: true, toY: dailyGoal.toDouble(), color: const Color(0xFF2A2A2A))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // VISTA PRINCIPAL (HOME)
  // VISTA PRINCIPAL (HOME)
  Widget _buildHomeView() {
    final themeColor = Theme.of(context).primaryColor;
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: themeColor));

        int totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
        int totalSugar = 0, totalFiber = 0, totalSodium = 0;

        final meals = snapshot.data!.docs;

        for (var doc in meals) {
          final data = doc.data() as Map<String, dynamic>;
          totalCal += (data['calories'] as num? ?? 0).toInt();
          totalProtein += (data['protein'] as num? ?? 0).toInt();
          totalCarbs += (data['carbs'] as num? ?? 0).toInt();
          totalFat += (data['fat'] as num? ?? 0).toInt();
          // Suma de Micros
          totalSugar += (data['sugar'] as num? ?? 0).toInt();
          totalFiber += (data['fiber'] as num? ?? 0).toInt();
          totalSodium += (data['sodium'] as num? ?? 0).toInt();
        }
        final double progress = totalCal / dailyGoal;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Dashboard", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage())), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.calendar_month, color: themeColor))),
                ],
              ),
              const SizedBox(height: 10),
              Text(DateFormat('EEEE, d MMMM').format(now), style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 30),

              // CIRCULO CALORIAS
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(width: 200, height: 200, child: CircularProgressIndicator(value: progress.clamp(0.0, 1.0), strokeWidth: 15, backgroundColor: Colors.grey.shade800, valueColor: AlwaysStoppedAnimation<Color>(themeColor))),
                    Column(mainAxisSize: MainAxisSize.min, children: [Text("$totalCal", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)), Text("de $dailyGoal kcal", style: const TextStyle(color: Colors.grey, fontSize: 14))]),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 1. FILA DE MACROS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCard("Prot", totalProtein, "g", Icons.fitness_center, const Color(0xFFFF6B6B)),
                  _buildCard("Carbs", totalCarbs, "g", Icons.bakery_dining, const Color(0xFF4ECDC4)),
                  _buildCard("Grasa", totalFat, "g", Icons.water_drop, const Color(0xFFFFD93D)),
                ],
              ),
              const SizedBox(height: 15),

              // 2. 🔥 NUEVA FILA DE MICROS (VISUAL)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCard("Azúcar", totalSugar, "g", Icons.icecream, Colors.pinkAccent),
                  _buildCard("Fibra", totalFiber, "g", Icons.grass, Colors.greenAccent),
                  _buildCard("Sodio", totalSodium, "mg", Icons.grain, Colors.grey),
                ],
              ),

              const SizedBox(height: 30),

              // SECCIÓN HIDRATACIÓN
              const HydrationSection(),

              const SizedBox(height: 30),

              // Sugerencia Chef
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: ElevatedButton.icon(
                  onPressed: () => _getDinnerSuggestion(totalCal),
                  icon: const Icon(Icons.auto_awesome, color: Colors.black),
                  label: const Text("Sugerencia del Chef", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
              const SizedBox(height: 30),

              // LISTA DE COMIDAS
              _buildMealsSection(meals),

              const SizedBox(height: 30),

              // -------------------------------------------------------------
              // 🔥 NUEVA FILA DE BOTONES CON ESCÁNER DE CÓDIGO DE BARRAS
              // -------------------------------------------------------------
              Row(
                children: [
                  // 1. MANUAL
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showManualEntryDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Column(children: [Icon(Icons.edit, color: Colors.black), Text("Manual", style: TextStyle(color: Colors.black, fontSize: 10))]),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 2. FOTO IA
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _scanFood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Column(children: [Icon(Icons.camera_alt, color: Colors.white), Text("Foto IA", style: TextStyle(color: Colors.white, fontSize: 10))]),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 3. BARCODE (NUEVO)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Navegar al escáner y esperar datos
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
                        );
                        // Si volvió con datos, abrimos el diálogo de editar/guardar
                        if (result != null && result is Map<String, dynamic>) {
                          _showEditMealDialog("new_scan", result);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Column(children: [Icon(Icons.qr_code_scanner, color: Colors.white), Text("Barcode", style: TextStyle(color: Colors.white, fontSize: 10))]),
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

  // TARJETA DE INFO NUTRICIONAL
  Widget _buildCard(String name, int value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(15)),
        child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 5), Text("$value$unit", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), Text(name, style: const TextStyle(color: Colors.grey, fontSize: 10))]),
      ),
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
          meals.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Sin registros", style: TextStyle(color: Colors.grey)))) : Column(children: meals.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildMealItem(data, doc.id);
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildMealItem(Map<String, dynamic> data, String docId) {
    final themeColor = Theme.of(context).primaryColor;
    final name = data['name'] ?? 'Sin nombre';
    final calories = (data['calories'] as num? ?? 0).toInt();

    // 🔥 Leemos los micros (puede que no existan en comidas viejas)
    final sugar = (data['sugar'] as num? ?? 0).toInt();
    final fiber = (data['fiber'] as num? ?? 0).toInt();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showEditMealDialog(docId, data);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.black, size: 20)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("P: ${data['protein']} C: ${data['carbs']} G: ${data['fat']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  // 🔥 ALERTA VISUAL + DETALLE
                  if (sugar > 0 || fiber > 0)
                    Text("Azúcar: ${sugar}g • Fibra: ${fiber}g", style: TextStyle(color: sugar > 10 ? Colors.orangeAccent : Colors.grey.shade600, fontSize: 10, fontWeight: sugar > 10 ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("$calories", style: TextStyle(color: themeColor, fontSize: 16, fontWeight: FontWeight.bold)), const Text("kcal", style: TextStyle(color: Colors.grey, fontSize: 10))]),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _deleteMeal(docId)),
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
            const SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: const Color(0xFF0A0A0A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
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