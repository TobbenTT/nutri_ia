import 'package:flutter/material.dart';

class FoodLogPage extends StatelessWidget {
  const FoodLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Comidas de Hoy",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildFoodItem("Desayuno", "Avena con plátano", "350 kcal"),
          _buildFoodItem("Almuerzo", "Pollo con arroz", "600 kcal"),
          _buildFoodItem("Snack", "Manzana", "80 kcal"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodDialog(context), // Llamamos a la función
        child: const Icon(Icons.add),
        tooltip: 'Añadir alimento',
      ),
    );
  }

  Widget _buildFoodItem(String category, String name, String calories) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.fastfood, color: Colors.green),
        title: Text(name),
        subtitle: Text(category),
        trailing: Text(
          calories,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }
  void _showAddFoodDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que suba con el teclado
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Ajuste para el teclado
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Registrar Alimento", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextField(
                decoration: const InputDecoration(labelText: "Nombre del alimento"),
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Calorías (kcal)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Guardar"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}