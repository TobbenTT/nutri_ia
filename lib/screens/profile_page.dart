import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

// ------------------------------------------------------------------------
// MODELO DE ACCESORIOS (GORRITOS)
// ------------------------------------------------------------------------
class Accessory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  Accessory({required this.id, required this.name, required this.icon, required this.color});
}

final List<Accessory> allHats = [
  Accessory(id: 'crown', name: 'Rey/Reina', icon: Icons.workspace_premium, color: const Color(0xFFFFD700)), // Oro
  Accessory(id: 'chef_hat', name: 'Chef Supremo', icon: Icons.restaurant, color: Colors.white70),
  Accessory(id: 'party_horn', name: 'Fiesta', icon: Icons.celebration, color: Colors.pinkAccent),
  Accessory(id: 'wizard_hat', name: 'Mago', icon: Icons.auto_awesome, color: Colors.deepPurpleAccent),
  Accessory(id: 'angel', name: 'Angelito', icon: Icons.wb_sunny_outlined, color: Colors.lightBlueAccent),
  Accessory(id: 'viking', name: 'Vikingo', icon: Icons.shield, color: Colors.orangeAccent),
];

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Controladores de texto
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _photoController = TextEditingController();

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
          _nameController.text = data['name'] ?? "Usuario";
          _goalController.text = (data['daily_goal'] ?? 2000).toString();
          // Usamos photoUrl exacto de tu Firebase para evitar errores
          _photoController.text = data['photoUrl'] ?? "";
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

    int newGoal = int.tryParse(_goalController.text) ?? 2000;
    if (newGoal < 500) newGoal = 500;
    if (newGoal > 10000) newGoal = 10000;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _nameController.text.trim(),
        'daily_goal': newGoal,
        'photoUrl': _photoController.text.trim(),
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
            // 1. AVATAR Y ESTADO CON SISTEMA DE GORRITOS
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _isDonor ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                          width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF1E1E1E),
                      // Lógica de seguridad para evitar pantallas rojas si la URL está vacía
                      backgroundImage: _photoController.text.trim().isNotEmpty
                          ? NetworkImage(_photoController.text.trim())
                          : null,
                      child: _photoController.text.trim().isEmpty
                          ? Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                          : null,
                    ),
                  ),
                ),

                // GORRITO VISUALIZADO EN TIEMPO REAL
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox();
                    final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                    final String? activeHatId = data['active_hat'];

                    if (activeHatId == null) return const SizedBox();

                    final hat = allHats.firstWhere((h) => h.id == activeHatId, orElse: () => allHats[0]);

                    return Positioned(
                      top: 0,
                      child: Icon(hat.icon, color: hat.color, size: 45),
                    );
                  },
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

            const SizedBox(height: 30),

            // 🏆 SECCIÓN DINÁMICA DE RECOMPENSAS (RACHAS Y MEDALLAS)
            _buildRewardsAndBadgesSection(),

            const SizedBox(height: 30),

            // 2. FORMULARIO DE EDICIÓN
            _buildTextField("Nombre", _nameController, Icons.person_outline),
            const SizedBox(height: 20),

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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _buildRewardsAndBadgesSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> badges = data['badges'] ?? [];
        final int streak = data['current_streak'] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget de la racha (El fuego)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "$streak DÍAS SEGUIDOS",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Mostrar Medallas
            if (badges.isNotEmpty) ...[
              const Text("MEDALLAS Y LOGROS",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 15),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: badges.map((b) => _buildBadgeIcon(b.toString())).toList(),
              ),
              const SizedBox(height: 30),
            ],

            // Selector de Accesorios (Gorritos)
            _buildHatsSelector(data['active_hat'], badges),
          ],
        );
      },
    );
  }

  Widget _buildBadgeIcon(String badgeId) {
    IconData icon; Color color; String label;
    switch (badgeId) {
      case 'beta_founder':
        icon = Icons.verified; color = Colors.cyanAccent; label = "Fundador";
        break;
      case 'ia_master':
        icon = Icons.psychology; color = Colors.purpleAccent; label = "IA Master";
        break;
      case 'streak_7':
        icon = Icons.local_fire_department; color = Colors.orangeAccent; label = "Racha 7";
        break;
      default:
        icon = Icons.star; color = Colors.amber; label = "Logro";
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 2),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHatsSelector(String? activeHatId, List<dynamic> badges) {
    bool isBeta = badges.contains('beta_founder');
    // Solo mostramos si es Donador o Fundador
    if (!_isDonor && !isBeta) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ACCESORIOS DESBLOQUEADOS",
          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 110, // Un poco más alto para que respire el diseño
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allHats.length,
            itemBuilder: (context, index) {
              final hat = allHats[index];
              final bool isSelected = activeHatId == hat.id;

              // Filtro de seguridad para el gorrito de Dino
              if (hat.id == 'dino' && !isBeta) return const SizedBox.shrink();

              return GestureDetector(
                onTap: () async {
                  await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                    'active_hat': hat.id,
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 90,
                  margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
                  decoration: BoxDecoration(
                    // Fondo oscuro o con tinte del color si está seleccionado
                    color: isSelected ? hat.color.withAlpha(25) : const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? hat.color : Colors.white.withAlpha(15),
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: hat.color.withAlpha(50), blurRadius: 10, spreadRadius: 1)]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          hat.icon,
                          color: isSelected ? hat.color : Colors.grey.shade700,
                          size: 32
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hat.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (activeHatId != null)
          TextButton.icon(
            onPressed: () => FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'active_hat': FieldValue.delete()}),
            icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
            label: const Text("Quitar accesorio", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
      ],
    );
  }

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
            ),
          ),
        ),
      ],
    );
  }

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
            ),
            onChanged: (val) => setState(() {}),
          ),
        ),
      ],
    );
  }

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