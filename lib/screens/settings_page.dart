import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_page.dart';
import 'diet_page.dart';
import 'admin_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'terms_page.dart';

// =======================================================
// SETTINGS PAGE - CON STREAMBUILDER (DETECTA VIP EN VIVO)
// =======================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Diálogo para editar nombre
  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Editar Nombre", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Tu nombre...",
            hintStyle: TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.black45,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && user != null) {
                // Actualizamos solo Firestore, el StreamBuilder actualizará la UI solo
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .update({'display_name': newName});

                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            child: const Text("Guardar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  // Diálogo para editar foto
  void _showEditPhotoDialog(String currentUrl) {
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cambiar Foto", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Pega la URL de una imagen",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "https://ejemplo.com/foto.jpg",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black45,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .update({'photoUrl': newUrl});

                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            child: const Text("Guardar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
// 🔒 DIÁLOGO CAMBIAR CONTRASEÑA
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
                  // CAMPO: CONTRASEÑA ACTUAL
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
                        icon: Icon(
                          obscureCurrent ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // CAMPO: NUEVA CONTRASEÑA
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
                        icon: Icon(
                          obscureNew ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
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

                    if (currentPass.isEmpty || newPass.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Rellena ambos campos")),
                      );
                      return;
                    }

                    if (newPass.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("La nueva contraseña debe tener al menos 6 caracteres")),
                      );
                      return;
                    }

                    setState(() => isLoading = true);

                    try {
                      // 1. Re-autenticar al usuario
                      final cred = EmailAuthProvider.credential(
                        email: user!.email!,
                        password: currentPass,
                      );
                      await user!.reauthenticateWithCredential(cred);

                      // 2. Actualizar contraseña
                      await user!.updatePassword(newPass);

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("¡Contraseña actualizada con éxito! 🔒"),
                            backgroundColor: Color(0xFF00FF88),
                          ),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      setState(() => isLoading = false);
                      String errorMsg = "Error al cambiar contraseña";
                      if (e.code == 'wrong-password') {
                        errorMsg = "La contraseña actual es incorrecta";
                      } else if (e.code == 'weak-password') {
                        errorMsg = "La nueva contraseña es muy débil";
                      } else if (e.code == 'requires-recent-login') {
                        errorMsg = "Por seguridad, cierra sesión y vuelve a entrar";
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
                      );
                    } catch (e) {
                      setState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                      );
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

    // Usamos StreamBuilder para escuchar cambios en tiempo real (VIP/Gratis)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {

        // Valores por defecto mientras carga
        String displayName = "Usuario";
        String photoUrl = "";
        bool isDonor = false;
        String plan = "Plan Gratuito";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['display_name'] ?? data['name'] ?? user!.displayName ?? "Usuario";
          photoUrl = data['photoUrl'] ?? data['photo_url'] ?? "";
          isDonor = data['is_donor'] ?? false; // AQUÍ LEE EL ESTADO
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
                  // Header
                  const Text(
                    "Ajustes",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ✅ TARJETA DE PERFIL DINÁMICA
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1F1F1F),
                          const Color(0xFF0A0A0A).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDonor ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.white10,
                        width: isDonor ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar con botón de edición
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[800],
                              // 1. Usamos foregroundImage para intentar cargar la foto encima
                              foregroundImage: (photoUrl.isNotEmpty)
                                  ? NetworkImage(photoUrl)
                                  : null,
                              // 2. MAGIA AQUÍ: Si el link es malo (error), ignoramos el error y se muestra el texto de abajo
                              onForegroundImageError: (_, __) {},
                              // 3. Este texto se muestra si no hay foto O si la foto falló
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () => _showEditPhotoDialog(photoUrl),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00FF88),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),

                        // Información del usuario
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        color: isDonor ? const Color(0xFFFFD700) : Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _showEditNameDialog(displayName),
                                    icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? "Sin correo",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDonor
                                      ? const Color(0xFFFFD700).withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDonor
                                        ? const Color(0xFFFFD700)
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  plan,
                                  style: TextStyle(
                                    color: isDonor ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 👇👇 AQUÍ PEGAS LA LLAMADA AL SELECTOR 👇👇
                  _buildThemeSelector(isDonor),
                  const SizedBox(height: 30),

                  // SECCIÓN: HERRAMIENTAS
                  _buildSectionHeader("HERRAMIENTAS"),
                  const SizedBox(height: 10),

                  _buildMenuTile(
                    icon: Icons.restaurant_menu,
                    title: "Chef IA / Crear Dieta",
                    subtitle: "Crea planes alimenticios personalizados",
                    color: Colors.purpleAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DietPage()),
                    ),
                  ),

                  _buildMenuTile(
                    icon: Icons.flag,
                    title: "Meta Diaria",
                    subtitle: "Ajusta tus calorías objetivo",
                    color: const Color(0xFF00FF88),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CalorieGoalPage()),
                    ),
                  ),

                  _buildMenuTile(
                    icon: Icons.accessibility_new,
                    title: "Perfil Físico",
                    subtitle: "Peso, altura, edad y más",
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PhysicalProfilePage()),
                    ),
                  ),

                  _buildMenuTile(
                    icon: Icons.history,
                    title: "Historial Completo",
                    subtitle: "Revisa tu progreso",
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CalendarPage()),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // SECCIÓN: SOPORTE
                  _buildSectionHeader("SOPORTE"),
                  const SizedBox(height: 10),

                  _buildMenuTile(
                    icon: Icons.favorite,
                    title: "Apoyar / Donar",
                    subtitle: "Ayuda a mejorar Nutri_IA",
                    color: Colors.pinkAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DonationPage()),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ---------------------------------------------------------
                  // ZONA ADMIN (SOLO VISIBLE PARA TI)
                  // ---------------------------------------------------------
                  if (user?.email == "david.cabezas.armando@gmail.com") ...[
                    _buildSectionHeader("ADMINISTRACIÓN"),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      icon: Icons.admin_panel_settings,
                      title: "Panel de Dios",
                      subtitle: "Gestionar usuarios y permisos",
                      color: Colors.redAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminPage()),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // SECCIÓN: CUENTA (REDISEÑADA)
                  _buildSectionHeader("CUENTA"),
                  const SizedBox(height: 10),

                  // 1. EDITAR PERFIL (Ahora integrado)
                  _buildMenuTile(
                    icon: Icons.edit_note,
                    title: "Editar Meta y Nombre",
                    subtitle: "Cambia tus calorías diarias y nombre",
                    color: const Color(0xFF00FF88),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfilePage()),
                    ),
                  ),

                  // 2. OTROS AJUSTES DE CUENTA
                  _buildMenuTile(
                    icon: Icons.lock,
                    title: "Cambiar Contraseña",
                    subtitle: "Actualiza tu contraseña",
                    color: Colors.grey,
                    onTap: () {
                      // BORRA LO QUE HAY AQUÍ (el SnackBar) Y PON ESTO:
                      _showChangePasswordDialog();
                    },
                  ),

                  // 2. PRIVACIDAD (BUSCA ESTO Y CAMBIA EL ONTAP)
                  _buildMenuTile(
                    icon: Icons.privacy_tip,
                    title: "Privacidad",
                    subtitle: "Gestiona tus datos",
                    color: Colors.grey,
                    onTap: () {
                      // ✅ AHORA NAVEGAMOS A LA PÁGINA REAL
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PrivacyPage()),
                      );
                    },
                  ),

                  // 3. TÉRMINOS Y CONDICIONES
                  _buildMenuTile(
                    icon: Icons.gavel,
                    title: "Términos y Condiciones",
                    subtitle: "Reglas de uso",
                    color: Colors.grey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TermsPage(isViewOnly: true)), // <--- MODO LECTURA
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // BOTÓN CERRAR SESIÓN (MEJORADO)
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
                            content: const Text(
                              "¿Estás seguro que deseas cerrar sesión?",
                              style: TextStyle(color: Colors.grey),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                              ),
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
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                                  (route) => false,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      label: const Text(
                        "CERRAR SESIÓN",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        backgroundColor: Colors.redAccent.withOpacity(0.05),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Nutri_IA",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Versión 1.0.3 • Hecho con 💚",
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 10,
                          ),
                        ),
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
    return Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey.shade700,
          size: 16,
        ),
      ),
    );
  }



  // 🎨 NUEVO: SELECTOR DE SKINS (Pega esto al final de la clase _SettingsPageState)
  Widget _buildThemeSelector(bool isVip) {
    // Definimos los colores disponibles
    final List<Map<String, dynamic>> skins = [
      {'name': 'Matrix', 'color': 0xFF00FF88, 'vip': false}, // Gratis
      {'name': 'Gold', 'color': 0xFFFFD700, 'vip': true},   // VIP
      {'name': 'Pink', 'color': 0xFFFF00FF, 'vip': true},   // VIP
      {'name': 'Blue', 'color': 0xFF00BFFF, 'vip': true},   // VIP
      {'name': 'Red', 'color': 0xFFFF3333, 'vip': true},    // VIP
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 10),
          child: Text(
              "PERSONALIZACIÓN (SKINS)",
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5
              )
          ),
        ),

        // Carrusel horizontal de colores
        SizedBox(
          height: 65,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: skins.length,
            itemBuilder: (context, index) {
              final skin = skins[index];
              final Color skinColor = Color(skin['color']);

              // Verificamos si está bloqueado (Es VIP y el usuario NO es VIP)
              final bool isLocked = skin['vip'] == true && !isVip;

              return GestureDetector(
                onTap: () {
                  if (isLocked) {
                    // Si está bloqueado, mostramos mensaje
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("👑 Skin exclusiva para usuarios VIP"),
                          backgroundColor: Colors.amber,
                          duration: Duration(seconds: 2),
                        )
                    );
                  } else {
                    // Si está desbloqueado, guardamos el color en Firebase
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .update({'theme_color': skin['color']});
                  }
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(
                    color: skinColor.withOpacity(0.1), // Fondo transparente
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: skinColor,
                        width: isLocked ? 1 : 3 // Borde más grueso si está activo
                    ),
                  ),
                  child: Center(
                    child: isLocked
                        ? const Icon(Icons.lock, color: Colors.white, size: 20)
                        : (skin['vip'] ? const Icon(Icons.star, color: Colors.white, size: 14) : null),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// =======================================================
// PÁGINA: META DE CALORÍAS (SIN CAMBIOS)
// =======================================================
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

  @override
  void dispose() {
    _caloriesController.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Meta actualizada correctamente"),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
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
      appBar: AppBar(
        title: const Text("Meta Diaria", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDropdown(
              "Nivel de Actividad",
              _activityLevel,
              ['Sedentario', 'Moderado', 'Activo', 'Muy Activo'],
                  (v) => setState(() => _activityLevel = v!),
            ),
            const SizedBox(height: 15),
            _buildDropdown(
              "Objetivo",
              _goal,
              ['Perder peso', 'Mantener', 'Ganar masa'],
                  (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E1E1E),
                    const Color(0xFF0A0A0A).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    "Calorías Recomendadas",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _caloriesController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      suffix: Text("kcal", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text("Recalcular con IA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  "GUARDAR META",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

// =======================================================
// PÁGINA: PERFIL FÍSICO (SIN CAMBIOS)
// =======================================================
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

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Perfil actualizado correctamente"),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Perfil Físico", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
                    initialValue: _gender,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Género",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.people, color: Colors.grey),
                    ),
                    items: ['Hombre', 'Mujer', 'Otro']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  "GUARDAR CAMBIOS",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      keyboardType: TextInputType.number,
    );
  }
}



// =======================================================
// PÁGINA: DONACIONES (SIN CAMBIOS)
// =======================================================
class DonationPage extends StatelessWidget {
  const DonationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Donaciones", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  color: Colors.pinkAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism,
                  size: 80,
                  color: Colors.pinkAccent,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "¡Apoya a Nutri_IA!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Tu ayuda permite mejorar la IA, mantener los servidores y agregar nuevas funciones.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.pinkAccent.withOpacity(0.2),
                      Colors.purpleAccent.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Beneficios Donador 👑",
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildBenefit("✓ Badge especial en tu perfil"),
                    _buildBenefit("✓ Acceso anticipado a nuevas funciones"),
                    _buildBenefit("✓ Soporte prioritario"),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // TU ENLACE REAL
                    final Uri url = Uri.parse('https://nutriia.001webhospedaje.com');

                    // Intentamos abrir el navegador externo (Chrome/Safari)
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No se pudo abrir el sitio web")),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  label: const Text(
                    "IR A LA WEB PARA DONAR", // Texto más claro
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}

// 🛡️ PÁGINA DE PRIVACIDAD (Pegar al final del archivo)
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text("BORRAR TODO", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
        await user!.delete();
        if (mounted) {
          // Asegúrate de tener importado login_page.dart o usa '/'
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
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
