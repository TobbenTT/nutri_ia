import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <--- Ya lo importaste, bien.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // ⚠️ ESTA ES LA LÍNEA QUE FALTABA:
  await dotenv.load(fileName: ".env");

  await initializeDateFormatting();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutri_IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        // FONDO NEGRO PURO CYBERPUNK
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF00FF88), // Verde Neón

        // Fuente estilo tech
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),

        // Inputs modernos
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F1F1F),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          prefixIconColor: const Color(0xFF00FF88),
          labelStyle: const TextStyle(color: Colors.grey),
        ),

        // Botones Neón
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF88),
            foregroundColor: Colors.black,
            elevation: 10,
            shadowColor: const Color(0xFF00FF88).withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}