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
    final String codeToSearch = _emailController.text.trim();

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('friend_code', isEqualTo: codeToSearch)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código no encontrado.")));
        return;
      }

      final friendDoc = query.docs.first;
      final friendId = friendDoc.id;

      if (friendId == currentUser?.uid) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Ese eres tú! 😅")));
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'friends': FieldValue.arrayUnion([friendId])
      });

      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("¡${friendDoc['name']} agregado!")));
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Agregar Amigo", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Código de Amigo",
            hintText: "Ej: David#4521",
            labelStyle: TextStyle(color: Colors.grey),
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
          ElevatedButton(
              onPressed: _addFriend,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              child: const Text("Agregar", style: TextStyle(color: Colors.black))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505), // Fondo oscuro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
          builder: (context, snapshot) {
            String myCode = "...";
            bool amIDonor = false;

            if (snapshot.hasData && snapshot.data!.data() != null) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              myCode = data['friend_code'] ?? "Sin Código";
              amIDonor = data['is_donor'] ?? false; // <--- LEEMOS SI SOY DONADOR
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Comunidad", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 5),
                    if (amIDonor) const Icon(Icons.verified, color: Colors.amber, size: 16), // Corona para mí
                  ],
                ),
                Text(
                  "Tu ID: $myCode",
                  style: const TextStyle(fontSize: 14, color: Color(0xFF00E676)),
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
          _buildRankingTab(),
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

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];
        friendsIds.add(currentUser!.uid);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendsIds)
              .snapshots(),
          builder: (context, friendsSnapshot) {
            if (!friendsSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            final users = friendsSnapshot.data!.docs;

            users.sort((a, b) {
              int scoreA = (a.data() as Map)['social_score'] ?? 0;
              int scoreB = (b.data() as Map)['social_score'] ?? 0;
              return scoreB.compareTo(scoreA);
            });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userDoc = users[index].data() as Map<String, dynamic>;
                final name = userDoc['name'] ?? 'Sin Nombre';
                final score = userDoc['social_score'] ?? 0;
                final bool isMe = users[index].id == currentUser!.uid;

                // --- AQUÍ DETECTAMOS AL DONADOR ---
                final bool isDonor = userDoc['is_donor'] ?? false;

                // Definimos el icono de medalla
                Widget? trailingIcon;
                if (index == 0) trailingIcon = const Text("🥇", style: TextStyle(fontSize: 24));
                if (index == 1) trailingIcon = const Text("🥈", style: TextStyle(fontSize: 24));
                if (index == 2) trailingIcon = const Text("🥉", style: TextStyle(fontSize: 24));
                if (index > 2) trailingIcon = Text("#${index + 1}", style: const TextStyle(color: Colors.grey));

                return Card(
                  color: isMe ? const Color(0xFF2C3E50) : const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: isDonor
                        ? const BorderSide(color: Colors.amber, width: 1.5) // Borde dorado si es donador
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[800],
                          backgroundImage: (userDoc['photoUrl'] != null) ? NetworkImage(userDoc['photoUrl']) : null,
                          child: (userDoc['photoUrl'] == null) ? Text(name[0].toUpperCase()) : null,
                        ),
                        // Corona en la foto de perfil
                        if (isDonor)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(Icons.verified, color: Colors.amber, size: 16),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? const Color(0xFF00E676) : Colors.white)),
                        if (isDonor) ...[
                          const SizedBox(width: 5),
                          const Text("PRO", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]
                      ],
                    ),
                    subtitle: Text("$score pts", style: const TextStyle(color: Colors.grey)),
                    trailing: trailingIcon,
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];

        if (friendsIds.isEmpty) return const Center(child: Text("Sin amigos aún.", style: TextStyle(color: Colors.grey)));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: friendsIds).snapshots(),
          builder: (context, listSnap) {
            if (!listSnap.hasData) return const Center(child: CircularProgressIndicator());

            return ListView(
              children: listSnap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final bool isDonor = d['is_donor'] ?? false; // Leemos si es donador

                return ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF00E676)),
                  title: Row(
                    children: [
                      Text(d['name'] ?? "Usuario", style: const TextStyle(color: Colors.white)),
                      if (isDonor) const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Icon(Icons.star, color: Colors.amber, size: 16),
                      )
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {},
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