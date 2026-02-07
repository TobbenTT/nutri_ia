import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NECESARIO PARA LEER EL COLOR
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // NECESARIO PARA GEMINI

// TUS PÁGINAS (Asegúrate que las rutas sean correctas)
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INICIALIZAR FIREBASE
  await Firebase.initializeApp();

  // 2. CARGAR CLAVES DE SEGURIDAD (Evita el crash de Gemini)
  await dotenv.load(fileName: ".env");

  // 3. BLOQUEAR GIRO DE PANTALLA
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. ESCUCHAMOS LA AUTENTICACIÓN (¿Está logueado?)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {

        // Si no hay usuario, mostramos el Login con color verde por defecto
        if (!authSnapshot.hasData) {
          return _buildApp(const Color(0xFF00FF88), const LoginPage());
        }

        // 2. SI HAY USUARIO, ESCUCHAMOS SU COLOR EN FIREBASE (Aquí ocurre la magia)
        final String uid = authSnapshot.data!.uid;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnapshot) {
            // Color por defecto (Verde Matrix) si no ha elegido nada
            Color userColor = const Color(0xFF00FF88);

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              // Si tiene un color guardado, lo usamos
              if (data.containsKey('theme_color')) {
                userColor = Color(data['theme_color']);
              }
            }

            // Construimos la app con el color del usuario y lo mandamos al Dashboard
            return _buildApp(userColor, const DashboardPage());
          },
        );
      },
    );
  }

  // Función auxiliar para construir el MaterialApp con un color específico
  Widget _buildApp(Color primaryColor, Widget home) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nutri IA',
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: primaryColor,
          scaffoldBackgroundColor: Colors.black,
          useMaterial3: true,
          // Configuración profunda de colores para que TODO cambie (botones, iconos, etc.)
          colorScheme: ColorScheme.dark(
            primary: primaryColor,
            secondary: primaryColor,
            surface: const Color(0xFF1E1E1E),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.black, // Texto negro en botones de color
            ),
          ),
          iconTheme: IconThemeData(color: primaryColor),
          inputDecorationTheme: InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                  borderRadius: BorderRadius.circular(10)
              )
          )
      ),
      home: home,
    );
  }
}