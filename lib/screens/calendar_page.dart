import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Asegúrate de que esta importación sea correcta según tus archivos
import 'settings_page.dart'; // Para redirigir a DonationPage

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Configuración del Calendario
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Datos
  List<DocumentSnapshot> _selectedMeals = [];
  bool _isLoading = false;
  int _totalCalories = 0;

  // VIP Status
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _checkVipStatus();
  }

  // 1. VERIFICAR VIP AL INICIO
  Future<void> _checkVipStatus() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (mounted) {
        setState(() {
          _isVip = doc.data()?['is_donor'] ?? false;
        });
        // Una vez verificado el VIP, cargamos los datos de hoy
        _loadMealsForDay(_focusedDay);
      }
    } catch (e) {
      debugPrint("Error verificando VIP: $e");
      // Si falla, asumimos false por seguridad y cargamos igual
      if (mounted) _loadMealsForDay(_focusedDay);
    }
  }

  // 2. CARGAR COMIDAS CON LÓGICA DE BLOQUEO
  Future<void> _loadMealsForDay(DateTime date) async {
    if (user == null) return;

    // A. LÓGICA DE BLOQUEO (Solo para NO VIPs)
    if (!_isVip) {
      final now = DateTime.now();
      // Normalizamos las fechas para ignorar horas/minutos
      final today = DateTime(now.year, now.month, now.day);
      final checkDate = DateTime(date.year, date.month, date.day);

      final difference = today.difference(checkDate).inDays;

      // Si es historial antiguo (> 7 días), bloqueamos
      if (difference.abs() > 7) {
        setState(() {
          _selectedMeals = [];
          _totalCalories = 0;
        });
        _showHistoryLockDialog();
        return;
      }
    }

    // B. CARGA DE DATOS
    setState(() {
      _isLoading = true;
      _selectedMeals = [];
      _totalCalories = 0;
    });

    try {
      // Usamos el mismo formato que en DashboardPage: yyyy-MM-dd
      final String dateStr = DateFormat('yyyy-MM-dd').format(date);

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meals')
          .where('date_str', isEqualTo: dateStr)
          .get();

      int tempCals = 0;
      for (var doc in query.docs) {
        tempCals += (doc.data()['calories'] as num? ?? 0).toInt();
      }

      if (mounted) {
        setState(() {
          _selectedMeals = query.docs;
          _totalCalories = tempCals;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando historial: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. ALERTA DE BLOQUEO VIP
  void _showHistoryLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Color(0xFFFFD700)),
            SizedBox(width: 10),
            Text("Historial Antiguo", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          "El plan gratuito solo permite ver los últimos 7 días.\n\n"
              "Para analizar tu progreso a largo plazo, hazte VIP.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Asumiendo que DonationPage está en settings_page.dart o impórtala si está aparte
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            child: const Text("Desbloquear", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Capturamos color del tema global
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Historial", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: themeColor),
        actions: [
          if (_isVip)
            Container(
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD700))
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                  SizedBox(width: 5),
                  Text("VIP", style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold))
                ],
              ),
            )
        ],
      ),
      body: Column(
        children: [
          // CALENDARIO VISUAL
          Container(
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              // locale: 'es_ES', // DESCOMENTAR SOLO SI TIENES INTL CONFIGURADO EN MAIN

              // Estilos
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Colors.grey),
                todayDecoration: const BoxDecoration(
                  color: Color(0xFF333333),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              ),

              // Lógica de Selección
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _loadMealsForDay(selectedDay);
                }
              },
            ),
          ),

          const SizedBox(height: 10),

          // RESUMEN TEXTO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay != null ? DateFormat('yyyy-MM-dd').format(_selectedDay!) : "Hoy",
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                Text(
                  "Total: $_totalCalories kcal",
                  style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // LISTA DE RESULTADOS
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: themeColor))
                : _selectedMeals.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    // Icono diferente si está bloqueado o vacío
                      (!_isVip && _selectedDay != null && _selectedDay!.difference(DateTime.now()).inDays.abs() > 7)
                          ? Icons.lock
                          : Icons.no_meals,
                      size: 50,
                      color: Colors.grey.shade800
                  ),
                  const SizedBox(height: 10),
                  Text(
                      (!_isVip && _selectedDay != null && _selectedDay!.difference(DateTime.now()).inDays.abs() > 7)
                          ? "Historial Bloqueado"
                          : "Sin registros",
                      style: const TextStyle(color: Colors.grey)
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _selectedMeals.length,
              itemBuilder: (context, index) {
                final data = _selectedMeals[index].data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: (data['calories'] ?? 0) > 500 ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            shape: BoxShape.circle
                        ),
                        child: Icon(
                            Icons.restaurant,
                            color: (data['calories'] ?? 0) > 500 ? Colors.orange : Colors.green,
                            size: 20
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'] ?? "Comida", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text("P: ${data['protein']} C: ${data['carbs']} G: ${data['fat']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text("${data['calories']} kcal", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}