import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback

class HydrationSection extends StatefulWidget {
  const HydrationSection({super.key});

  @override
  State<HydrationSection> createState() => _HydrationSectionState();
}

class _HydrationSectionState extends State<HydrationSection> {
  final User? user = FirebaseAuth.instance.currentUser;
  final int waterGoal = 2500; // Meta fija de 2.5L

  // ==========================================
  // LÓGICA DE AGREGAR LÍQUIDOS
  // ==========================================

  Future<void> _addLiquid(String type, int mlPorUnidad, int calsPorUnidad, int cantidad) async {
    if (user == null) return;
    HapticFeedback.mediumImpact();

    final int totalMl = mlPorUnidad * cantidad;
    final int totalCals = calsPorUnidad * cantidad;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // 1. Guardar registro de líquido
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('liquids')
          .add({
        'type': type,
        'quantity': cantidad, // Guardamos cuántos fueron
        'ml': totalMl,
        'calories': totalCals,
        'date_str': todayStr,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Si tiene calorías, guardar TAMBIÉN como COMIDA
      if (totalCals > 0) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('meals')
            .add({
          'name': "$type (x$cantidad)",
          'calories': totalCals,
          'protein': 0,
          'carbs': (totalCals / 4).round(),
          'fat': 0,
          'timestamp': FieldValue.serverTimestamp(),
          'date_str': todayStr,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Hidratación + $totalCals kcal agregadas ⚡"),
            backgroundColor: Colors.orangeAccent,
          ));
        }
      }
    } catch (e) {
      debugPrint("Error al guardar líquido: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error de permisos: Revisa Firebase Console"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // DIÁLOGO PARA PREGUNTAR CANTIDAD
  void _showQuantityDialog(String name, int ml, int cals, IconData icon, Color color) {
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Text(name, style: const TextStyle(color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("¿Cuántas unidades?", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _circleBtn(Icons.remove, () {
                        if (quantity > 1) setDialogState(() => quantity--);
                      }),
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(
                          "$quantity",
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _circleBtn(Icons.add, () {
                        if (quantity < 10) setDialogState(() => quantity++);
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Total: ${ml * quantity} ml ${cals > 0 ? '(+${cals * quantity} kcal)' : ''}",
                    style: TextStyle(color: color.withOpacity(0.8), fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Cierra dialogo cantidad
                    Navigator.pop(context); // Cierra bottom sheet menú
                    _addLiquid(name, ml, cals, quantity);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: const Text("AGREGAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  void _showLiquidEntryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text("Registrar Hidratación",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 20),

                // Usamos Wrap para que los botones se acomoden automáticamente y no causen overflow
                Center(
                  child: Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    alignment: WrapAlignment.center,
                    children: [
                      _liquidOption("Agua", Icons.water_drop, Colors.cyan, 250, 0),
                      _liquidOption("Café/Té", Icons.coffee, Colors.brown, 250, 5),
                      _liquidOption("Bebida", Icons.local_drink, Colors.purpleAccent, 330, 140),
                      _liquidOption("Energética", Icons.bolt, Colors.amber, 250, 110),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _liquidOption(String name, IconData icon, Color color, int ml, int cals) {
    return GestureDetector(
      onTap: () => _showQuantityDialog(name, ml, cals, icon, color),
      child: Container(
        width: 150, // Ancho fijo para uniformidad
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("$ml ml", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (cals > 0)
              Text("+$cals kcal", style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox();

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('liquids')
          .where('date_str', isEqualTo: dateStr)
          .snapshots(),
      builder: (context, snapshot) {
        int totalMl = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            totalMl += (doc['ml'] as num).toInt();
          }
        }

        double progress = (totalMl / waterGoal).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 40),
              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Hidratación", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("$totalMl / $waterGoal ml", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.black,
                      color: Colors.cyanAccent,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              IconButton(
                onPressed: _showLiquidEntryDialog,
                icon: const Icon(Icons.add_circle, color: Colors.cyanAccent, size: 35),
              )
            ],
          ),
        );
      },
    );
  }
}