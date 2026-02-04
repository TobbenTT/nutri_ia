import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // NECESARIO PARA GENERAR EL CÓDIGO ALEATORIO
import 'dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controladores de texto
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  bool _isLoading = false;

  // FUNCIÓN PRINCIPAL DE REGISTRO
  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _heightController.text.isEmpty) {
      _showError("Por favor, llena todos los campos");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Crear usuario en Firebase Authentication (Correo y Contraseña)
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. GENERAR CÓDIGO Y FOTO
            final random = Random();
            final code = (1000 + random.nextInt(9000)).toString();
            final friendCode = "${_nameController.text.trim()}#$code";

      // TRUCO PRO: Generamos una URL de avatar con sus iniciales
      // Usamos el servicio gratuito de ui-avatars.com
            final defaultPhoto = "https://ui-avatars.com/api/?name=${_nameController.text.trim()}&background=random&size=128&color=fff";

      // 3. Guardar en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),

        // NUEVO CAMPO DE FOTO
        'photoUrl': defaultPhoto,

        'age': int.tryParse(_ageController.text) ?? 0,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'height': double.tryParse(_heightController.text) ?? 0.0,
        'friend_code': friendCode,
        'social_score': 0,
        'last_active_day': '',
        'friends': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Todo salió bien, vamos al Dashboard
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("¡Bienvenido! Tu ID es: $friendCode"), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      String msg = "Error al registrarse";
      if (e.code == 'email-already-in-use') msg = "Ese correo ya está registrado.";
      if (e.code == 'weak-password') msg = "La contraseña es muy débil (mínimo 6 caracteres).";
      _showError(msg);
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear Cuenta")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 80, color: Color(0xFF00E676)),
              const SizedBox(height: 20),

              // DATOS PERSONALES
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nombre (Tu Nickname)", prefixIcon: Icon(Icons.badge)),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Correo Electrónico", prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock)),
                obscureText: true,
              ),

              const SizedBox(height: 25),
              const Text("Datos para tu Plan Nutricional", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // DATOS FÍSICOS (En fila para ahorrar espacio)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      decoration: const InputDecoration(labelText: "Edad", suffixText: "años"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      decoration: const InputDecoration(labelText: "Peso", suffixText: "kg"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      decoration: const InputDecoration(labelText: "Altura", suffixText: "cm"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _register,
                  // CORRECCIÓN AQUÍ: El padding va dentro de styleFrom
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: const Color(0xFF00E676), // Color verde
                    foregroundColor: Colors.black, // Texto negro
                  ),
                  child: const Text("REGISTRARME"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}