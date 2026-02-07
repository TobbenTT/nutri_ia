import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'login_page.dart';

// ------------------------------------------------------------------------
// 1. MODELO DE ACCESORIOS (GORRITOS) - VERSIÓN FINAL
// ------------------------------------------------------------------------
class Accessory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool needsAd; // Requiere ver anuncio
  final bool isBeta;  // Exclusivo Beta Founders

  Accessory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.needsAd = false,
    this.isBeta = false,
  });
}

// 🧢 LISTA MAESTRA DE ACCESORIOS
final List<Accessory> allHats = [
  // --- GRATIS / POR JUGAR ---
  Accessory(id: 'chef_hat', name: 'Chef', icon: Icons.restaurant, color: Colors.white),
  Accessory(id: 'party_horn', name: 'Fiestero', icon: Icons.celebration, color: Colors.pinkAccent),
  Accessory(id: 'viking', name: 'Vikingo', icon: Icons.shield, color: Colors.orangeAccent),

  // --- EXCLUSIVOS BETA FOUNDER (LEGENDARIOS) ---
  Accessory(id: 'beta_helmet', name: 'Casco Beta', icon: Icons.construction, color: Colors.cyanAccent, isBeta: true),
  Accessory(id: 'bug_hunter', name: 'Caza Bugs', icon: Icons.bug_report, color: Colors.greenAccent, isBeta: true),
  Accessory(id: 'pioneer', name: 'Pionero', icon: Icons.rocket_launch, color: Colors.purpleAccent, isBeta: true),

  // --- REWARDED ADS (MONETIZACIÓN) ---
  Accessory(id: 'wizard_hat', name: 'Mago', icon: Icons.auto_awesome, color: Colors.deepPurpleAccent, needsAd: true),
  Accessory(id: 'angel', name: 'Ángel', icon: Icons.wb_sunny_outlined, color: Colors.lightBlueAccent, needsAd: true),
  Accessory(id: 'crown', name: 'Rey', icon: Icons.workspace_premium, color: const Color(0xFFFFD700), needsAd: true),
];

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
  final TextEditingController _photoController = TextEditingController();

  bool _isDonor = false;
  bool _isLoading = true;
  String _previewPhoto = ""; // Para ver la foto en tiempo real antes de guardar

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // 📥 CARGAR DATOS
  Future<void> _loadUserProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? "Usuario";
          _goalController.text = (data['daily_goal'] ?? 2000).toString();
          _photoController.text = data['photoUrl'] ?? "";
          _previewPhoto = data['photoUrl'] ?? "";
          _isDonor = data['is_donor'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
      setState(() => _isLoading = false);
    }
  }

  // 💾 GUARDAR DATOS
  Future<void> _saveProfile() async {
    if (user == null) return;
    HapticFeedback.mediumImpact();

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
          const SnackBar(content: Text("¡Perfil actualizado correctamente! ✅"), backgroundColor: Color(0xFF00FF88)),
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
  // LÓGICA DE ANUNCIOS Y EQUIPAMIENTO
  // ------------------------------------------------------------------------
  void _watchAdToUnlock(Accessory hat) {
    // AQUÍ IRÁ EL CÓDIGO REAL DE ADMOB CUANDO LO INTEGRES
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("🎁 Desbloquear con Anuncio", style: TextStyle(color: Colors.white)),
        content: Text("Mira un anuncio breve para usar el gorro '${hat.name}'.\n(Simulación)", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Simulación de espera
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reproduciendo anuncio... 📺"), duration: Duration(seconds: 2)));
              Future.delayed(const Duration(seconds: 2), () {
                _equipHat(hat.id); // ÉXITO
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            child: const Text("VER ANUNCIO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _equipHat(String hatId) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'active_hat': hatId,
    });
    HapticFeedback.lightImpact();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Accesorio equipado! 🧢")));
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
            // 1. AVATAR CON GORRITO (ZONA VISUAL PRINCIPAL)
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Círculo del Avatar
                Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _isDonor ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                            width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: (_isDonor ? const Color(0xFFFFD700) : const Color(0xFF00FF88)).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2
                          )
                        ]
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFF1E1E1E),
                      backgroundImage: _previewPhoto.isNotEmpty
                          ? NetworkImage(_previewPhoto)
                          : null,
                      child: _previewPhoto.isEmpty
                          ? Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                          : null,
                    ),
                  ),
                ),

                // GORRITO SUPERPUESTO (STREAM)
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
                      child: DropShadow( // Efecto de sombra para el icono
                        child: Icon(hat.icon, color: hat.color, size: 60),
                      ),
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
                  letterSpacing: 1.5,
                  fontSize: 12),
            ),

            const SizedBox(height: 30),

            // 🏆 SECCIÓN DE ESTADÍSTICAS Y GORRITOS
            _buildStatsAndHatsSection(),

            const SizedBox(height: 30),
            const Divider(color: Colors.white10),
            const SizedBox(height: 20),

            // 2. FORMULARIO DE DATOS
            const Align(alignment: Alignment.centerLeft, child: Text("EDITAR PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(height: 20),

            _buildTextField("Nombre de Usuario", _nameController, Icons.person_outline),
            const SizedBox(height: 20),

            // CAMPO DE FOTO CON BOTÓN DE AYUDA (RECUPERADO)
            _buildPhotoUrlField(),

            const SizedBox(height: 20),
            _buildTextField("Meta Diaria (kcal)", _goalController, Icons.flag_outlined, isNumber: true),

            const SizedBox(height: 40),

            // 3. BOTÓN GUARDAR GRANDE
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

  // --- WIDGETS AUXILIARES ---

  Widget _buildStatsAndHatsSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        final int streak = data['current_streak'] ?? 0;
        final int totalScans = data['total_scans'] ?? 0;

        return Column(
          children: [
            // Tarjetas de Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statCard(Icons.local_fire_department, "$streak", "Días Racha", Colors.orange),
                _statCard(Icons.qr_code_scanner, "$totalScans", "Total Scans", Colors.blueAccent),
                _statCard(Icons.emoji_events, "${allHats.length}", "Coleccionables", Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 30),

            // Selector de Gorros
            _buildHatsSelector(data, streak, totalScans),
          ],
        );
      },
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
        ],
      ),
    );
  }

  // LÓGICA DE GORRITOS (BETA / ADS / FREE)
  Widget _buildHatsSelector(Map<String, dynamic> userData, int streak, int totalScans) {
    final String? activeHatId = userData['active_hat'];
    final bool isVip = userData['is_donor'] ?? false;
    final List<dynamic> badges = userData['badges'] ?? [];
    final bool isBetaFounder = badges.contains('beta_founder');

    // Reglas de negocio
    bool isUnlocked(Accessory hat) {
      if (hat.isBeta) return isBetaFounder; // Solo fundadores
      if (isVip && !hat.needsAd) return true; // VIP tiene todo lo que no es de anuncio ni beta

      if (hat.needsAd) return false; // Requiere anuncio

      // Reglas Gratis
      switch (hat.id) {
        case 'chef_hat': return true;
        case 'party_horn': return streak >= 3;
        case 'viking': return totalScans >= 10;
        default: return false;
      }
    }

    String getLockReason(Accessory hat) {
      if (hat.isBeta) return "Exclusivo Beta Founders 🚀";
      if (hat.needsAd) return "Ver anuncio para desbloquear 📺";
      switch (hat.id) {
        case 'party_horn': return "Necesitas racha de 3 días";
        case 'viking': return "Necesitas 10 scans";
        default: return "Bloqueado";
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TU COLECCIÓN", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Icon(Icons.arrow_forward, color: Colors.grey, size: 14)
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: allHats.length,
            itemBuilder: (context, index) {
              final hat = allHats[index];
              final bool unlocked = isUnlocked(hat);
              final bool isSelected = activeHatId == hat.id;

              return GestureDetector(
                onTap: () async {
                  if (unlocked) {
                    _equipHat(hat.id);
                  } else if (hat.needsAd && !hat.isBeta) {
                    _watchAdToUnlock(hat);
                  } else {
                    _showLockedReason(hat.name, getLockReason(hat));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 95,
                  margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? hat.color.withAlpha(30) : const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? hat.color
                          : (unlocked ? Colors.white10 : Colors.redAccent.withOpacity(0.3)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              hat.icon,
                              color: unlocked
                                  ? (isSelected ? hat.color : Colors.grey.shade700)
                                  : (hat.isBeta ? Colors.cyan.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
                              size: 34
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              hat.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unlocked ? (isSelected ? Colors.white : Colors.grey.shade600) : Colors.grey.shade800,
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // INDICADORES DE ESTADO
                      if (hat.isBeta && !unlocked)
                        const Positioned(top: 8, right: 8, child: Icon(Icons.rocket_launch, size: 12, color: Colors.cyanAccent))
                      else if (!unlocked && hat.needsAd)
                        const Positioned(top: 8, right: 8, child: Icon(Icons.play_circle_fill, size: 14, color: Colors.amber))
                      else if (!unlocked)
                          const Positioned(top: 8, right: 8, child: Icon(Icons.lock, size: 12, color: Colors.redAccent)),

                      if (isSelected)
                        Positioned(bottom: 8, child: Icon(Icons.check_circle, size: 14, color: hat.color)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (activeHatId != null)
          Center(
            child: TextButton.icon(
              onPressed: () => FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'active_hat': FieldValue.delete()}),
              icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              label: const Text("Quitar accesorio", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          ),
      ],
    );
  }

  void _showLockedReason(String item, String reason) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text("$item: $reason")),
            ],
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        )
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10)
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

  // 🔥 RECUPERADO: CAMPO DE URL CON BOTÓN DE AYUDA
  Widget _buildPhotoUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Foto de Perfil (URL)", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _showInstructionsDialog, // 💡 ABRE EL TUTORIAL
              child: const Row(
                children: [
                  Icon(Icons.help_outline, color: Color(0xFF00FF88), size: 14),
                  SizedBox(width: 5),
                  Text("¿Cómo obtener?", style: TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
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
              border: Border.all(color: Colors.white10)
          ),
          child: TextField(
            controller: _photoController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              hintText: "Pega aquí el link de tu imagen...",
            ),
            onChanged: (val) => setState(() => _previewPhoto = val),
          ),
        ),
      ],
    );
  }

  // 🔥 RECUPERADO: DIÁLOGO DE INSTRUCCIONES (LO QUE FALTABA)
  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Cómo obtener un link de imagen 📸", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _step("1", "Ve a Google Imágenes, Pinterest o Imgur."),
              _step("2", "Mantén presionado sobre la imagen que te guste."),
              _step("3", "Elige la opción 'Abrir imagen en pestaña nueva' o 'Copiar dirección de imagen'."),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Ejemplos de Links Válidos:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(height: 5),
                    Text("✅ https://i.imgur.com/foto.jpg", style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    Text("✅ https://i.pinimg.com/.../foto.png", style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    SizedBox(height: 5),
                    Text("❌ https://pinterest.com/pin/123 (Esto es una web, no una imagen)", style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ],
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF00FF88),
            child: Text(num, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        ],
      ),
    );
  }
}

// Widget auxiliar para sombra simple
class DropShadow extends StatelessWidget {
  final Widget child;
  const DropShadow({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 2, left: 2,
          child: Opacity(opacity: 0.5, child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn), child: child)),
        ),
        child,
      ],
    );
  }
}