import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
// Asegúrate de que esta ruta sea correcta según tus carpetas:
import 'services/notification_service.dart';
import 'screens/login_page.dart'; // O tu página de inicio
import 'screens/dashboard_page.dart'; // Por si ya está logueado
import 'package:firebase_auth/firebase_auth.dart' as import_firebase_auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INICIALIZAR FIREBASE (Vital)
  // Si usas firebase_options.dart, agrega: options: DefaultFirebaseOptions.currentPlatform
  await Firebase.initializeApp();

  // 2. CHALECO ANTIBALAS PARA NOTIFICACIONES 🛡️
  // Si esto falla, la app NO se detiene.
  try {
    final notiService = NotificationService();
    await notiService.init();

    // Programamos los horarios (seguros dentro del try)
    await notiService.scheduleDailyNotification(
        id: 1,
        title: "¡Buenos días! ☀️",
        body: "No olvides registrar tu desayuno.",
        hour: 9
    );
    await notiService.scheduleDailyNotification(
        id: 2,
        title: "Hora del almuerzo 🥗",
        body: "¿Qué vas a comer hoy? Regístralo.",
        hour: 14
    );
    await notiService.scheduleDailyNotification(
        id: 3,
        title: "Cena ligera 🌙",
        body: "Cierra tu día registrando tu cena.",
        hour: 20
    );
    debugPrint("✅ Notificaciones iniciadas correctamente");

  } catch (e) {
    // Si falla, solo imprimimos el error, pero la app SIGUE VIVA
    debugPrint("⚠️ Error en notificaciones (La app iniciará sin ellas): $e");
  }

  // 3. BLOQUEAR GIRO DE PANTALLA (Opcional, se ve más pro vertical)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nutri IA',
      theme: ThemeData(
        brightness: Brightness.dark, // Tema oscuro por defecto
        primaryColor: const Color(0xFF00FF88),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      // Aquí decides a dónde ir. Si usas FirebaseAuth, puedes validar si hay usuario.
      home: const AuthWrapper(),
    );
  }
}

// Pequeño widget para decidir si ir al Login o al Dashboard
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha cambios en la autenticación en tiempo real
    return StreamBuilder(
      stream: import_firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }
        if (snapshot.hasData) {
          return const DashboardPage(); // Usuario logueado -> Dashboard
        }
        return const LoginPage(); // No logueado -> Login
      },
    );
  }
}

