import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _photoController = TextEditingController(); // Nuevo controlador
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _weightController.text = (data['weight'] ?? 0).toString();
          _heightController.text = (data['height'] ?? 0).toString();
          _ageController.text = (data['age'] ?? 0).toString();
          _photoController.text = data['photoUrl'] ?? ""; // Cargar URL actual
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'weight': double.tryParse(_weightController.text) ?? 0,
        'height': double.tryParse(_heightController.text) ?? 0,
        'age': int.tryParse(_ageController.text) ?? 0,
        'photoUrl': _photoController.text.trim(), // Guardar nueva URL
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Perfil actualizado!"), backgroundColor: Color(0xFF00FF88)),
        );
        Navigator.pop(context);
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView( // Scroll por si el teclado tapa
          child: Column(
            children: [
              // Previsualización de la foto
              CircleAvatar(
                radius: 40,
                backgroundImage: _photoController.text.isNotEmpty
                    ? NetworkImage(_photoController.text)
                    : null,
                child: _photoController.text.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(height: 20),

              const Text("Foto de Perfil (URL)", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 5),
              TextField(
                controller: _photoController,
                decoration: const InputDecoration(
                  hintText: "Pega aquí un link de imagen (jpg/png)",
                  prefixIcon: Icon(Icons.link),
                ),
                onChanged: (val) => setState((){}), // Para actualizar la vista previa
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.grey),
              const SizedBox(height: 20),

              _buildInput("Peso (kg)", _weightController, Icons.monitor_weight),
              const SizedBox(height: 15),
              _buildInput("Altura (cm)", _heightController, Icons.height),
              const SizedBox(height: 15),
              _buildInput("Edad", _ageController, Icons.cake),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("GUARDAR CAMBIOS"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}