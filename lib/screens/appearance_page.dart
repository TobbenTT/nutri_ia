import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_page.dart'; // Para reutilizar DonationPage si están bloqueados

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    // LISTA DE SKINS DEFINITIVA
    final List<Map<String, dynamic>> skins = [
      {'name': 'Matrix Green', 'color': 0xFF00FF88, 'vip': false}, // Gratis
      {'name': 'Gold VIP', 'color': 0xFFFFD700, 'vip': true},      // VIP
      {'name': 'Cyber Pink', 'color': 0xFFFF00FF, 'vip': true},    // VIP
      {'name': 'Deep Blue', 'color': 0xFF00BFFF, 'vip': true},     // VIP
      {'name': 'Red Alert', 'color': 0xFFFF3333, 'vip': true},     // VIP
      {'name': 'Royal Purple', 'color': 0xFF9D00FF, 'vip': true},  // VIP
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Apariencia", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final bool isVip = data['is_donor'] ?? false;
          final int currentColor = data['theme_color'] ?? 0xFF00FF88;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreviewCard(currentColor),
                const SizedBox(height: 30),
                const Text(
                  "SELECCIONA TU TEMA",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 columnas
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: skins.length,
                    itemBuilder: (context, index) {
                      final skin = skins[index];
                      final Color skinColor = Color(skin['color']);
                      final bool isLocked = skin['vip'] == true && !isVip;
                      final bool isSelected = currentColor == skin['color'];

                      return GestureDetector(
                        onTap: () {
                          if (isLocked) {
                            _showLockedDialog(context);
                          } else {
                            // ACTUALIZAR FIREBASE (El main.dart detectará el cambio automáticamente)
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({'theme_color': skin['color']});
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected
                                ? Border.all(color: skinColor, width: 2)
                                : Border.all(color: Colors.transparent),
                          ),
                          child: Stack(
                            children: [
                              // Color de fondo suave
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    gradient: LinearGradient(
                                      colors: [skinColor.withOpacity(0.1), Colors.transparent],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                              // Nombre y Círculo
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: skinColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: skinColor.withOpacity(0.5), blurRadius: 10)],
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, color: Colors.black)
                                          : (isLocked ? const Icon(Icons.lock, color: Colors.black) : null),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      skin['name'],
                                      style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.grey,
                                          fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Badge VIP
                              if (skin['vip'])
                                Positioned(
                                  top: 10, right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("VIP", style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Vista previa superior
  Widget _buildPreviewCard(int colorCode) {
    Color color = Color(colorCode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.palette, color: color, size: 40),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Vista Previa", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              const Text("Así se verán tus iconos", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  void _showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Skin Bloqueada 🔒", style: TextStyle(color: Colors.white)),
        content: const Text("Esta apariencia es exclusiva para miembros VIP.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            child: const Text("Hacerme VIP", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}