import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // 🛡️ NUEVO: LISTA LOCAL DE BLOQUEADOS
  List<String> _blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    // 🛡️ CARGAR BLOQUEADOS AL INICIAR
    _loadBlockedUsers();
  }

  // 🛡️ 1. CARGAR USUARIOS BLOQUEADOS
  Future<void> _loadBlockedUsers() async {
    if (currentUser == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('blocked_users')
          .get();

      if (mounted) {
        setState(() {
          _blockedUserIds = snapshot.docs.map((doc) => doc.id).toList();
        });
      }
    } catch (e) {
      debugPrint("Error cargando bloqueados: $e");
    }
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
    final Color themeColor = Theme.of(context).primaryColor;

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
              style: ElevatedButton.styleFrom(backgroundColor: themeColor),
              child: const Text("Agregar", style: TextStyle(color: Colors.black))
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LÓGICA DEL MURO Y SEGURIDAD
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text("¡Comida copiada! 🍱"), backgroundColor: Theme.of(context).primaryColor)
        );
      }
    } catch (e) {
      debugPrint("Error copiando: $e");
    }
  }

  // 🛡️ 2. MENÚ DE OPCIONES (REPORTAR / BLOQUEAR / COPIAR)
  void _showPostOptions(String docId, String postUserId, String postUserName, Map<String, dynamic> mealData) {
    // Si es mi propio post, solo mostrar opción de borrar (opcional) o nada
    final bool isMe = currentUser!.uid == postUserId;
    final Color themeColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, width: 40, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),

          // OPCIÓN 1: COPIAR (Tu función original)
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: themeColor),
            title: const Text("Copiar a mi dieta", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _copyMealToMyDiet(mealData);
            },
          ),
          const Divider(color: Colors.grey, height: 1),

          if (!isMe) ...[
            // OPCIÓN 2: REPORTAR
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.redAccent),
              title: const Text("Reportar contenido", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _reportPost(docId, postUserId);
              },
            ),
            // OPCIÓN 3: BLOQUEAR
            ListTile(
              leading: const Icon(Icons.block, color: Colors.grey),
              title: Text("Bloquear a $postUserName", style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _blockUser(postUserId);
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 🛡️ Lógica de Reporte
  Future<void> _reportPost(String docId, String postUserId) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'post_id': docId,
      'reported_user': postUserId,
      'reported_by': currentUser!.uid,
      'reason': 'Contenido inapropiado',
      'timestamp': FieldValue.serverTimestamp(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reporte enviado."), backgroundColor: Colors.green));
  }

  // 🛡️ Lógica de Bloqueo
  Future<void> _blockUser(String blockedUserId) async {
    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('blocked_users').doc(blockedUserId).set({
      'blocked_at': FieldValue.serverTimestamp(),
    });
    setState(() {
      _blockedUserIds.add(blockedUserId);
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario bloqueado.")));
  }

  // ==========================================
  // UI PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final Color themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
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
                Text("Tu ID: $myCode", style: TextStyle(fontSize: 12, color: themeColor)),
              ],
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: themeColor,
          labelColor: themeColor,
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
          _buildFeedTab(),
          _buildRankingTab(),
          _buildFriendsList(),
        ],
      ),
      floatingActionButton: _tabController.index > 0
          ? FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: themeColor,
        child: const Icon(Icons.person_add, color: Colors.black),
      )
          : null,
    );
  }

  // ------------------------------------------
  // PESTAÑA 1: MURO GLOBAL (MODIFICADA CON SEGURIDAD)
  // ------------------------------------------
  Widget _buildFeedTab() {
    final Color themeColor = Theme.of(context).primaryColor;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return Center(child: CircularProgressIndicator(color: themeColor));

        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        final List<dynamic> myFriends = userData?['friends'] ?? [];
        final String myUid = currentUser!.uid;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('community_feed').orderBy('timestamp', descending: true).limit(50).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: themeColor));
            final posts = snapshot.data!.docs;

            // 🛡️ FILTRO: Eliminamos posts de gente bloqueada
            final filteredPosts = posts.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return !_blockedUserIds.contains(d['user_id']);
            }).toList();

            if (filteredPosts.isEmpty) {
              return const Center(child: Text("El muro está vacío.", style: TextStyle(color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final doc = filteredPosts[index];
                final data = doc.data() as Map<String, dynamic>;

                final bool isPrivate = data['is_private'] ?? false;
                final String authorId = data['user_id'];

                if (isPrivate && authorId != myUid && !myFriends.contains(authorId)) {
                  return const SizedBox.shrink();
                }

                final List likes = data['likes'] ?? [];
                final bool isLiked = likes.contains(currentUser?.uid);
                final bool isVip = data['is_vip'] ?? false;
                final Timestamp? ts = data['timestamp'];
                final String timeAgo = ts != null ? DateFormat('dd MMM, HH:mm').format(ts.toDate()) : "Reciente";

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(20),
                    border: isPrivate
                        ? Border.all(color: Colors.grey.withOpacity(0.5), width: 1)
                        : (isVip ? Border.all(color: Colors.amber.withOpacity(0.6), width: 1.5) : Border.all(color: Colors.white10)),
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
                            if (isVip)
                              const Positioned(
                                right: 0, bottom: 0,
                                child: Icon(Icons.verified, color: Colors.amber, size: 16),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(
                                data['user_name'] ?? "Usuario",
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
                              ),
                            if (isPrivate)
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.lock, size: 14, color: Colors.grey),
                              )
                          ],
                        ),
                        subtitle: Text(isPrivate ? "Solo para amigos • $timeAgo" : timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        // 🛡️ CAMBIO AQUÍ: Menú de 3 puntos en lugar del botón directo de copiar
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onPressed: () => _showPostOptions(doc.id, authorId, data['user_name'], data),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        child: Row(
                          children: [
                            Expanded(child: Text(data['name'] ?? "Comida", style: const TextStyle(color: Colors.white, fontSize: 16))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(8)),
                              child: Text("${data['calories']} kcal", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),

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
      },
    );
  }

  // ------------------------------------------
  // PESTAÑA 2: RANKING (SIN CAMBIOS)
  // ------------------------------------------
  Widget _buildRankingTab() {
    final Color themeColor = Theme.of(context).primaryColor;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: themeColor));

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];
        friendsIds.add(currentUser!.uid);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: friendsIds).snapshots(),
          builder: (context, friendsSnapshot) {
            if (!friendsSnapshot.hasData) return Center(child: CircularProgressIndicator(color: themeColor));

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
                final name = userDoc['name'] ?? 'Usuario';
                final score = userDoc['social_score'] ?? 0;
                final bool isMe = users[index].id == currentUser!.uid;
                final bool isDonor = userDoc['is_donor'] ?? false;

                Widget? trailingIcon;
                if (index == 0) {
                  trailingIcon = const Text("🥇", style: TextStyle(fontSize: 24));
                } else if (index == 1) trailingIcon = const Text("🥈", style: TextStyle(fontSize: 24));
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
                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? themeColor : Colors.white)),
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
  // PESTAÑA 3: MIS AMIGOS (SIN CAMBIOS)
  // ------------------------------------------
  Widget _buildFriendsList() {
    final Color themeColor = Theme.of(context).primaryColor;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: themeColor));
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        List<dynamic> friendsIds = userData?['friends'] ?? [];

        if (friendsIds.isEmpty) return const Center(child: Text("Aún no tienes amigos.", style: TextStyle(color: Colors.grey)));

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: friendsIds).snapshots(),
          builder: (context, listSnap) {
            if (!listSnap.hasData) return Center(child: CircularProgressIndicator(color: themeColor));

            return ListView(
              children: listSnap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final bool isDonor = d['is_donor'] ?? false;

                return ListTile(
                  leading: Icon(Icons.person, color: themeColor),
                  title: Row(
                    children: [
                      Text(d['name'] ?? "Usuario", style: const TextStyle(color: Colors.white)),
                      if (isDonor) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.star, color: Colors.amber, size: 16)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      // Lógica de borrar pendiente
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