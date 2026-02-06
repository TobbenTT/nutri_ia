import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Cache para las comidas del día seleccionado
  List<DocumentSnapshot> _selectedMeals = [];
  bool _isLoading = false;
  int _totalCalories = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMealsForDay(_focusedDay);
  }

  // 📥 CARGAR COMIDAS DE UN DÍA ESPECÍFICO
  Future<void> _loadMealsForDay(DateTime date) async {
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _selectedMeals = [];
      _totalCalories = 0;
    });

    try {
      // Convertimos la fecha seleccionada al formato exacto que guardamos en Firebase "yyyy-MM-dd"
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

      setState(() {
        _selectedMeals = query.docs;
        _totalCalories = tempCals;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando historial: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Historial", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. EL CALENDARIO
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

              // Estilos visuales
              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.grey),
                todayDecoration: BoxDecoration(
                  color: Color(0xFF333333),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF00FF88),
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              ),

              // Lógica de selección
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _loadMealsForDay(selectedDay); // Cargar datos al tocar
                }
              },
            ),
          ),

          const SizedBox(height: 10),

          // 2. RESUMEN DEL DÍA
          if (_selectedMeals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM', 'es_ES').format(_selectedDay!), // Requiere inicializar locale si falla, usa solo 'd MMMM'
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Text(
                    "Total: $_totalCalories kcal",
                    style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // 3. LISTA DE COMIDAS
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                : _selectedMeals.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 50, color: Colors.grey.shade800),
                const SizedBox(height: 10),
                const Text("No hay registros este día", style: TextStyle(color: Colors.grey)),
              ],
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
                      // Icono según calorías
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: (data['calories'] ?? 0) > 500
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
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
                            Text(
                              data['name'] ?? "Comida",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "P: ${data['protein']}g  C: ${data['carbs']}g  G: ${data['fat']}g",
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "${data['calories']} kcal",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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