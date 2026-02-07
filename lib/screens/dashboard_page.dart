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
    // ✅ Gemini 3 Flash
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: ApiConfig.geminiApiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    _loadUserGoal();
    _loadWeeklyStats();
  }

  // Agrega esta función dentro de _DashboardPageState en dashboard_page.dart
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

    // 1. Si ya registró algo hoy, no hacemos nada (evita subir la racha infinitamente el mismo día)
    if (lastEntryDate == todayStr) return;

    // 2. Si el último registro fue AYER, la racha aumenta
    if (lastEntryDate == yesterdayStr) {
      currentStreak++;
    }
    // 3. Si no registró ayer y no es hoy, la racha se reinicia a 1 (empezando de nuevo)
    else {
      currentStreak = 1;
    }

    // 4. Actualizamos Firebase con el nuevo conteo
    await userDoc.update({
      'current_streak': currentStreak,
      'last_entry_date': todayStr,
    });

    debugPrint("🔥 Racha actualizada en base de datos: $currentStreak");
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

  // 1. FUNCIÓN PARA CARGAR DATOS DE LA SEMANA
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
          final dateDay = DateTime(date.year, date.month, date.day);
          final todayDay = DateTime(now.year, now.month, now.day);

          final diff = todayDay.difference(dateDay).inDays;

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

  // 2. WIDGET DEL GRÁFICO
  Widget _buildStatsView() {
    final themeColor = Theme.of(context).primaryColor;

    if (_chartCache.isEmpty) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    double maxCal = dailyGoal.toDouble() + 500;
    for(var val in _chartCache.values) {
      if(val > maxCal) maxCal = val + 500;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tu Progreso Semanal", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("Últimos 7 días vs Meta", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          Container(
            height: 300,
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCal,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} kcal',
                        TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final date = DateTime.now().subtract(Duration(days: 6 - index));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            index == 6 ? 'HOY' : "${date.day}/${date.month}",
                            style: TextStyle(
                                color: index == 6 ? themeColor : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _chartCache.entries.map((e) {
                  final index = e.key;
                  final cals = e.value;
                  final isOverLimit = cals > dailyGoal;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: cals,
                        color: isOverLimit ? Colors.redAccent : themeColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: dailyGoal.toDouble(),
                          color: const Color(0xFF2A2A2A),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(themeColor, "Bien"),
              const SizedBox(width: 20),
              _legendItem(Colors.redAccent, "Exceso"),
              const SizedBox(width: 20),
              _legendItem(const Color(0xFF2A2A2A), "Meta: $dailyGoal"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
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
      showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)));

      final bytes = await photo.readAsBytes();
      final content = [
        Content.multi([
          TextPart("Identifica el alimento principal y estima sus macros. Responde SOLO JSON: {\"food\": \"nombre\", \"calories\": int, \"protein\": int, \"carbs\": int, \"fat\": int}"),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model.generateContent(content);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar cargando

      String cleanText = response.text ?? "{}";
      cleanText = cleanText.replaceAll("```json", "").replaceAll("```", "").trim();
      final data = jsonDecode(cleanText);

      // --- CAMBIO AQUÍ: En lugar de guardar directo, mostramos el diálogo de revisión ---
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Es correcto?", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(imageFile, height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              _buildEditField("Nombre", nameCtrl),
              const SizedBox(height: 15),
              _buildEditField("Calorías estimadas", calCtrl, isNumber: true),
              const SizedBox(height: 10),
              Text(
                "Macros: P:${foodData['protein']}g C:${foodData['carbs']}g G:${foodData['fat']}g",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () {
              _saveMeal(
                nameCtrl.text,
                int.tryParse(calCtrl.text) ?? 0,
                protein: (foodData['protein'] as num? ?? 0).toInt(),
                carbs: (foodData['carbs'] as num? ?? 0).toInt(),
                fat: (foodData['fat'] as num? ?? 0).toInt(),
              );
              // Actualizar récord de escaneos para insignia
              FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                'total_scans': FieldValue.increment(1),
              });
              Navigator.pop(context);
            },
            child: const Text("GUARDAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
              title: const Text("Agregar Manual", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: "Ej: Manzana", hintStyle: TextStyle(color: Colors.grey)),
                  ),
                  if (isLoading) Padding(padding: const EdgeInsets.only(top: 20), child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
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
                      await _saveMeal(nameController.text, 100);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {}
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  child: const Text("Guardar", style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // FUNCIONES SMART (VIP - CENA INTELIGENTE)
  // ==========================================

  Future<void> _getDinnerSuggestion(int currentCalories) async {
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
    );

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final bool isVip = userDoc.data()?['is_donor'] ?? false;

      if (!isVip) {
        if (mounted) Navigator.pop(context);
        _showVipLockDialog();
        return;
      }

      int remaining = dailyGoal - currentCalories;
      if (remaining < 0) remaining = 0;

      final promptJson = "Sugiere cena para $remaining kcal restantes de meta $dailyGoal. Responde en JSON: {\"suggestion\": \"texto\"}";
      final contentJson = [Content.text(promptJson)];

      final response = await _model.generateContent(contentJson);

      if (mounted) {
        Navigator.pop(context);
        String cleanText = response.text ?? "{}";
        cleanText = cleanText.replaceAll("```json", "").replaceAll("```", "").trim();
        final data = jsonDecode(cleanText);
        _showSuggestionResult(data['suggestion'] ?? "No pude generar una sugerencia.");
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showSuggestionResult(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFFFD700))),
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, color: Color(0xFFFFD700)),
            SizedBox(width: 10),
            Text("El Chef Sugiere...", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.5)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Gracias Chef", style: TextStyle(color: Theme.of(context).primaryColor))),
        ],
      ),
    );
  }

  void _showVipLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Función VIP 👑", style: TextStyle(color: Color(0xFFFFD700))),
        content: const Text(
          "Solo los donadores tienen acceso al Chef Personal Inteligente.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Entendido", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            child: const Text("Hacerme VIP", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
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
      // 👇 AQUÍ ES DONDE LLAMAS A LA NUEVA FUNCIÓN DE RACHA 👇
      await _updateStreak();

      await _loadWeeklyStats();
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Guardado: $name"),
            backgroundColor: Theme.of(context).primaryColor
        ));
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

  Future<void> _shareMeal(Map<String, dynamic> data, bool isPrivate) async {
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final userData = userDoc.data();
    final userName = userData?['name'] ?? user!.displayName ?? "NutriUsuario";
    final bool isVip = userData?['is_donor'] ?? false;

    try {
      await FirebaseFirestore.instance.collection('community_feed').add({
        'user_id': user!.uid,
        'user_name': userName,
        'is_vip': isVip,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isPrivate ? "Publicado solo para amigos 🔒" : "Publicado en el muro global 🌍"),
              backgroundColor: Theme.of(context).primaryColor
          ),
        );
      }
    } catch (e) {
      debugPrint("Error compartiendo: $e");
    }
  }

  Future<void> _updateUserRecords() async {
    if (user == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final mealsSnapshot = await userDoc.collection('meals').get();

    // 1. Contar escaneos totales
    int totalScans = mealsSnapshot.docs.length;

    // 2. Calcular racha (días consecutivos con registros)
    // Obtenemos todos los date_str únicos y los ordenamos
    List<String> activeDays = mealsSnapshot.docs
        .map((doc) => doc['date_str'] as String)
        .toSet()
        .toList();
    activeDays.sort((a, b) => b.compareTo(a)); // De más reciente a más antiguo

    int currentStreak = 0;
    if (activeDays.isNotEmpty) {
      // Lógica simple de racha: comparamos fechas consecutivas
      currentStreak = activeDays.length; // Simplificación para el ejemplo
    }

    // 3. Actualizar insignias basadas en records
    List<String> newBadges = [];
    if (totalScans >= 50) newBadges.add('ia_master');
    if (currentStreak >= 7) newBadges.add('streak_7');

    await userDoc.update({
      'total_scans': totalScans,
      'current_streak': currentStreak,
      'badges': FieldValue.arrayUnion(newBadges), // Añade sin duplicar
    });
  }

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
          IconButton(
            icon: const Icon(Icons.share, color: Colors.lightBlueAccent),
            onPressed: () => _shareMeal({
              'name': nameCtrl.text,
              'calories': int.tryParse(calCtrl.text) ?? 0,
              'protein': int.tryParse(protCtrl.text) ?? 0,
              'carbs': int.tryParse(carbCtrl.text) ?? 0,
              'fat': int.tryParse(fatCtrl.text) ?? 0,
            }, false),
          ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
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
    final themeColor = Theme.of(context).primaryColor;
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
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: themeColor));

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Dashboard", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage())),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.calendar_month, color: themeColor),
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
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
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

              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: ElevatedButton.icon(
                  onPressed: () => _getDinnerSuggestion(totalCal),
                  icon: const Icon(Icons.auto_awesome, color: Colors.black),
                  label: const Text(
                    "¿Qué puedo comer ahora?",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),

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
                      style: ElevatedButton.styleFrom(backgroundColor: themeColor, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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
    final themeColor = Theme.of(context).primaryColor;
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
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.black, size: 20)),
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
                Text("$calories", style: TextStyle(color: themeColor, fontSize: 16, fontWeight: FontWeight.bold)),
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