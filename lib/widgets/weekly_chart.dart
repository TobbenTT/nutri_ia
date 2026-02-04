import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class WeeklyChart extends StatefulWidget {
  const WeeklyChart({super.key});

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart> {
  List<double> _weeklyCalories = List.filled(7, 0.0);
  bool _isLoading = true;
  final List<String> _weekDays = [];

  @override
  void initState() {
    super.initState();
    _generateWeekDays();
    _loadWeeklyData();
  }

  // Genera las etiquetas (Lun, Mar, Mie...)
  void _generateWeekDays() {
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      _weekDays.add(DateFormat('E', 'es').format(day)); // Requiere intl configurado en español
    }
  }

  Future<void> _loadWeeklyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime now = DateTime.now();
    DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
    // Normalizamos la fecha para inicio del día
    DateTime startOfPeriod = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
          .get();

      List<double> tempCalories = List.filled(7, 0.0);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final calories = (data['calories'] as num).toDouble();

        // Calculamos la diferencia en días respecto a hoy para saber en qué barra va
        int diff = now.difference(timestamp).inDays;

        // Invertimos el índice (0 es hoy, 6 es hace una semana)
        int index = 6 - diff;

        if (index >= 0 && index < 7) {
          tempCalories[index] += calories;
        }
      }

      if (mounted) {
        setState(() {
          _weeklyCalories = tempCalories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando gráfico: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));

    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
        elevation: 4,
        color: const Color(0xFF1A1A1A), // Fondo oscuro
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Últimos 7 Días", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 20),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 3000, // Tope visual del gráfico (ajustable)
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.black87,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.round()} kcal',
                            const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() < _weekDays.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  _weekDays[value.toInt()][0].toUpperCase(), // Primera letra del día
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: _weeklyCalories.asMap().entries.map((entry) {
                      int idx = entry.key;
                      double val = entry.value;
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: val,
                            color: val > 2000
                                ? Colors.redAccent // Si te pasaste de 2000, rojo
                                : const Color(0xFF00FF88), // Si no, verde
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 3000, // Fondo gris hasta el tope
                              color: Colors.white10,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}