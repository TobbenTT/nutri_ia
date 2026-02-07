import 'dart:math'; // Para la autoreparación de IDs
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// IMPORTAR PARA ACCEDER A LA LISTA DE GORRITOS (allHats)
import 'profile_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // 🛡️ LISTA LOCAL DE BLOQUEADOS
  List<String> _blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    _loadBlockedUsers();
    _fixMissingFriendCode(); // Autoreparación de ID
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

  // 🛡️ 2. AUTOREPARACIÓN DE ID (Si tu cuenta vieja no tiene ID)
  Future<void> _fixMissingFriendCode() async {
    if (currentUser == null) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      final data = docSnap.data() as Map<String, dynamic>;
      if (data['friend_code'] == null || data['friend_code'] == "") {
        final String name = data['name'] ?? "Usuario";
        final random = Random();
        final number = 1000 + random.nextInt(9000);
        final cleanName = name.split(' ')[0].replaceAll(RegExp(r'[^\w\s]+'), '');
        final newCode = "$cleanName#$number";
        await docRef.update({'friend_code': newCode});
        if(mounted) setState(() {});
      }
    }
  }

  // ==========================================
  // LÓGICA DE AMIGOS
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
  // LÓGICA DEL MURO
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

  void _showPostOptions(String docId, String postUserId, String postUserName, Map<String, dynamic> mealData) {
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
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.redAccent),
              title: const Text("Reportar contenido", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _reportPost(docId, postUserId);
              },
            ),
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
  // 🔥 NUEVO WIDGET: AVATAR CON GORRITO 🔥
  // ==========================================
  Widget _buildAvatarWithHat(String? photoUrl, String name, String? activeHatId, {double radius = 20, double iconSize = 24}) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // 1. El Avatar Base
        Padding(
          padding: const EdgeInsets.only(top: 4), // Espacio para el gorro
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[800],
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                : null,
          ),
        ),

        // 2. El Gorrito (Si existe)
        if (activeHatId != null && activeHatId.isNotEmpty)
          Builder(builder: (context) {
            final hat = allHats.firstWhere((h) => h.id == activeHatId, orElse: () => allHats[0]);
            return Positioned(
              top: -5, // Ajuste vertical
              child: Icon(hat.icon, color: hat.color, size: iconSize),
            );
          }),
      ],
    );
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
  // PESTAÑA 1: MURO GLOBAL
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

                // NOTA: Para que aparezcan el gorro y foto en el muro,
                // debes asegurarte que al guardar el post (Dashboard) también guardes estos campos.
                // Si son posts antiguos, saldrán sin gorro.
                final String? postHat = data['active_hat'];
                final String? postPhoto = data['user_photo'] ?? data['photo_url'];

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
                        // 🔥 USAMOS EL NUEVO WIDGET DE AVATAR AQUÍ
                        leading: _buildAvatarWithHat(
                            postPhoto,
                            data['user_name'] ?? "U",
                            postHat,
                            radius: 20,
                            iconSize: 22
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
  // PESTAÑA 2: RANKING (ACTUALIZADO CON FOTO Y GORRO)
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

                // DATOS VISUALES REALES
                final String? photo = userDoc['photoUrl'] ?? userDoc['photo_url'];
                final String? hat = userDoc['active_hat'];

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
                    // 🔥 USAMOS EL NUEVO WIDGET DE AVATAR AQUÍ
                    leading: _buildAvatarWithHat(
                        photo,
                        name,
                        hat,
                        radius: 20,
                        iconSize: 22
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
  // PESTAÑA 3: MIS AMIGOS (ACTUALIZADO CON FOTO Y GORRO)
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

                // DATOS VISUALES REALES
                final String? photo = d['photoUrl'] ?? d['photo_url'];
                final String? hat = d['active_hat'];

                return ListTile(
                  // 🔥 USAMOS EL NUEVO WIDGET DE AVATAR AQUÍ
                  leading: _buildAvatarWithHat(
                      photo,
                      d['name'] ?? "U",
                      hat,
                      radius: 22,
                      iconSize: 24
                  ),
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