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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Aquí guardaremos las comidas agrupadas por fecha
  Map<DateTime, List<Map<String, dynamic>>> _mealsByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadHistory();
  }

  // 1. Descargar TODO el historial y organizarlo por días
  Future<void> _loadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .orderBy('timestamp', descending: true)
          .get();

      Map<DateTime, List<Map<String, dynamic>>> tempMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? ts = data['timestamp'];
        if (ts == null) continue;

        // Convertimos a fecha "pura" (sin hora) para que coincida con el calendario
        final date = ts.toDate();
        final dateKey = DateTime(date.year, date.month, date.day);

        if (tempMap[dateKey] == null) {
          tempMap[dateKey] = [];
        }
        tempMap[dateKey]!.add(data);
      }

      setState(() {
        _mealsByDate = tempMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando historial: $e");
      setState(() => _isLoading = false);
    }
  }

  // Función para obtener eventos de un día específico
  List<Map<String, dynamic>> _getMealsForDay(DateTime day) {
    // Normalizamos la fecha para quitar la hora y buscar en el mapa
    final dateKey = DateTime(day.year, day.month, day.day);
    return _mealsByDate[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos totales del día seleccionado
    final selectedMeals = _getMealsForDay(_selectedDay ?? DateTime.now());
    int totalCals = 0;
    for (var m in selectedMeals) totalCals += (m['calories'] as num? ?? 0).toInt();

    return Scaffold(
      appBar: AppBar(title: const Text("Historial")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : Column(
        children: [
          // CALENDARIO
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getMealsForDay, // Esto pone los puntitos automáticamente

            // Estilo del Calendario
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Color(0xFF00E676), // Puntito verde si hay comida
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),

          const Divider(height: 30),

          // RESUMEN DEL DÍA SELECCIONADO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE d, MMMM', 'es').format(_selectedDay!),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // CORRECTO
                ),
                Text(
                  "Total: $totalCals kcal",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // LISTA DE COMIDAS DE ESE DÍA
          Expanded(
            child: selectedMeals.isEmpty
                ? const Center(child: Text("No hay registros este día.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: selectedMeals.length,
              itemBuilder: (context, index) {
                final meal = selectedMeals[index];
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.restaurant, color: Colors.white54),
                    title: Text(meal['name'] ?? "Comida"),
                    subtitle: Text("${meal['calories']} kcal"),
                    trailing: Text(
                      "${meal['protein']}p ${meal['carbs']}c ${meal['fat']}f",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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