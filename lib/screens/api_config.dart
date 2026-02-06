import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Ahora lee la clave del archivo .env
  // Si no la encuentra, devuelve un string vacío para evitar errores de null
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? "";
}