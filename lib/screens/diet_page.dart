import 'dart:convert'; // Para convertir JSON y Base64
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Peticiones directas a internet
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- NUEVO: Para saber quién es el usuario
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- NUEVO: Para chequear si pagó
import 'api_config.dart'; // Tu archivo de clave
import 'settings_page.dart'; // Para redirigir a la página de donación si es necesario

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  final String apiKey = ApiConfig.geminiApiKey;
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // VARIABLES DE CONTROL VIP
  bool _checkingStatus = true; // ¿Estamos cargando los datos del usuario?
  bool _canAccess = false; // ¿Tiene permiso para entrar?
  final String adminEmail = "david.cabezas.armando@gmail.com"; // Para que tú siempre entres

  @override
  void initState() {
    super.initState();
    _checkAccess(); // Verificamos permisos antes de saludar
  }

  // 🔒 FUNCIÓN DE SEGURIDAD: VERIFICA SI ES DONADOR
  Future<void> _checkAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Verificar si es el Admin (Tú)
      if (user.email == adminEmail) {
        setState(() {
          _canAccess = true;
          _checkingStatus = false;
        });
        _addMessage("¡Bienvenido Creador! 🛡️ Modo Dios activado.", false);
        return;
      }

      // 2. Verificar en Firebase si es Donador
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final bool isDonor = doc.data()?['is_donor'] ?? false;

      if (mounted) {
        setState(() {
          _canAccess = isDonor;
          _checkingStatus = false;
        });

        if (isDonor) {
          _addMessage("¡Hola VIP! 👑 Soy tu Chef IA exclusivo.\nMándame foto de tu comida y te calculo todo.", false);
        }
      }
    } catch (e) {
      debugPrint("Error verificando acceso: $e");
      setState(() => _checkingStatus = false);
    }
  }

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

  // 🔥 LÓGICA IA ACTUALIZADA (GEMINI 3 - 2026)
  Future<void> _sendToGemini({String? textInput, Uint8List? imageBytes}) async {
    setState(() => _isLoading = true);

    try {
      // ✅ CAMBIO CRÍTICO: Usamos Gemini 3 Flash Preview (Vigente en 2026)
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$apiKey'
      );

      List<Map<String, dynamic>> parts = [];

      if (textInput != null && textInput.isNotEmpty) {
        parts.add({"text": textInput});
      } else if (imageBytes != null) {
        parts.add({"text": "Analiza esta imagen detalladamente. Identifica la comida, estima sus calorías totales y dame los macronutrientes aproximados. Responde como un chef experto."});
      }

      if (imageBytes != null) {
        String base64Image = base64Encode(imageBytes);
        parts.add({
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": base64Image
          }
        });
      }

      final body = jsonEncode({
        "contents": [{"parts": parts}]
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          String botReply = data['candidates'][0]['content']['parts'][0]['text'];
          _addMessage(botReply, false);
        }
      } else {
        _addMessage("Error IA (${response.statusCode}).", false, isError: true);
        debugPrint(response.body);
      }

    } catch (e) {
      _addMessage("Error de conexión.", false, isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleTextSubmit() {
    String text = _textController.text.trim();
    if (text.isEmpty) return;
    _addMessage(text, true);
    _textController.clear();
    _sendToGemini(textInput: text);
  }

  Future<void> _handleImageSubmit(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (image == null) return;
      Uint8List bytes = await image.readAsBytes();
      _addMessage("Analizando foto... 📸", true, image: bytes);
      _sendToGemini(imageBytes: bytes);
    } catch (e) {
      _addMessage("Error con la foto.", false, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. PANTALLA DE CARGA (Verificando si pagó)
    if (_checkingStatus) {
      return const Scaffold(
        backgroundColor: Color(0xFF050505),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }

    // 2. PANTALLA DE BLOQUEO (Si no es Donador)
    if (!_canAccess) {
      return Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: AppBar(
          title: const Text("Acceso Restringido", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: const Icon(Icons.lock, size: 80, color: Colors.amber),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Función Exclusiva VIP",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  "El Nutri Chef IA consume muchos recursos y es exclusivo para quienes apoyan el proyecto.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navega a la página de donaciones
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DonationPage()));
                  },
                  icon: const Icon(Icons.star, color: Colors.black),
                  label: const Text("CONVERTIRSE EN VIP", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Volver", style: TextStyle(color: Colors.grey)),
                )
              ],
            ),
          ),
        ),
      );
    }

    // 3. PANTALLA DEL CHAT (Si es VIP o Admin)
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Nutri Chef IA 👑", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
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
          if (_isLoading) const LinearProgressIndicator(color: Color(0xFFFFD700), backgroundColor: Colors.transparent),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Color(0xFFFFD700)),
            onPressed: _isLoading ? null : () => _handleImageSubmit(ImageSource.camera),
          ),
          IconButton(
            icon: const Icon(Icons.photo, color: Colors.white),
            onPressed: _isLoading ? null : () => _handleImageSubmit(ImageSource.gallery),
          ),
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
                  hintText: "Pregúntale al Chef...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleTextSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFFFFD700),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black, size: 20),
              onPressed: _isLoading ? null : _handleTextSubmit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    bool isUser = msg['isUser'];
    bool isError = msg['isError'];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(15),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red.withOpacity(0.2)
              : (isUser ? const Color(0xFFFFD700).withOpacity(0.2) : const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isError ? Colors.red : (isUser ? const Color(0xFFFFD700) : Colors.white10)
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['image'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(msg['image'], height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            Text(
                msg['text'],
                style: TextStyle(color: isError ? Colors.redAccent : Colors.white, height: 1.4)
            ),
          ],
        ),
      ),
    );
  }
}