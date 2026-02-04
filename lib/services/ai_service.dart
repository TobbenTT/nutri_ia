import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // 🔴 🔴 🔴 ¡ATENCIÓN! PEGA TU API KEY AQUÍ ABAJO DENTRO DE LAS COMILLAS 🔴 🔴 🔴
  static const String apiKey = 'AIzaSyCUVCeImhIuKSq5e3uC-oPwBbULvU3WXjU';

  Future<Map<String, dynamic>?> analyzeFood(File imageFile) async {
    try {
      // Usamos el modelo Gemini 1.5 Flash (Rápido y bueno para imágenes)
      final model = GenerativeModel(
        model: 'gemini-pro-vision', // El modelo clásico para fotos
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();

      // Le damos instrucciones precisas a la IA para que actúe como nutricionista
      final prompt = TextPart(
          "Analiza esta imagen de comida. Identifica el plato principal. "
              "Devuelve SOLO un JSON (sin texto extra ni markdown ```json) con este formato exacto: "
              "{'name': 'Nombre corto del plato', 'calories': 0 (número entero estimado), 'protein': 0.0 (decimal estimado), 'carbs': 0.0 (decimal estimado), 'fat': 0.0 (decimal estimado)}. "
              "Si la imagen no es comida clara, devuelve un JSON vacío {}."
      );

      // Preparamos la imagen para enviarla
      final imageParts = [
        DataPart('image/jpeg', imageBytes),
      ];

      // Enviamos todo a Google
      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);

      final text = response.text;

      if (text == null || text.isEmpty) {
        print("La IA no devolvió texto.");
        return null;
      }

      // Limpieza de seguridad por si la IA agrega formato de código
      String cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();

      // Convertimos el texto recibido en datos que la app entiende (Mapa)
      return jsonDecode(cleanJson);

    } catch (e) {
      print("Error grave en el servicio de IA: $e");
      return null;
    }
  }

  // NUEVA FUNCIÓN: GENERADOR DE DIETA
  Future<String?> generateDietPlan(int calories, String goal) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash-001', apiKey: apiKey);

      final prompt = "Soy tu nutricionista IA. Mi paciente necesita consumir $calories kcal diarias. "
          "Su objetivo actual es: $goal. "
          "Crea un plan de alimentación de 1 día (Desayuno, Almuerzo, Cena y Snacks) "
          "que sea saludable, fácil de cocinar y sume exactamente esas calorías. "
          "Usa formato Markdown con emojis, sé motivador y breve.";

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      return "Error al generar dieta: $e";
    }
  }
} // Fin de la clase


