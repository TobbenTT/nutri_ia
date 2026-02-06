import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart'; // Asegúrate de tener este archivo para navegar al final

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controladores de texto para los campos
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  bool _isLoading = false;

  Future<void> _register() async {
    // 1. Validaciones simples
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _heightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, llena todos los campos.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Crear usuario en Firebase Authentication (Correo y Contraseña)
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. Guardar datos físicos y configuración en Firestore (Base de Datos)
      // AQUÍ ES DONDE OCURRE LA MAGIA PARA EVITAR EL ERROR DEL PLAN GRATUITO
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),

        // Datos Físicos (Convertimos texto a número)
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'height': double.tryParse(_heightController.text.trim()) ?? 0.0,

        // --- CONFIGURACIÓN POR DEFECTO (CRUCIAL) ---
        'is_donor': false,    // Nace como usuario GRATIS
        'social_score': 0,    // Puntos iniciales
        'created_at': FieldValue.serverTimestamp(),
        // --------------------------------------------
      });

      // 4. Si todo salió bien, vamos al Dashboard
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      String msg = "Error al registrarse";
      if (e.code == 'email-already-in-use') msg = "Este correo ya está registrado.";
      if (e.code == 'weak-password') msg = "La contraseña es muy débil (mínimo 6 caracteres).";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                "Únete a Nutri_IA",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // CAMPO NOMBRE
              _buildTextField(_nameController, "Nombre completo", Icons.person),
              const SizedBox(height: 15),

              // CAMPO CORREO
              _buildTextField(_emailController, "Correo electrónico", Icons.email, isEmail: true),
              const SizedBox(height: 15),

              // CAMPO CONTRASEÑA
              _buildTextField(_passwordController, "Contraseña", Icons.lock, isPassword: true),
              const SizedBox(height: 15),

              // FILA: EDAD, PESO, ALTURA
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

              // BOTÓN REGISTRAR
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

  // Widget auxiliar para no repetir código de inputs
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