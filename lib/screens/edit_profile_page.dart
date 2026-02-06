import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        setState(() {
          _nameController.text = doc.data()?['name'] ?? user!.displayName ?? "";
          _goalController.text = (doc.data()?['daily_goal'] ?? 2000).toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    int newGoal = int.tryParse(_goalController.text) ?? 2000;
    if (newGoal < 500) newGoal = 500;
    if (newGoal > 10000) newGoal = 10000;

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'name': _nameController.text.trim(),
      'daily_goal': newGoal,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Perfil actualizado correctamente"),
        backgroundColor: Color(0xFF00FF88),
      ));
      Navigator.pop(context); // Volver atrás al terminar
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Editar Perfil y Metas", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Ajusta tu meta diaria de calorías para que la barra de progreso del inicio sea real.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildField("Tu Nombre", _nameController, false),
            const SizedBox(height: 20),
            _buildField("Meta Calorías (Ej: 2000)", _goalController, true),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
                child: const Text("GUARDAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool isNumber) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF00FF88)), borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}