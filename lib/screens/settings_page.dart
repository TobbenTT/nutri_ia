import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// TUS PÁGINAS IMPORTADAS
import 'calendar_page.dart';
import 'diet_page.dart';
import 'admin_page.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'terms_page.dart';
import 'appearance_page.dart';
import 'profile_page.dart'; // IMPORTANTE: Aquí está la lista allHats

// =======================================================
// SETTINGS PAGE - PRINCIPAL
// =======================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // ---------------------------------------------------
  // DIÁLOGO DE CAMBIO DE CONTRASEÑA SOLAMENTE
  // (Los de nombre y foto se han eliminado de esta vista rápida)
  // ---------------------------------------------------

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Cambiar Contraseña", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPassController,
                    obscureText: obscureCurrent,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Contraseña Actual",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                        onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: newPassController,
                    obscureText: obscureNew,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Nueva Contraseña",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                        onPressed: () => setState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    final currentPass = currentPassController.text.trim();
                    final newPass = newPassController.text.trim();
                    if (currentPass.isEmpty || newPass.isEmpty) return;

                    setState(() => isLoading = true);
                    try {
                      final cred = EmailAuthProvider.credential(email: user!.email!, password: currentPass);
                      await user!.reauthenticateWithCredential(cred);
                      await user!.updatePassword(newPass);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Contraseña actualizada!"), backgroundColor: Color(0xFF00FF88)));
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
                  child: const Text("Actualizar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        String displayName = "Usuario";
        String photoUrl = "";
        bool isDonor = false;
        String plan = "Plan Gratuito";
        String? activeHatId;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['display_name'] ?? data['name'] ?? user!.displayName ?? "Usuario";
          photoUrl = data['photoUrl'] ?? data['photo_url'] ?? "";
          isDonor = data['is_donor'] ?? false;
          activeHatId = data['active_hat'];
          plan = isDonor ? "Plan Donador 👑" : "Plan Gratuito";
        }

        return Scaffold(
          backgroundColor: const Color(0xFF050505),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Ajustes",
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),

                  // ===================================================
                  // TARJETA DE PERFIL (Simplificada y con gorrito ajustado)
                  // ===================================================
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1F1F1F), const Color(0xFF0A0A0A).withAlpha(200)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDonor ? const Color(0xFFFFD700).withAlpha(128) : Colors.white10,
                        width: isDonor ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // ----- SECCIÓN AVATAR CON GORRITO -----
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter, // Alineación superior para el gorro
                          children: [
                            // El Avatar base
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0), // Un poco de espacio para que el gorro no se corte arriba
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[800],
                                foregroundImage: (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            // LÓGICA PARA PINTAR EL GORRITO (POSICIÓN AJUSTADA)
                            if (activeHatId != null)
                              Builder(
                                  builder: (context) {
                                    final hat = allHats.firstWhere(
                                            (h) => h.id == activeHatId,
                                        orElse: () => allHats[0]
                                    );
                                    return Positioned(
                                      top: -5, // Ajustado para que "aterrice" en la cabeza
                                      child: Icon(hat.icon, color: hat.color, size: 42), // Tamaño ligeramente mayor
                                    );
                                  }
                              ),
                            // NOTA: Se han eliminado los iconos de edición de cámara aquí.
                          ],
                        ),
                        // --------------------------------------

                        const SizedBox(width: 20),
                        // Información de texto simplificada (sin botón de editar nombre)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  color: isDonor ? const Color(0xFFFFD700) : Colors.white,
                                  fontSize: 22, // Un poco más grande
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(user?.email ?? "", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDonor ? const Color(0xFFFFD700).withOpacity(0.2) : const Color(0xFF00FF88).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(plan, style: TextStyle(color: isDonor ? const Color(0xFFFFD700) : const Color(0xFF00FF88), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ===================================================
                  // BOTÓN DE LOGROS (Movido aquí, debajo del perfil)
                  // ===================================================
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage())
                    ),
                    icon: const Icon(Icons.workspace_premium, color: Colors.black),
                    label: const Text("VER MIS LOGROS Y GORRITOS", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: const Color(0xFF00FF88).withOpacity(0.4),
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSectionHeader("HERRAMIENTAS"),
                  _buildMenuTile(
                    icon: Icons.palette,
                    title: "Apariencia",
                    subtitle: "Personaliza los colores de la app",
                    color: Colors.cyanAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearancePage())),
                  ),

                  _buildMenuTile(
                    icon: Icons.restaurant_menu,
                    title: "Chef IA / Crear Dieta",
                    subtitle: "Crea planes alimenticios personalizados",
                    color: Colors.purpleAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietPage())),
                  ),

                  _buildMenuTile(
                    icon: Icons.flag,
                    title: "Meta Diaria",
                    subtitle: "Ajusta tus calorías objetivo",
                    color: const Color(0xFF00FF88),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalorieGoalPage())),
                  ),

                  _buildMenuTile(
                    icon: Icons.accessibility_new,
                    title: "Perfil Físico",
                    subtitle: "Peso, altura, edad y más",
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhysicalProfilePage())),
                  ),

                  _buildMenuTile(
                    icon: Icons.history,
                    title: "Historial Completo",
                    subtitle: "Revisa tu progreso",
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage())),
                  ),

                  const SizedBox(height: 30),

                  _buildSectionHeader("SOPORTE"),
                  const SizedBox(height: 10),

                  _buildMenuTile(
                    icon: Icons.favorite,
                    title: "Apoyar / Donar",
                    subtitle: "Ayuda a mejorar Nutri_IA",
                    color: Colors.pinkAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationPage())),
                  ),

                  const SizedBox(height: 30),

                  if (user?.email == "david.cabezas.armando@gmail.com") ...[
                    _buildSectionHeader("ADMINISTRACIÓN"),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      icon: Icons.admin_panel_settings,
                      title: "Panel de Dios",
                      subtitle: "Gestionar usuarios y permisos",
                      color: Colors.redAccent,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage())),
                    ),
                    const SizedBox(height: 30),
                  ],

                  _buildSectionHeader("CUENTA"),
                  const SizedBox(height: 10),

                  // Nota: Aquí es donde el usuario debería ir para editar nombre/foto realmente
                  _buildMenuTile(
                    icon: Icons.edit_note,
                    title: "Editar Perfil Completo",
                    subtitle: "Cambia nombre, foto y metas",
                    color: const Color(0xFF00FF88),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage())),
                  ),

                  _buildMenuTile(
                    icon: Icons.lock,
                    title: "Cambiar Contraseña",
                    subtitle: "Actualiza tu seguridad",
                    color: Colors.grey,
                    onTap: _showChangePasswordDialog,
                  ),

                  _buildMenuTile(
                    icon: Icons.privacy_tip,
                    title: "Privacidad",
                    subtitle: "Gestiona tus datos y visibilidad",
                    color: Colors.grey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage())),
                  ),

                  _buildMenuTile(
                    icon: Icons.gavel,
                    title: "Términos y Condiciones",
                    subtitle: "Reglas de uso",
                    color: Colors.grey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage(isViewOnly: true))),
                  ),

                  const SizedBox(height: 40),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
                            content: const Text("¿Estás seguro que deseas cerrar sesión?", style: TextStyle(color: Colors.grey)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                child: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      label: const Text("CERRAR SESIÓN", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        backgroundColor: Colors.redAccent.withOpacity(0.05),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Center(
                    child: Column(
                      children: [
                        Text("Nutri_IA", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Versión 1.0.5 • Hecho con 💚", style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String title, required String subtitle, required Color color, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade700, size: 16),
      ),
    );
  }
}

// =====================================================================
// LAS OTRAS CLASES (CalorieGoalPage, PhysicalProfilePage, etc.)
// SE MANTIENEN IGUAL QUE EN EL ARCHIVO ORIGINAL ABAJO DE ESTO.
// =====================================================================
// NOTA: Para que el código funcione completo, asegúrate de que las clases
// CalorieGoalPage, PhysicalProfilePage, DonationPage y PrivacyPage
// sigan estando al final del archivo, tal como estaban en tu versión anterior.
// Por brevedad, no las he repetido aquí ya que no requerían cambios.
// Si las necesitas, dímelo y te paso el archivo entero de 600 líneas.

class CalorieGoalPage extends StatefulWidget {
  const CalorieGoalPage({super.key});
  @override
  State<CalorieGoalPage> createState() => _CalorieGoalPageState();
}

class _CalorieGoalPageState extends State<CalorieGoalPage> {
  final _caloriesController = TextEditingController(text: "2000");
  String _activityLevel = 'Moderado';
  String _goal = 'Mantener';

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _caloriesController.text = (data['daily_goal'] ?? 2000).toString();
        _activityLevel = data['activity_level'] ?? 'Moderado';
        _goal = data['goal'] ?? 'Mantener';
      });
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'daily_goal': int.tryParse(_caloriesController.text) ?? 2000,
        'activity_level': _activityLevel,
        'goal': _goal,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meta actualizada"), backgroundColor: Color(0xFF00FF88)));
      }
    }
  }

  void _calculate() {
    int base = 2000;
    if (_activityLevel == 'Sedentario') base = 1800;
    if (_activityLevel == 'Activo') base = 2200;
    if (_activityLevel == 'Muy Activo') base = 2500;
    if (_goal == 'Perder peso') base -= 300;
    if (_goal == 'Ganar masa') base += 300;
    setState(() => _caloriesController.text = base.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(title: const Text("Meta Diaria", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _activityLevel,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: "Nivel de Actividad", filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: ['Sedentario', 'Moderado', 'Activo', 'Muy Activo'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _activityLevel = v!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _goal,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: "Objetivo", filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: ['Perder peso', 'Mantener', 'Ganar masa'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3))),
              child: Column(
                children: [
                  const Text("Calorías Recomendadas", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _caloriesController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF00FF88), fontSize: 48, fontWeight: FontWeight.bold),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: InputBorder.none, suffix: Text("kcal", style: TextStyle(color: Colors.grey, fontSize: 16))),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(onPressed: _calculate, icon: const Icon(Icons.auto_awesome), label: const Text("Recalcular con IA"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white)),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), padding: const EdgeInsets.all(16)), child: const Text("GUARDAR META", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            )
          ],
        ),
      ),
    );
  }
}

