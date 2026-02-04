import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- FUNCIÓN PARA AGREGAR AMIGO ---
  Future<void> _addFriend() async {
    if (_emailController.text.isEmpty) return;

    final String codeToSearch = _emailController.text.trim(); // Ahora es el código

    try {
      // BÚSQUEDA POR FRIEND_CODE
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('friend_code', isEqualTo: codeToSearch) // <--- Cambio clave
          .get();

      if (query.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código no encontrado. Revisa mayúsculas/minúsculas.")));
        return;
      }

      final friendDoc = query.docs.first;
      final friendId = friendDoc.id;

      if (friendId == currentUser?.uid) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Ese eres tú! 😅")));
        return;
      }

      // El resto sigue igual (agregar a la lista)
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'friends': FieldValue.arrayUnion([friendId])
      });

      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("¡${friendDoc['name']} agregado al equipo!")));
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- DIÁLOGO DE BÚSQUEDA ---
  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Amigo"),
        content: TextField(
          controller: _emailController,
          // Busca _showAddFriendDialog y cambia el TextField:
          decoration: const InputDecoration(
            labelText: "Código de Amigo",
            hintText: "Ej: David#4521", // <--- Nuevo ejemplo
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(onPressed: _addFriend, child: const Text("Agregar")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // AQUI ESTÁ EL CAMBIO: Título dinámico con tu ID
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
          builder: (context, snapshot) {
            String myCode = "..."; // Texto mientras carga

            if (snapshot.hasData && snapshot.data!.data() != null) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              // Si el campo 'friend_code' no existe (usuarios viejos), muestra "Sin Código"
              myCode = data['friend_code'] ?? "Sin Código";
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Comunidad"),
                Text(
                  "Tu ID: $myCode",
                  style: const TextStyle(fontSize: 14, color: Colors.greenAccent),
                ),
              ],
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "RANKING", icon: Icon(Icons.leaderboard)),
            Tab(text: "MIS AMIGOS", icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // PESTAÑA 1: RANKING
          _buildRankingTab(),

          // PESTAÑA 2: LISTA DE AMIGOS
          _buildFriendsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: const Color(0xFF00E676),
        child: const Icon(Icons.person_add, color: Colors.black),
      ),
    );
  }

  Widget _buildRankingTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // Obtenemos la lista de IDs de amigos + el mío
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];
        friendsIds.add(currentUser!.uid); // Me incluyo para competir

        // Consultamos los datos de todos esos usuarios
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendsIds) // Filtro mágico
              .snapshots(),
          builder: (context, friendsSnapshot) {
            if (!friendsSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            final users = friendsSnapshot.data!.docs;

            // Ordenamos por puntaje (social_score) de mayor a menor
            // Nota: Aquí podrías ordenar por quién comió MÁS o MENOS, depende la competencia
            users.sort((a, b) {
              int scoreA = (a.data() as Map)['social_score'] ?? 0;
              int scoreB = (b.data() as Map)['social_score'] ?? 0;
              return scoreB.compareTo(scoreA); // Descendente
            });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userDoc = users[index].data() as Map<String, dynamic>;
                final name = userDoc['name'] ?? 'Sin Nombre';
                final score = userDoc['social_score'] ?? 0;
                final bool isMe = users[index].id == currentUser!.uid;

                // Trofeos para los top 3
                Widget? trophy;
                if (index == 0) trophy = const Text("🥇", style: TextStyle(fontSize: 24));
                if (index == 1) trophy = const Text("🥈", style: TextStyle(fontSize: 24));
                if (index == 2) trophy = const Text("🥉", style: TextStyle(fontSize: 24));

                return Card(
                  color: isMe ? const Color(0xFF2C3E50) : const Color(0xFF1E1E1E), // Resaltar mi usuario
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? const Color(0xFF00E676) : Colors.white)),
                    subtitle: Text("$score kcal hoy"),
                    trailing: trophy ?? Text("#${index + 1}", style: const TextStyle(color: Colors.grey)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsList() {
    // Reutilizamos lógica similar pero solo mostramos lista simple
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];

        if (friendsIds.isEmpty) {
          return const Center(child: Text("Aún no tienes amigos. ¡Invita a alguien!", style: TextStyle(color: Colors.grey)));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: friendsIds).snapshots(),
          builder: (context, listSnap) {
            if (!listSnap.hasData) return const Center(child: CircularProgressIndicator());

            return ListView(
              children: listSnap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF00E676)),
                  title: Text(d['name'] ?? "Usuario"),
                  subtitle: Text(d['email'] ?? ""),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      // Lógica para borrar amigo (opcional)
                    },
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}