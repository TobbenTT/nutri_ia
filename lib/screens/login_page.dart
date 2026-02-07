import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

// IMPORTACIONES
import 'dashboard_page.dart';
import 'register_page.dart';
import 'terms_page.dart';

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
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Llena los campos");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _checkTermsAndRedirect();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Error de autenticación");
      setState(() => _isLoading = false);
    } catch (e) {
      _showError("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // ✅ CORRECCIÓN AQUÍ: Eliminamos 'options' que daba error en tu versión
  Future<void> _authenticateBiometric() async {
    try {
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        _showError("Biometría no disponible");
        return;
      }

      // Usamos la forma simple compatible con versiones viejas y nuevas
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Toca el sensor para entrar',
        // Quitamos 'options' porque tu librería es antigua.
        // Si necesitas parámetros específicos en versión vieja usa:
        // stickyAuth: true,
        // biometricOnly: true,
      );

      if (didAuthenticate) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _checkTermsAndRedirect();
        } else {
          _showError("Inicia sesión con contraseña primero");
        }
      }
    } on PlatformException catch (_) {
      _showError("Error biométrico. Usa contraseña.");
    }
  }

  Future<void> _checkTermsAndRedirect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final bool accepted = doc.data()?['accepted_terms'] ?? false;

      if (!mounted) return;

      if (accepted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TermsPage(isViewOnly: false)),
              (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Error verificando cuenta");
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: neonGreen.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)
                  ],
                ),
                child: const Icon(Icons.fitness_center, size: 80, color: neonGreen),
                // Si tienes imagen usa: Image.asset('assets/icon/icon.png', height: 100),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Correo",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.email, color: neonGreen),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: neonGreen), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.lock, color: neonGreen),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: neonGreen), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 30),

              if (_isLoading)
                const CircularProgressIndicator(color: neonGreen)
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: neonGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _authenticateBiometric,
                      child: Column(
                        children: [
                          Icon(Icons.fingerprint, size: 50, color: neonGreen.withOpacity(0.8)),
                          const Text("Biometría", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage())),
                child: const Text("Crear Cuenta", style: TextStyle(color: neonGreen)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}