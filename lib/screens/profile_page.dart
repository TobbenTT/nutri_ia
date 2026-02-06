import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diet_page.dart';
import 'settings_page.dart';
import '../widgets/weekly_chart.dart'; // Si tienes el archivo, si no, comenta esta línea

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // TU CORREO DE ADMIN
    const String adminEmail = "david.cabezas.armando@gmail.com";

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final score = data['social_score'] ?? 0;
          final name = data['display_name'] ?? data['name'] ?? "Usuario";
          final code = data['friend_code'] ?? "---";
          final photo = data['photoUrl'];

          // ESTADOS DEL USUARIO
          final bool isDonor = data['is_donor'] ?? false;
          final bool isAdmin = (user.email == adminEmail); // ¿Es el Dios?

          // COLORES DINÁMICOS
          Color mainColor;
          Color secondaryColor;
          IconData badgeIcon;
          String badgeText;

          if (isAdmin) {
            mainColor = Colors.redAccent; // Rojo Admin
            secondaryColor = const Color(0xFF4A0000); // Rojo oscuro
            badgeIcon = Icons.security;
            badgeText = "ADMINISTRADOR 🛡️";
          } else if (isDonor) {
            mainColor = const Color(0xFFFFD700); // Dorado
            secondaryColor = const Color(0xFF332a00); // Dorado oscuro
            badgeIcon = Icons.verified;
            badgeText = "MIEMBRO VIP 👑";
          } else {
            mainColor = const Color(0xFF00FF88); // Verde normal
            secondaryColor = const Color(0xFF1E1E1E); // Gris
            badgeIcon = Icons.person;
            badgeText = "USUARIO";
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. TARJETA DE PERFIL (DISEÑO INTELIGENTE)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isAdmin || isDonor
                      ? LinearGradient(
                      colors: [secondaryColor, Colors.black],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter
                  )
                      : null,
                  color: (isAdmin || isDonor) ? null : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: (isAdmin || isDonor) ? mainColor.withOpacity(0.5) : Colors.transparent,
                      width: isAdmin ? 2 : 1
                  ),
                  boxShadow: isAdmin ? [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 20)] : [],
                ),
                child: Column(
                  children: [
                    // FOTO DE PERFIL
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: mainColor, width: 3),
                        boxShadow: (isAdmin || isDonor) ? [
                          BoxShadow(color: mainColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)
                        ] : [],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.black,
                        backgroundImage: (photo != null && photo.toString().isNotEmpty)
                            ? NetworkImage(photo)
                            : null,
                        child: (photo == null || photo.toString().isEmpty)
                            ? Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // NOMBRE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            name,
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: (isAdmin || isDonor) ? mainColor : Colors.white
                            )
                        ),
                        if (isAdmin || isDonor) ...[
                          const SizedBox(width: 8),
                          Icon(badgeIcon, color: mainColor, size: 24),
                        ]
                      ],
                    ),

                    // ID
                    const SizedBox(height: 5),
                    Text("ID: $code", style: const TextStyle(color: Colors.grey, fontSize: 14)),

                    // ETIQUETA ESPECIAL
                    if (isAdmin || isDonor) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: mainColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: mainColor.withOpacity(0.4), blurRadius: 10)]
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 2. GRÁFICO (Placeholder o Widget Real)
              const Text("Tu Progreso", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),
              Container(
                height: 200,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: Text("Gráfico Semanal", style: TextStyle(color: Colors.grey))),
              ),

              const SizedBox(height: 30),

              // 3. BOTÓN IA (Cambia de color si eres Admin/Donor)
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietPage())),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: isAdmin ? Colors.redAccent : (isDonor ? const Color(0xFFFFD700) : Colors.purpleAccent),
                  foregroundColor: (isAdmin || isDonor) ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: (isAdmin || isDonor) ? 10 : 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isAdmin ? Icons.security : (isDonor ? Icons.star : Icons.auto_awesome)),
                    const SizedBox(width: 10),
                    Text(
                        isAdmin ? "PANEL DE IA (ADMIN)" : (isDonor ? "ACCESO CHEF VIP" : "CREAR MI DIETA CON IA"),
                        style: const TextStyle(fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 4. LOGROS
              const Text("Mis Logros", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  _buildMedal("Creador", "Desarrollador", isAdmin, Icons.code, color: Colors.redAccent), // MEDALLA ADMIN
                  _buildMedal("Donador", "Apoya la App", isDonor, Icons.volunteer_activism, color: const Color(0xFFFFD700)),
                  _buildMedal("Novato", "Regístrate", true, Icons.star, color: const Color(0xFF00FF88)),
                  _buildMedal("Atleta", "Supera 1000 pts", score > 1000, Icons.fitness_center, color: const Color(0xFF00FF88)),
                  _buildMedal("Leyenda", "Supera 5000 pts", score > 5000, Icons.emoji_events, color: const Color(0xFF00FF88)),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedal(String title, String desc, bool unlocked, IconData icon, {required Color color}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? color.withOpacity(0.1) : Colors.black12,
        border: Border.all(color: unlocked ? color : Colors.grey[800]!),
        borderRadius: BorderRadius.circular(15),
        boxShadow: unlocked ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)] : [],
      ),
      child: Column(
        children: [
          Icon(icon, color: unlocked ? color : Colors.grey, size: 30),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: unlocked ? Colors.white : Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          Text(desc, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
      ),
    );
  }
}