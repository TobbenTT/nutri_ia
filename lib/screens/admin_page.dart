import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Panel de Dios ⚡", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent.withOpacity(0.2), // Color diferente para saber que es zona peligrosa
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o correo...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),

          // LISTA DE USUARIOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // Filtramos la lista según la búsqueda
                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? "").toString().toLowerCase();
                  final email = (data['email'] ?? "").toString().toLowerCase();
                  return name.contains(_searchText) || email.contains(_searchText);
                }).toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isDonor = data['is_donor'] ?? false;
                    final String uid = doc.id;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: isDonor ? const BorderSide(color: Colors.amber, width: 1) : BorderSide.none,
                      ),
                      child: SwitchListTile(
                        activeThumbColor: Colors.amber,
                        title: Text(
                            data['name'] ?? "Sin Nombre",
                            style: TextStyle(
                                color: isDonor ? Colors.amber : Colors.white,
                                fontWeight: FontWeight.bold
                            )
                        ),
                        subtitle: Text(
                          data['email'] ?? "---",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        secondary: CircleAvatar(
                          // CORRECCIÓN: Solo usamos NetworkImage si hay texto real en la URL
                          backgroundImage: (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty)
                              ? NetworkImage(data['photoUrl'])
                              : null,
                          backgroundColor: Colors.grey.shade800,
                          child: (data['photoUrl'] == null || data['photoUrl'].toString().isEmpty)
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        value: isDonor,
                        onChanged: (newValue) async {
                          // AQUÍ OCURRE LA MAGIA: Actualizamos Firebase al instante
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({'is_donor': newValue});
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}