import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // 🔴 🔴 🔴 API KEY SEGURA 🔴 🔴 🔴
  static const String apiKey = 'AIzaSyCUVCeImhIuKSq5e3uC-oPwBbULvU3WXjU';

  Future<Map<String, dynamic>?> analyzeFood(File imageFile) async {
    try {
      // ✅ MODELO CORRECTO: gemini-3-flash-preview
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();

      // Prompt pidiendo JSON estricto
      final prompt = TextPart(
          "Analiza esta imagen de comida. Identifica el plato principal. "
              "Devuelve SOLO un JSON (sin texto extra ni markdown ```json) con este formato exacto: "
              "{'name': 'Nombre corto del plato', 'calories': 0 (número entero estimado), 'protein': 0 (número entero estimado), 'carbs': 0 (número entero estimado), 'fat': 0 (número entero estimado)}. "
              "Si la imagen no es comida clara, devuelve un JSON vacío {}."
      );

      final imageParts = [
        DataPart('image/jpeg', imageBytes),
      ];

      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);

      final text = response.text;

      if (text == null || text.isEmpty) {
        print("La IA no devolvió texto.");
        return null;
      }

      // ✅ EXTRACCIÓN SEGURA DE JSON CON REGEX
      // Busca contenido entre { y } para evitar errores de formato
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);

      if (jsonMatch != null) {
        String cleanJson = jsonMatch.group(0)!;
        return jsonDecode(cleanJson);
      } else {
        // Fallback por si la IA no obedece
        String cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanJson);
      }

    } catch (e) {
      print("Error en AiService: $e");
      return null;
    }
  }

  // ✅ MODELO CORRECTO: gemini-3-flash-preview
  Future<String?> generateDietPlan(int calories, String goal) async {
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: apiKey);

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
}