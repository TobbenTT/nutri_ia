import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'dashboard_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final LocalAuthentication auth = LocalAuthentication();

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _goToDashboard();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Error al entrar");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- BIOMETRÍA UNIVERSAL (SIN CONFIGURACIONES QUE DEN ERROR) ---
  Future<void> _authenticateBiometric() async {
    try {
      // 1. Verificamos si hay sensor (Compatible con todas las versiones)
      final bool canCheck = await auth.canCheckBiometrics;
      if (!canCheck) {
        _showError("Tu celular no tiene biometría activa.");
        return;
      }

      // 2. Autenticación BÁSICA
      // Al no pasarle "options" ni "stickyAuth", usa la configuración por defecto.
      // ESTO FUNCIONA EN CUALQUIER VERSIÓN DE LA LIBRERÍA.
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Toca el sensor para entrar a Nutri_IA',
      );

      if (didAuthenticate) {
        // Solo dejamos pasar si ya existe un usuario recordado por Firebase
        if (FirebaseAuth.instance.currentUser != null) {
          _goToDashboard();
        } else {
          _showError("Por seguridad, inicia sesión con contraseña primero.");
        }
      }
    } catch (e) {
      // Ignoramos el error técnico y solo avisamos
      debugPrint("Error Auth: $e");
      _showError("No se pudo leer la huella.");
    }
  }

  void _goToDashboard() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
      );
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint, size: 80, color: Color(0xFF00E676)),
                const SizedBox(height: 20),
                const Text("Bienvenido", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Correo", prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock)),
                  obscureText: true,
                ),
                const SizedBox(height: 25),

                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF00E676))
                    : Column(
                  children: [
                    // Botón corregido (Sin el error de padding)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text("ENTRAR"),
                      ),
                    ),
                    const SizedBox(height: 20),

                    IconButton(
                      iconSize: 60,
                      icon: const Icon(Icons.fingerprint, color: Color(0xFF00E676)),
                      onPressed: _authenticateBiometric,
                    ),
                    const Text("Huella / Cara", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage())),
                  child: const Text("Crear Cuenta"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}