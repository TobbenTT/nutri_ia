import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diet_page.dart';
import 'settings_page.dart';
import '../widgets/weekly_chart.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil Legendario"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final score = data['social_score'] ?? 0;
          final name = data['name'] ?? "Usuario";
          final code = data['friend_code'] ?? "---";
          final photo = data['photoUrl'];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. CABECERA
              Center(
                child: Column(
                  children: [
                    // FOTO DE PERFIL DINÁMICA
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF00FF88),
                      backgroundImage: (photo != null && photo.toString().isNotEmpty)
                          ? NetworkImage(photo)
                          : null,
                      child: (photo == null || photo.toString().isEmpty)
                          ? const Icon(Icons.person, size: 50, color: Colors.black)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    // ESTOS TEXTOS FALTABAN EN TU CÓDIGO
                    Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00FF88))),
                    Text("ID: $code", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. GRÁFICO SEMANAL
              const Text("Tu Progreso", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const SizedBox(
                height: 200,
                child: WeeklyChart(),
              ),
              const SizedBox(height: 30),

              // 3. BOTÓN DIETA IA
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietPage())),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome),
                    SizedBox(width: 10),
                    Text("CREAR MI DIETA CON IA", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 4. SECCIÓN DE LOGROS (MEDALLAS)
              const Text("Mis Logros", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  _buildMedal("Novato", "Regístrate", true, Icons.star),
                  _buildMedal("Explorador", "Escanea 1 comida", score > 0, Icons.camera_alt),
                  _buildMedal("Atleta", "Supera 1000 pts", score > 1000, Icons.fitness_center),
                  _buildMedal("Leyenda", "Supera 5000 pts", score > 5000, Icons.emoji_events),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedal(String title, String desc, bool unlocked, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFF1A1A1A) : Colors.black12,
        border: Border.all(color: unlocked ? const Color(0xFF00FF88) : Colors.grey[800]!),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: unlocked ? const Color(0xFF00FF88) : Colors.grey, size: 30),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: unlocked ? Colors.white : Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          Text(desc, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
      ),
    );
  }
}