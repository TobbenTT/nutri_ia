import 'dart:math'; // 1. IMPORTANTE: Agrega esto al inicio
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  bool _isLoading = false;

  // 2. NUEVA FUNCIÓN: Generar código único (Ej: David#4521)
  String _generateFriendCode(String name) {
    final random = Random();
    final number = 1000 + random.nextInt(9000); // Número entre 1000 y 9999
    // Tomamos la primera palabra del nombre y quitamos símbolos raros
    final cleanName = name.split(' ')[0].replaceAll(RegExp(r'[^\w\s]+'), '');
    return "$cleanName#$number";
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final ageText = _ageController.text.trim();
    final weightText = _weightController.text.trim();
    final heightText = _heightController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty ||
        ageText.isEmpty || weightText.isEmpty || heightText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, llena todos los campos.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 3. GENERAMOS EL ID ANTES DE GUARDAR
      final String myFriendCode = _generateFriendCode(name);

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'friend_code': myFriendCode, // ✅ AQUÍ GUARDAMOS LA ID
        'photoUrl': "",
        'active_hat': null,

        'age': int.tryParse(ageText) ?? 0,
        'weight': double.tryParse(weightText) ?? 0.0,
        'height': double.tryParse(heightText) ?? 0.0,

        'is_donor': false,
        'social_score': 0,
        'is_beta_user': true,
        'badges': ['beta_founder'],
        'current_streak': 0,
        'total_scans': 0,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      String msg = "Error al registrarse";
      if (e.code == 'email-already-in-use') msg = "Este correo ya está registrado.";
      if (e.code == 'invalid-email') msg = "El formato del correo es incorrecto.";
      if (e.code == 'weak-password') msg = "La contraseña debe tener al menos 6 caracteres.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error inesperado: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... TU CÓDIGO UI EXISTENTE (NO CAMBIA) ...
    // Solo asegúrate de copiar el build completo que ya tenías
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Crear Cuenta", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 80, color: Color(0xFF00FF88)),
              const SizedBox(height: 20),
              const Text("Únete a Nutri_IA", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              _buildTextField(_nameController, "Nombre completo", Icons.person),
              const SizedBox(height: 15),
              _buildTextField(_emailController, "Correo electrónico", Icons.email, isEmail: true),
              const SizedBox(height: 15),
              _buildTextField(_passwordController, "Contraseña", Icons.lock, isPassword: true),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField(_ageController, "Edad", Icons.cake, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(_weightController, "Peso (kg)", Icons.monitor_weight, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(_heightController, "Altura (cm)", Icons.height, isNumber: true)),
                ],
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFF00FF88))
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("REGISTRARME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon,
      {bool isPassword = false, bool isNumber = false, bool isEmail = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isNumber
          ? TextInputType.number
          : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF00FF88)),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00FF88)),
        ),
      ),
    );
  }
}