import 'dart:convert'; // Para convertir JSON y Base64
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Peticiones directas a internet
import 'package:image_picker/image_picker.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  // ----------------------------------------------------------
  // 🔑 TU API KEY AQUÍ (Pégala dentro de las comillas)
  // ----------------------------------------------------------
  final String apiKey = "PON_AQUI_TU_API_KEY_REAL";
  // ----------------------------------------------------------

  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // Historial simple del chat
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Mensaje de bienvenida del bot
    _addMessage("¡Hola! Soy tu Nutri Chef IA 👨‍🍳.\nEnvíame una foto de tu comida (¡incluso un completo!) y te diré sus calorías.", false);
  }

  // Función auxiliar para agregar mensajes al chat visualmente
  void _addMessage(String text, bool isUser, {Uint8List? image, bool isError = false}) {
    setState(() {
      _messages.add({
        "text": text,
        "isUser": isUser,
        "image": image,
        "isError": isError
      });
    });
  }

  // 🔥 EL CORAZÓN DEL SISTEMA: Enviar datos a Google manualmente
  Future<void> _sendToGemini({String? textInput, Uint8List? imageBytes}) async {
    setState(() => _isLoading = true);

    try {
      // 1. URL DEL ENDPOINT (La dirección web de la IA)
      // Usamos el modelo "gemini-1.5-flash" que es rápido y acepta imágenes
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey'
      );

      // 2. CONSTRUIR EL PAQUETE DE DATOS (JSON)
      // Aquí "empaquetamos" el texto y la foto (en Base64)
      List<Map<String, dynamic>> parts = [];

      // A) Si el usuario escribió texto, lo agregamos
      if (textInput != null && textInput.isNotEmpty) {
        parts.add({"text": textInput});
      }
      // B) Si mandó foto pero no escribió, ponemos un texto por defecto
      else if (imageBytes != null) {
        parts.add({"text": "Analiza esta imagen detalladamente. Identifica la comida (ej: completo italiano, cazuela, etc) y estima sus calorías y macronutrientes."});
      }

      // C) Si hay imagen, la convertimos a Base64 (La "Licuadora de Píxeles")
      if (imageBytes != null) {
        String base64Image = base64Encode(imageBytes);
        parts.add({
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": base64Image
          }
        });
      }

      // Armamos el cuerpo final del mensaje
      final body = jsonEncode({
        "contents": [
          {
            "parts": parts
          }
        ]
      });

      // 3. ENVIAR LA CARTA (Petición POST)
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // 4. LEER LA RESPUESTA
      if (response.statusCode == 200) {
        // ÉXITO: Desempaquetamos el JSON que nos devolvió Google
        final data = jsonDecode(response.body);

        // Buscamos el texto escondido en la estructura de Google
        String botReply = data['candidates'][0]['content']['parts'][0]['text'];

        _addMessage(botReply, false);
      } else {
        // ERROR: Si Google rechaza, mostramos por qué (Error 400, 403, etc.)
        _addMessage("Error del servidor (${response.statusCode}):\n${response.body}", false, isError: true);
      }

    } catch (e) {
      _addMessage("Error de conexión: $e", false, isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Lógica al presionar enviar texto
  void _handleTextSubmit() {
    String text = _textController.text.trim();
    if (text.isEmpty) return;

    _addMessage(text, true); // Mostrar mensaje del usuario
    _textController.clear();

    _sendToGemini(textInput: text); // Enviar a la IA
  }

  // Lógica al presionar los botones de cámara/galería
  Future<void> _handleImageSubmit(ImageSource source) async {
    try {
      // 1. Tomar la foto y comprimirla (para que suba rápido)
      final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 80
      );

      if (image == null) return; // Usuario canceló

      // 2. Leer los bytes de la imagen
      Uint8List bytes = await image.readAsBytes();

      // 3. Mostrar la foto en el chat
      _addMessage("Analizando foto... 📸", true, image: bytes);

      // 4. Enviar a la IA
      _sendToGemini(imageBytes: bytes);

    } catch (e) {
      _addMessage("No se pudo cargar la foto: $e", false, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Nutri Chef IA 🤖", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ZONA DE CHAT (Lista de mensajes)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildBubble(msg);
              },
            ),
          ),

          // BARRA DE CARGA
          if (_isLoading)
            const LinearProgressIndicator(color: Color(0xFF00FF88), backgroundColor: Colors.transparent),

          // ZONA DE INPUT (Botones y texto)
          _buildInputArea(),
        ],
      ),
    );
  }

  // Widget para la barra inferior
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          // Botón Cámara
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Color(0xFF00FF88)),
            onPressed: _isLoading ? null : () => _handleImageSubmit(ImageSource.camera),
          ),
          // Botón Galería
          IconButton(
            icon: const Icon(Icons.photo, color: Colors.white),
            onPressed: _isLoading ? null : () => _handleImageSubmit(ImageSource.gallery),
          ),
          // Campo de Texto
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Escribe aquí...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleTextSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón Enviar
          CircleAvatar(
            backgroundColor: const Color(0xFF00FF88),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black, size: 20),
              onPressed: _isLoading ? null : _handleTextSubmit,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para las burbujas de chat
  Widget _buildBubble(Map<String, dynamic> msg) {
    bool isUser = msg['isUser'];
    bool isError = msg['isError'];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(15),
        constraints: const BoxConstraints(maxWidth: 300), // Ancho máximo de la burbuja
        decoration: BoxDecoration(
          color: isError
              ? Colors.red.withOpacity(0.2)
              : (isUser ? const Color(0xFF00FF88).withOpacity(0.2) : const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(15),
          ),
          border: Border.all(
              color: isError ? Colors.red : (isUser ? const Color(0xFF00FF88) : Colors.white10)
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Si hay foto, la mostramos
            if (msg['image'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(msg['image'], height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            // El texto del mensaje
            Text(
                msg['text'],
                style: TextStyle(
                    color: isError ? Colors.redAccent : Colors.white,
                    height: 1.4 // Espaciado para leer mejor
                )
            ),
          ],
        ),
      ),
    );
  }
}