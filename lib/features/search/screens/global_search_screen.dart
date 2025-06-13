import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/communities/widgets/user_avatar_widget.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;
  
  String _searchQuery = '';
  bool _isSearching = false;
  
  // Results
  List<Map<String, dynamic>> _taskResults = [];
  List<Map<String, dynamic>> _communityResults = [];
  List<Map<String, dynamic>> _messageResults = [];
  List<Map<String, dynamic>> _memberResults = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _focusNode.requestFocus();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _taskResults.clear();
        _communityResults.clear();
        _messageResults.clear();
        _memberResults.clear();
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _searchQuery = query.toLowerCase();
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Search in parallel
      await Future.wait([
        _searchTasks(user.uid),
        _searchCommunities(user.uid),
        _searchMessages(user.uid),
        _searchMembers(user.uid),
      ]);
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  Future<void> _searchTasks(String userId) async {
    final results = <Map<String, dynamic>>[];
    
    final tasksSnapshot = await FirebaseFirestore.instance
        .collectionGroup('tasks')
        .where('assignedToId', isEqualTo: userId)
        .get();
    
    for (var doc in tasksSnapshot.docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      
      if (title.contains(_searchQuery) || description.contains(_searchQuery)) {
        results.add({
          'id': doc.id,
          'title': data['title'],
          'description': data['description'],
          'communityId': data['communityId'],
          'communityName': data['communityName'],
          'state': data['state'],
          'dueDate': data['dueDate'],
        });
      }
    }
    
    setState(() {
      _taskResults = results;
    });
  }
  
  Future<void> _searchCommunities(String userId) async {
    final results = <Map<String, dynamic>>[];
    
    final communitiesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .where('members', arrayContains: userId)
        .get();
    
    for (var doc in communitiesSnapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      
      if (name.contains(_searchQuery) || description.contains(_searchQuery)) {
        results.add({
          'id': doc.id,
          'name': data['name'],
          'description': data['description'],
          'imageUrl': data['imageUrl'],
          'memberCount': (data['members'] as List?)?.length ?? 0,
        });
      }
    }
    
    setState(() {
      _communityResults = results;
    });
  }
  
  Future<void> _searchMessages(String userId) async {
    // Limit message search to recent messages for performance
    final results = <Map<String, dynamic>>[];
    
    // Get user's communities first
    final communitiesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .where('members', arrayContains: userId)
        .get();
    
    for (var communityDoc in communitiesSnapshot.docs) {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityDoc.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      for (var messageDoc in messagesSnapshot.docs) {
        final data = messageDoc.data();
        final content = (data['content'] ?? '').toString().toLowerCase();
        
        if (content.contains(_searchQuery)) {
          results.add({
            'id': messageDoc.id,
            'content': data['content'],
            'senderName': data['senderName'],
            'senderId': data['senderId'],
            'communityId': communityDoc.id,
            'communityName': communityDoc.data()['name'],
            'timestamp': data['timestamp'],
          });
        }
      }
    }
    
    setState(() {
      _messageResults = results;
    });
  }
  
  Future<void> _searchMembers(String userId) async {
    final results = <Map<String, dynamic>>[];
    final processedUserIds = <String>{};
    
    // Get user's communities
    final communitiesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .where('members', arrayContains: userId)
        .get();
    
    for (var communityDoc in communitiesSnapshot.docs) {
      final memberIds = List<String>.from(communityDoc.data()['members'] ?? []);
      
      for (var memberId in memberIds) {
        if (processedUserIds.contains(memberId)) continue;
        processedUserIds.add(memberId);
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final name = (userData['displayName'] ?? userData['name'] ?? '').toString().toLowerCase();
          final email = (userData['email'] ?? '').toString().toLowerCase();
          
          if (name.contains(_searchQuery) || email.contains(_searchQuery)) {
            results.add({
              'id': memberId,
              'name': userData['displayName'] ?? userData['name'] ?? 'Usuario',
              'email': userData['email'],
              'photoURL': userData['photoURL'],
            });
          }
        }
      }
    }
    
    setState(() {
      _memberResults = results;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: (value) {
                            _performSearch(value);
                          },
                          style: TextStyle(
                            fontFamily: fontFamilyPrimary,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar tareas, comunidades, mensajes...',
                            hintStyle: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _performSearch('');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5),
                  indicatorColor: theme.colorScheme.primary,
                  labelStyle: const TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: 'Tareas (${_taskResults.length})'),
                    Tab(text: 'Comunidades (${_communityResults.length})'),
                    Tab(text: 'Mensajes (${_messageResults.length})'),
                    Tab(text: 'Miembros (${_memberResults.length})'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isSearching
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskResults(),
                _buildCommunityResults(),
                _buildMessageResults(),
                _buildMemberResults(),
              ],
            ),
    );
  }
  
  Widget _buildTaskResults() {
    if (_taskResults.isEmpty) {
      return _buildEmptyState('No se encontraron tareas');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _taskResults.length,
      itemBuilder: (context, index) {
        final task = _taskResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              task['title'] ?? 'Sin título',
              style: const TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task['description'] != null && task['description'].isNotEmpty)
                  Text(
                    task['description'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                Text(
                  task['communityName'] ?? 'Comunidad',
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            trailing: _buildTaskStateChip(task['state']),
            onTap: () {
              Navigator.of(context).pushNamed(
                '/task-detail',
                arguments: {
                  'communityId': task['communityId'],
                  'taskId': task['id'],
                },
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildCommunityResults() {
    if (_communityResults.isEmpty) {
      return _buildEmptyState('No se encontraron comunidades');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _communityResults.length,
      itemBuilder: (context, index) {
        final community = _communityResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: community['imageUrl'] != null
                  ? NetworkImage(community['imageUrl'])
                  : null,
              child: community['imageUrl'] == null
                  ? Icon(
                      Icons.group,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            title: Text(
              community['name'] ?? 'Sin nombre',
              style: const TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${community['memberCount']} miembros',
              style: const TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 12,
              ),
            ),
            onTap: () {
              Navigator.of(context).pushNamed(
                '/community-detail',
                arguments: community['id'],
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildMessageResults() {
    if (_messageResults.isEmpty) {
      return _buildEmptyState('No se encontraron mensajes');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messageResults.length,
      itemBuilder: (context, index) {
        final message = _messageResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.message,
                size: 20,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            title: Text(
              message['content'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: fontFamilyPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'De: ${message['senderName']}',
                  style: const TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'En: ${message['communityName']}',
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            onTap: () {
              // Navigate to community chat
              Navigator.of(context).pushNamed(
                '/community-detail',
                arguments: message['communityId'],
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildMemberResults() {
    if (_memberResults.isEmpty) {
      return _buildEmptyState('No se encontraron miembros');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _memberResults.length,
      itemBuilder: (context, index) {
        final member = _memberResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: UserAvatarWidget(
              imageUrl: member['photoURL'],
              radius: 20,
              userRole: 'member',
            ),
            title: Text(
              member['name'] ?? 'Usuario',
              style: const TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              member['email'] ?? '',
              style: const TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Intenta buscar algo',
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTaskStateChip(String? state) {
    String displayState = 'Por hacer';
    Color color = Colors.grey;
    
    switch (state?.toLowerCase()) {
      case 'done':
      case 'completed':
        displayState = 'Completado';
        color = Colors.green;
        break;
      case 'doing':
      case 'in_progress':
        displayState = 'En progreso';
        color = Colors.blue;
        break;
      case 'review':
      case 'under_review':
        displayState = 'En revisión';
        color = Colors.orange;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayState,
        style: TextStyle(
          fontFamily: fontFamilyPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}