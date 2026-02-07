import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _photoController = TextEditingController(); // Nuevo controlador para la foto

  bool _isDonor = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // 📥 CARGAR DATOS DE FIREBASE
  Future<void> _loadUserProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? user!.displayName ?? "Usuario";
          _goalController.text = (data['daily_goal'] ?? 2000).toString();
          _photoController.text = data['photo_url'] ?? ""; // Cargar URL de la foto
          _isDonor = data['is_donor'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
      setState(() => _isLoading = false);
    }
  }

  // 💾 GUARDAR CAMBIOS
  Future<void> _saveProfile() async {
    if (user == null) return;

    // Validación básica
    int newGoal = int.tryParse(_goalController.text) ?? 2000;
    if (newGoal < 500) newGoal = 500;
    if (newGoal > 10000) newGoal = 10000;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _nameController.text.trim(),
        'daily_goal': newGoal,
        'photo_url': _photoController.text.trim(), // Guardar URL de la foto
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado ✅"), backgroundColor: Color(0xFF00FF88)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // 🚪 CERRAR SESIÓN
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  // ------------------------------------------------------------------------
  // UI PRINCIPAL
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Obtenemos el nombre para la inicial
    String displayName = _nameController.text.isNotEmpty ? _nameController.text : "U";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. AVATAR Y ESTADO
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _isDonor ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                          width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: _isDonor ? Colors.amber.withOpacity(0.5) : Colors.green.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2)
                      ]),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF1E1E1E),
                    // INTENTAR CARGAR FOTO (Seguro a prueba de errores)
                    foregroundImage: _photoController.text.isNotEmpty
                        ? NetworkImage(_photoController.text)
                        : null,
                    onForegroundImageError: (_, __) {}, // Evita el crash si el link es malo
                    // SI NO HAY FOTO O FALLA, SE VE ESTO:
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                if (_isDonor)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD700),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, color: Colors.black, size: 20),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 15),
            Text(
              _isDonor ? "MIEMBRO VIP 👑" : "Usuario Estándar",
              style: TextStyle(
                  color: _isDonor ? const Color(0xFFFFD700) : Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ),

            const SizedBox(height: 40),

            // 2. FORMULARIO DE EDICIÓN
            _buildTextField("Nombre", _nameController, Icons.person_outline),
            const SizedBox(height: 20),

            // CAMPO NUEVO: FOTO DE PERFIL CON TUTORIAL
            _buildPhotoUrlField(),

            const SizedBox(height: 20),
            _buildTextField("Meta de Calorías Diaria", _goalController, Icons.flag_outlined, isNumber: true),

            const SizedBox(height: 10),
            const Text(
              "Esta meta actualizará tu barra de progreso en el Dashboard.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 40),

            // 3. BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                  shadowColor: const Color(0xFF00FF88).withOpacity(0.4),
                ),
                child: const Text(
                  "GUARDAR CAMBIOS",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET CAMPO DE TEXTO NORMAL
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              hintStyle: const TextStyle(color: Colors.grey),
            ),
            // Actualizar vista previa al escribir nombre
            onChanged: (val) { if(!isNumber) setState((){}); },
          ),
        ),
      ],
    );
  }

  // WIDGET ESPECIAL: CAMPO DE FOTO CON TUTORIAL
  Widget _buildPhotoUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Foto de Perfil (URL)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _showPhotoTutorial,
              child: const Row(
                children: [
                  Icon(Icons.help_outline, color: Color(0xFF00FF88), size: 16),
                  SizedBox(width: 4),
                  Text("¿Cómo subir?", style: TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextField(
            controller: _photoController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              hintText: "Ej: https://i.imgur.com/foto.jpg",
              hintStyle: TextStyle(color: Colors.grey),
            ),
            // Actualizar vista previa al pegar link
            onChanged: (val) => setState(() {}),
          ),
        ),
      ],
    );
  }

  // TUTORIAL DE AYUDA
  void _showPhotoTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Cómo poner tu foto 📸", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "La URL debe terminar en .jpg o .png",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _step("1", "Busca tu imagen en Google o Pinterest."),
              _step("2", "Mantén presionado sobre la imagen."),
              _step("3", "Elige 'Abrir imagen en pestaña nueva' o 'Copiar dirección de imagen'."),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  "❌ MAL: pinterest.com/pin/123\n✅ BIEN: i.pinimg.com/.../foto.jpg",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido", style: TextStyle(color: Color(0xFF00FF88))),
          ),
        ],
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF00FF88),
            child: Text(num, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}