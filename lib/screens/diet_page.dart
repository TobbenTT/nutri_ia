import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:http/http.dart' as http; // Peticiones del Chat
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'api_config.dart'; // Tu archivo de clave
import 'settings_page.dart'; // Para redirigir a donación
import '../services/ai_service.dart'; // ✅ NUEVO: Para el Plan Diario

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> with SingleTickerProviderStateMixin {
  // ---------------------------------------------------
  // VARIABLES GLOBALES Y DE ACCESO
  // ---------------------------------------------------
  final User? user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  // VARIABLES CONTROL VIP
  bool _checkingStatus = true;
  bool _canAccess = false;
  final String adminEmail = "david.cabezas.armando@gmail.com";

  // ---------------------------------------------------
  // VARIABLES DEL CHAT (TU CÓDIGO ORIGINAL)
  // ---------------------------------------------------
  final String apiKey = ApiConfig.geminiApiKey;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  bool _isChatLoading = false;
  final ImagePicker _picker = ImagePicker();

  // ---------------------------------------------------
  // VARIABLES DEL PLAN DIARIO (LO NUEVO)
  // ---------------------------------------------------
  final AiService _aiService = AiService();
  String? _todaysPlan;
  bool _isPlanLoading = true;
  bool _isGeneratingPlan = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAccess();     // 1. Ver si es VIP
    _loadTodaysDiet();  // 2. Cargar Plan si existe
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 🔐 1. LÓGICA DE SEGURIDAD (MODO DIOS Y VIP)
  // ===========================================================================
  Future<void> _checkAccess() async {
    if (user == null) return;
    try {
      // 1. Admin
      if (user!.email == adminEmail) {
        setState(() {
          _canAccess = true;
          _checkingStatus = false;
        });
        _addChatMessage("¡Bienvenido Creador! 🛡️ Modo Dios activado.", false);
        return;
      }

      // 2. Donador
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final bool isDonor = doc.data()?['is_donor'] ?? false;

      if (mounted) {
        setState(() {
          _canAccess = isDonor;
          _checkingStatus = false;
        });

        if (isDonor) {
          _addChatMessage("¡Hola VIP! 👑 Soy tu Chef IA.\nPuedes pedirme recetas o ir a la pestaña 'Plan Diario' para tu menú de hoy.", false);
        }
      }
    } catch (e) {
      debugPrint("Error verificando acceso: $e");
      setState(() => _checkingStatus = false);
    }
  }

  // ===========================================================================
  // 📅 2. LÓGICA DEL PLAN DIARIO (PERSISTENCIA) - NUEVO
  // ===========================================================================
  Future<void> _loadTodaysDiet() async {
    if (user == null) return;
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('diet_plans')
          .doc(todayDate)
          .get();

      if (mounted) {
        setState(() {
          if (doc.exists) {
            _todaysPlan = doc.data()?['plan_text'];
          }
          _isPlanLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isPlanLoading = false);
    }
  }

  Future<void> _generateAndSaveDiet() async {
    setState(() => _isGeneratingPlan = true);
    HapticFeedback.mediumImpact();

    try {
      // Obtenemos meta calórica real
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final int calories = userDoc.data()?['daily_goal'] ?? 2000;
      final String goal = "Salud general";

      // Llamamos a tu AiService
      final String? plan = await _aiService.generateDietPlan(calories, goal);

      if (plan != null && mounted) {
        // Guardamos en Firestore
        final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('diet_plans')
            .doc(todayDate)
            .set({
          'plan_text': plan,
          'calories_target': calories,
          'created_at': FieldValue.serverTimestamp(),
        });

        setState(() {
          _todaysPlan = plan;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isGeneratingPlan = false);
    }
  }

  // ===========================================================================
  // 💬 3. LÓGICA DEL CHAT (TU CÓDIGO ORIGINAL CON HTTP)
  // ===========================================================================
  void _addChatMessage(String text, bool isUser, {Uint8List? image, bool isError = false}) {
    setState(() {
      _chatMessages.add({
        "text": text,
        "isUser": isUser,
        "image": image,
        "isError": isError
      });
    });
  }

  Future<void> _sendToGemini({String? textInput, Uint8List? imageBytes}) async {
    setState(() => _isChatLoading = true);

    try {
      // ✅ MODELO GEMINI 3 FLASH PREVIEW (MANTENIDO)
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
          _addChatMessage(botReply, false);
        }
      } else {
        _addChatMessage("Error IA (${response.statusCode}).", false, isError: true);
      }

    } catch (e) {
      _addChatMessage("Error de conexión.", false, isError: true);
    } finally {
      setState(() => _isChatLoading = false);
    }
  }

  void _handleTextSubmit() {
    String text = _chatController.text.trim();
    if (text.isEmpty) return;
    _addChatMessage(text, true);
    _chatController.clear();
    _sendToGemini(textInput: text);
  }

  Future<void> _handleImageSubmit(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (image == null) return;
      Uint8List bytes = await image.readAsBytes();
      _addChatMessage("Analizando foto... 📸", true, image: bytes);
      _sendToGemini(imageBytes: bytes);
    } catch (e) {
      _addChatMessage("Error con la foto.", false, isError: true);
    }
  }

  // ===========================================================================
  // 🖥️ 4. INTERFAZ GRÁFICA (UI)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    // A) PANTALLA DE CARGA
    if (_checkingStatus) {
      return const Scaffold(
        backgroundColor: Color(0xFF050505),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }

    // B) PANTALLA DE BLOQUEO (NO VIP)
    if (!_canAccess) {
      return _buildLockedView();
    }

    // C) PANTALLA PRINCIPAL (VIP)
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Chef & Plan 👑", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today), text: "Plan de Hoy"),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: "Chat Chef"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: EL NUEVO PLAN DIARIO
          _buildPlanTab(),
          // TAB 2: TU CHAT ORIGINAL
          _buildChatTab(),
        ],
      ),
    );
  }

  // --- VISTA BLOQUEADA ---
  Widget _buildLockedView() {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(title: const Text("Acceso VIP", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 2)),
                child: const Icon(Icons.lock, size: 80, color: Colors.amber),
              ),
              const SizedBox(height: 30),
              const Text("Función Exclusiva VIP", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text("El Chef IA y el Plan Diario son exclusivos para quienes apoyan el proyecto.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DonationPage())),
                icon: const Icon(Icons.star, color: Colors.black),
                label: const Text("CONVERTIRSE EN VIP", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              ),
              const SizedBox(height: 20),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Volver", style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: PLAN DIARIO (PERSISTENTE) ---
  Widget _buildPlanTab() {
    if (_isPlanLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));

    if (_todaysPlan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("Menú de hoy vacío", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Genera un plan completo basado en tus metas.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            if (_isGeneratingPlan)
              Column(children: [const CircularProgressIndicator(color: Color(0xFF00FF88)), const SizedBox(height: 15), Text("El Chef está cocinando el plan... 👨‍🍳", style: TextStyle(color: Colors.greenAccent.shade100))])
            else
              SizedBox(
                width: 250,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _generateAndSaveDiet,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text("GENERAR PLAN AHORA", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3))),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFF00FF88)),
                const SizedBox(width: 10),
                Expanded(child: Text("Plan generado para hoy: ${DateFormat('dd/MM').format(DateTime.now())}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(20)),
            child: SelectableText(_todaysPlan!, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: CHAT (TU CÓDIGO ORIGINAL) ---
  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              return _buildChatBubble(msg);
            },
          ),
        ),
        if (_isChatLoading) const LinearProgressIndicator(color: Color(0xFFFFD700), backgroundColor: Colors.transparent),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.camera_alt, color: Color(0xFFFFD700)), onPressed: _isChatLoading ? null : () => _handleImageSubmit(ImageSource.camera)),
          IconButton(icon: const Icon(Icons.photo, color: Colors.white), onPressed: _isChatLoading ? null : () => _handleImageSubmit(ImageSource.gallery)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: _chatController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: "Pregúntale al Chef...", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                onSubmitted: (_) => _handleTextSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFFFFD700),
            child: IconButton(icon: const Icon(Icons.send, color: Colors.black, size: 20), onPressed: _isChatLoading ? null : _handleTextSubmit),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    bool isUser = msg['isUser'];
    bool isError = msg['isError'];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(15),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isError ? Colors.red.withOpacity(0.2) : (isUser ? const Color(0xFFFFD700).withOpacity(0.2) : const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isError ? Colors.red : (isUser ? const Color(0xFFFFD700) : Colors.white10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['image'] != null)
              Padding(padding: const EdgeInsets.only(bottom: 10.0), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(msg['image'], height: 180, width: double.infinity, fit: BoxFit.cover))),
            Text(msg['text'], style: TextStyle(color: isError ? Colors.redAccent : Colors.white, height: 1.4)),
          ],
        ),
      ),
    );
  }
}