class PhysicalProfilePage extends StatefulWidget {
  const PhysicalProfilePage({super.key});
  @override
  State<PhysicalProfilePage> createState() => _PhysicalProfilePageState();
}

class _PhysicalProfilePageState extends State<PhysicalProfilePage> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Hombre';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _weightController.text = (data['weight'] ?? 70).toString();
        _heightController.text = (data['height'] ?? 170).toString();
        _ageController.text = (data['age'] ?? 25).toString();
        _gender = data['gender'] ?? 'Hombre';
      });
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'weight': double.tryParse(_weightController.text) ?? 70,
        'height': double.tryParse(_heightController.text) ?? 170,
        'age': int.tryParse(_ageController.text) ?? 25,
        'gender': _gender,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perfil actualizado"), backgroundColor: Color(0xFF00FF88)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(title: const Text("Perfil Físico", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildInput("Peso (kg)", _weightController, Icons.monitor_weight),
                  const SizedBox(height: 15),
                  _buildInput("Altura (cm)", _heightController, Icons.height),
                  const SizedBox(height: 15),
                  _buildInput("Edad", _ageController, Icons.cake),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: "Género", filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: ['Hombre', 'Mujer', 'Otro'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), padding: const EdgeInsets.all(16)), child: const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(icon, color: Colors.grey)),
      keyboardType: TextInputType.number,
    );
  }
}

