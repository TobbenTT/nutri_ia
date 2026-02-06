import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart'; // Solo una vez
import 'package:flutter/services.dart'; // Para manejar errores de plataforma
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

  // Instancia correcta para la versión 3.0.0
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

  Future<void> _authenticateBiometric() async {
    try {
      // 1. Verificamos si hay hardware
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        _showError("Tu celular no tiene biometría disponible.");
        return;
      }

      // 2. Autenticamos (Formato Universal)
      // Al quitar 'stickyAuth' y 'options', Flutter usará la configuración por defecto
      // que funciona en el 99% de los casos.
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Toca el sensor o mira la cámara para entrar',
      );

      if (didAuthenticate) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _goToDashboard();
        } else {
          _showError("Primero inicia sesión con contraseña para vincular.");
        }
      }
    } on PlatformException catch (e) {
      // Ignoramos el error "NotAvailable" que pasa a veces al cancelar
      if (e.code == 'NotAvailable') return;
      _showError("Error: ${e.message}");
    } catch (e) {
      _showError("No se pudo autenticar.");
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
      backgroundColor: const Color(0xFF050505), // Fondo negro puro para que resalte el neón
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- AQUÍ ESTÁ EL CAMBIO: TU LOGO CON BRILLO ---
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withOpacity(0.4), // Brillo verde matrix
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Image.asset(
                    'assets/icon/icon.png', // Tu logo real
                    height: 120,            // Un buen tamaño
                    width: 120,
                  ),
                ),

                const SizedBox(height: 20),
                const Text("Bienvenido", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 40),

                // Inputs con estilo oscuro
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Correo",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF00E676)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF00E676)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 25),

                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF00E676))
                    : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Botón de Huella (Este sí lo dejamos como Icono porque es un botón)
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
                  child: const Text("Crear Cuenta", style: TextStyle(color: Color(0xFF00E676))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}