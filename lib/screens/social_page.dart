import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl en pubspec.yaml

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
    // AHORA SON 3 PESTAÑAS: MURO, RANKING, AMIGOS
    _tabController = TabController(length: 3, vsync: this);

    // Escuchar cambios para actualizar el botón flotante
    _tabController.addListener(() {
      setState(() {});
    });
  }

  // ==========================================
  // LÓGICA DE AMIGOS (TU CÓDIGO ORIGINAL)
  // ==========================================

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

  // ==========================================
  // LÓGICA DEL MURO (CÓDIGO NUEVO)
  // ==========================================

  Future<void> _toggleLike(String docId, List likes) async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    DocumentReference docRef = FirebaseFirestore.instance.collection('community_feed').doc(docId);

    if (likes.contains(uid)) {
      await docRef.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await docRef.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  Future<void> _copyMealToMyDiet(Map<String, dynamic> data) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('meals').add({
        'name': data['name'],
        'calories': data['calories'],
        'protein': data['protein'],
        'carbs': data['carbs'],
        'fat': data['fat'],
        'timestamp': FieldValue.serverTimestamp(),
        'date_str': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Comida copiada! 🍱"), backgroundColor: Color(0xFF00E676)));
      }
    } catch (e) {
      debugPrint("Error copiando: $e");
    }
  }

  // ==========================================
  // UI PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        // USAMOS TU HEADER ORIGINAL PORQUE MUESTRA TU CÓDIGO Y SI ERES VIP
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
          builder: (context, snapshot) {
            String myCode = "...";
            bool amIDonor = false;

            if (snapshot.hasData && snapshot.data!.data() != null) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              myCode = data['friend_code'] ?? "Sin Código";
              amIDonor = data['is_donor'] ?? false;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Social Hub", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    if (amIDonor) const Icon(Icons.verified, color: Colors.amber, size: 16),
                  ],
                ),
                Text("Tu ID: $myCode", style: const TextStyle(fontSize: 12, color: Color(0xFF00E676))),
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
            Tab(text: "MURO 🌍", icon: Icon(Icons.public)),
            Tab(text: "RANKING 🏆", icon: Icon(Icons.leaderboard)),
            Tab(text: "AMIGOS 👥", icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedTab(),      // Pestaña 1: Muro (Nuevo)
          _buildRankingTab(),   // Pestaña 2: Ranking (Tuyo)
          _buildFriendsList(),  // Pestaña 3: Amigos (Tuyo)
        ],
      ),
      // BOTÓN FLOTANTE CAMBIA SEGÚN LA PESTAÑA
      floatingActionButton: _tabController.index > 0
          ? FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: const Color(0xFF00E676),
        child: const Icon(Icons.person_add, color: Colors.black),
      )
          : null, // En el muro no mostramos botón flotante (se comparte desde el dashboard)
    );
  }

  // ------------------------------------------
  // PESTAÑA 1: MURO GLOBAL (CON DISEÑO VIP)
  // ------------------------------------------
  Widget _buildFeedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('community_feed').orderBy('timestamp', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(child: Text("Sé el primero en compartir desde Inicio!", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final doc = posts[index];
            final data = doc.data() as Map<String, dynamic>;

            final List likes = data['likes'] ?? [];
            final bool isLiked = likes.contains(currentUser?.uid);
            final bool isVip = data['is_vip'] ?? false; // <--- LEEMOS SI ES VIP

            final Timestamp? ts = data['timestamp'];
            final String timeAgo = ts != null ? DateFormat('dd MMM, HH:mm').format(ts.toDate()) : "Reciente";

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(20),
                // ✨ BORDE DORADO SI ES VIP
                border: isVip
                    ? Border.all(color: Colors.amber.withOpacity(0.6), width: 1.5)
                    : Border.all(color: Colors.white10),
                // ✨ RESPLANDOR DORADO SI ES VIP
                boxShadow: isVip
                    ? [BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 15, spreadRadius: 1)]
                    : [],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF333333),
                          child: Text((data['user_name'] ?? "U")[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        // ✨ ESTRELLA EN EL AVATAR
                        if (isVip)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(Icons.verified, color: Colors.amber, size: 16),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Text(
                            data['user_name'] ?? "Usuario",
                            // ✨ NOMBRE DORADO
                            style: TextStyle(
                                color: isVip ? Colors.amber : Colors.white,
                                fontWeight: FontWeight.bold
                            )
                        ),
                        if (isVip)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                            child: const Text("PRO", style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    subtitle: Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E676)),
                      onPressed: () => _copyMealToMyDiet(data),
                      tooltip: "Copiar a mi dieta",
                    ),
                  ),

                  // CONTENIDO DE LA COMIDA
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text(data['name'] ?? "Comida", style: const TextStyle(color: Colors.white, fontSize: 16))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(8)),
                          child: Text("${data['calories']} kcal", style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // BOTÓN DE LIKE
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey),
                          onPressed: () => _toggleLike(doc.id, likes),
                        ),
                        Text("${likes.length}", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------
  // PESTAÑA 2: RANKING (TU CÓDIGO)
  // ------------------------------------------
  Widget _buildRankingTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];
        friendsIds.add(currentUser!.uid); // Inclúyete a ti mismo

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: friendsIds).snapshots(),
          builder: (context, friendsSnapshot) {
            if (!friendsSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            final users = friendsSnapshot.data!.docs;
            // Ordenar por puntaje (social_score)
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
                final name = userDoc['name'] ?? 'Usuario';
                final score = userDoc['social_score'] ?? 0;
                final bool isMe = users[index].id == currentUser!.uid;
                final bool isDonor = userDoc['is_donor'] ?? false;

                Widget? trailingIcon;
                if (index == 0) trailingIcon = const Text("🥇", style: TextStyle(fontSize: 24));
                else if (index == 1) trailingIcon = const Text("🥈", style: TextStyle(fontSize: 24));
                else if (index == 2) trailingIcon = const Text("🥉", style: TextStyle(fontSize: 24));
                else trailingIcon = Text("#${index + 1}", style: const TextStyle(color: Colors.grey));

                return Card(
                  color: isMe ? const Color(0xFF2C3E50) : const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: isDonor ? const BorderSide(color: Colors.amber, width: 1.5) : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Row(
                      children: [
                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? const Color(0xFF00E676) : Colors.white)),
                        if (isDonor) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.star, color: Colors.amber, size: 14)),
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

  // ------------------------------------------
  // PESTAÑA 3: MIS AMIGOS (TU CÓDIGO)
  // ------------------------------------------
  Widget _buildFriendsList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];

        if (friendsIds.isEmpty) return const Center(child: Text("Aún no tienes amigos.", style: TextStyle(color: Colors.grey)));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: friendsIds).snapshots(),
          builder: (context, listSnap) {
            if (!listSnap.hasData) return const Center(child: CircularProgressIndicator());

            return ListView(
              children: listSnap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final bool isDonor = d['is_donor'] ?? false;

                return ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF00E676)),
                  title: Row(
                    children: [
                      Text(d['name'] ?? "Usuario", style: const TextStyle(color: Colors.white)),
                      if (isDonor) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.star, color: Colors.amber, size: 16)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      // Aquí podrías agregar lógica para borrar amigos si quieres
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