class DonationPage extends StatelessWidget {
  const DonationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(title: const Text("Donaciones", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.volunteer_activism, size: 80, color: Colors.pinkAccent),
              const SizedBox(height: 30),
              const Text("¡Apoya a Nutri_IA!", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Text("Tu ayuda permite mejorar la IA y mantener los servidores.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.pinkAccent.withOpacity(0.3))),
                child: const Column(children: [
                  Text("Beneficios Donador 👑", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text("✓ Badge especial\n✓ Acceso anticipado\n✓ Soporte prioritario", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://nutriia.001webhospedaje.com');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el sitio web")));
                    }
                  },
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  label: const Text("IR A LA WEB PARA DONAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, padding: const EdgeInsets.all(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (mounted && doc.exists) {
      setState(() => _isPrivate = doc.data()?['is_private_profile'] ?? false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Text("⚠️ ELIMINAR CUENTA", style: TextStyle(color: Colors.white)),
        content: const Text("Se borrarán todos tus datos. ¿Seguro?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar", style: TextStyle(color: Colors.white))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.black), child: const Text("BORRAR TODO", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
        await user!.delete();
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Re-inicia sesión para borrar.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Privacidad", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            activeColor: Theme.of(context).primaryColor,
            title: const Text("Perfil Privado", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Ocultar perfil en búsquedas", style: TextStyle(color: Colors.grey)),
            value: _isPrivate,
            onChanged: (val) async {
              setState(() => _isPrivate = val);
              await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'is_private_profile': val});
            },
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Eliminar Cuenta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}