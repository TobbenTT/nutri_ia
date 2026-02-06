import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart'; // Asegúrate de importar tu login para redirigir al salir

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Controladores para editar
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();

  bool _isDonor = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // 📥 CARGAR DATOS DE FIREBASE
  Future<void> _loadUserProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? user!.displayName ?? "Usuario";
          _goalController.text = (data['daily_goal'] ?? 2000).toString();
          _isDonor = data['is_donor'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
      setState(() => _isLoading = false);
    }
  }

  // 💾 GUARDAR CAMBIOS
  Future<void> _saveProfile() async {
    if (user == null) return;

    // Validación básica
    int newGoal = int.tryParse(_goalController.text) ?? 2000;
    if (newGoal < 500) newGoal = 500; // Mínimo de seguridad
    if (newGoal > 10000) newGoal = 10000; // Máximo lógico

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _nameController.text.trim(),
        'daily_goal': newGoal,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado ✅"), backgroundColor: Color(0xFF00FF88)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // 🚪 CERRAR SESIÓN
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. AVATAR Y ESTADO
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _isDonor ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                          width: 3
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: _isDonor ? Colors.amber.withOpacity(0.5) : Colors.green.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2
                        )
                      ]
                  ),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF1E1E1E),
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
                if (_isDonor)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD700),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, color: Colors.black, size: 20),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 15),
            Text(
              _isDonor ? "MIEMBRO VIP 👑" : "Usuario Estándar",
              style: TextStyle(
                  color: _isDonor ? const Color(0xFFFFD700) : Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5
              ),
            ),

            const SizedBox(height: 40),

            // 2. FORMULARIO DE EDICIÓN
            _buildTextField("Nombre", _nameController, Icons.person_outline),
            const SizedBox(height: 20),
            _buildTextField("Meta de Calorías Diaria", _goalController, Icons.flag_outlined, isNumber: true),

            const SizedBox(height: 10),
            const Text(
              "Esta meta actualizará tu barra de progreso en el Dashboard.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 40),

            // 3. BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                  shadowColor: const Color(0xFF00FF88).withOpacity(0.4),
                ),
                child: const Text(
                  "GUARDAR CAMBIOS",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}