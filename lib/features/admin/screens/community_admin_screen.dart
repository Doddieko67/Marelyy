import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:intl/intl.dart';

class CommunityAdminScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  
  const CommunityAdminScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunityAdminScreen> createState() => _CommunityAdminScreenState();
}

class _CommunityAdminScreenState extends State<CommunityAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Estadísticas de la comunidad
  int _totalMembers = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;
  int _activeTasks = 0;
  int _messagesCount = 0;
  
  // Listas de datos
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _recentTasks = [];
  List<Map<String, dynamic>> _tasksByStatus = [];
  
  bool _isLoading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
    _loadCommunityData();
  }

  Future<void> _checkOwnership() async {
    try {
      final communityDoc = await _firestore
          .collection('communities')
          .doc(widget.communityId)
          .get();
      
      if (communityDoc.exists) {
        final data = communityDoc.data()!;
        final ownerId = data['ownerId'] as String?;
        _isOwner = ownerId == _auth.currentUser?.uid;
      }
    } catch (e) {
      print('Error checking ownership: $e');
    }
  }

  Future<void> _loadCommunityData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadMemberStats(),
        _loadTaskStats(),
        _loadMembers(),
        _loadRecentTasks(),
        _loadMessagesCount(),
      ]);
    } catch (e) {
      print('Error loading community data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMemberStats() async {
    try {
      final communityDoc = await _firestore
          .collection('communities')
          .doc(widget.communityId)
          .get();
      
      if (communityDoc.exists) {
        final data = communityDoc.data()!;
        final members = data['members'] as List<dynamic>? ?? [];
        _totalMembers = members.length;
      }
    } catch (e) {
      print('Error loading member stats: $e');
    }
  }

  Future<void> _loadTaskStats() async {
    try {
      final tasksSnapshot = await _firestore
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .get();
      
      _totalTasks = tasksSnapshot.docs.length;
      _completedTasks = 0;
      _activeTasks = 0;
      
      Map<String, int> statusCount = {};
      
      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'toDo';
        
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        
        if (status == 'done' || status == 'completed') {
          _completedTasks++;
        } else {
          _activeTasks++;
        }
      }
      
      _tasksByStatus = statusCount.entries.map((entry) => {
        'status': entry.key,
        'count': entry.value,
        'percentage': (_totalTasks > 0 ? (entry.value / _totalTasks * 100) : 0.0),
      }).toList();
      
    } catch (e) {
      print('Error loading task stats: $e');
    }
  }

  Future<void> _loadMembers() async {
    try {
      final communityDoc = await _firestore
          .collection('communities')
          .doc(widget.communityId)
          .get();
      
      if (communityDoc.exists) {
        final data = communityDoc.data()!;
        final memberIds = data['members'] as List<dynamic>? ?? [];
        
        _members.clear();
        
        for (String memberId in memberIds.cast<String>()) {
          try {
            // Obtener datos del usuario
            final userDoc = await _firestore
                .collection('users')
                .doc(memberId)
                .get();
            
            // Obtener datos del miembro en la comunidad
            final memberDoc = await _firestore
                .collection('communities')
                .doc(widget.communityId)
                .collection('members')
                .doc(memberId)
                .get();
            
            String userName = 'Usuario desconocido';
            String userEmail = '';
            
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              userName = userData['displayName'] ?? userData['name'] ?? 'Usuario';
              userEmail = userData['email'] ?? '';
            }
            
            String role = 'member';
            DateTime? joinedAt;
            
            if (memberDoc.exists) {
              final memberData = memberDoc.data()!;
              role = memberData['role'] ?? 'member';
              joinedAt = (memberData['joinedAt'] as Timestamp?)?.toDate();
            }
            
            // Verificar si es el owner
            if (memberId == data['ownerId']) {
              role = 'owner';
            }
            
            _members.add({
              'id': memberId,
              'name': userName,
              'email': userEmail,
              'role': role,
              'joinedAt': joinedAt,
            });
          } catch (e) {
            print('Error loading member $memberId: $e');
          }
        }
        
        // Ordenar miembros por rol (owner > admin > member) y luego por fecha
        _members.sort((a, b) {
          const roleOrder = {'owner': 0, 'admin': 1, 'member': 2};
          final roleComparison = (roleOrder[a['role']] ?? 3) - (roleOrder[b['role']] ?? 3);
          if (roleComparison != 0) return roleComparison;
          
          final dateA = a['joinedAt'] as DateTime?;
          final dateB = b['joinedAt'] as DateTime?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
      }
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  Future<void> _loadRecentTasks() async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      _recentTasks = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Sin título',
          'description': data['description'] ?? '',
          'status': data['status'] ?? 'toDo',
          'createdAt': data['createdAt'] as Timestamp?,
          'assignedTo': data['assignedTo'] as String?,
          'createdBy': data['createdBy'] as String?,
        };
      }).toList();
    } catch (e) {
      print('Error loading recent tasks: $e');
    }
  }

  Future<void> _loadMessagesCount() async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(widget.communityId)
          .collection('messages')
          .get();
      
      _messagesCount = snapshot.docs.length;
    } catch (e) {
      print('Error loading messages count: $e');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha desconocida';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
      case 'to_do':
        return 'Por hacer';
      case 'doing':
      case 'inprogress':
      case 'in_progress':
        return 'En progreso';
      case 'underreview':
      case 'under_review':
      case 'review':
        return 'En revisión';
      case 'done':
      case 'completed':
        return 'Completado';
      default:
        return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
      case 'to_do':
        return Colors.grey;
      case 'doing':
      case 'inprogress':
      case 'in_progress':
        return Colors.blue;
      case 'underreview':
      case 'under_review':
      case 'review':
        return Colors.orange;
      case 'done':
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Propietario';
      case 'admin':
        return 'Administrador';
      case 'member':
        return 'Miembro';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'member':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    double? percentage,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (percentage != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 4),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: fontFamilyPrimary,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (subtitle != null && percentage == null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final theme = Theme.of(context);
    final role = member['role'] as String;
    final roleColor = _getRoleColor(role);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              role == 'owner' 
                  ? Icons.admin_panel_settings 
                  : role == 'admin' 
                      ? Icons.admin_panel_settings 
                      : Icons.person,
              color: roleColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'] ?? 'Usuario desconocido',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (member['email']?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    member['email'],
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getRoleDisplayName(role),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: roleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (member['joinedAt'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(member['joinedAt']),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final theme = Theme.of(context);
    final status = task['status'] as String;
    final statusColor = _getStatusColor(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title'] ?? 'Sin título',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusDisplayName(status),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (task['description']?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              task['description'],
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (task['createdAt'] != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDate((task['createdAt'] as Timestamp).toDate()),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Admin: ${widget.communityName}',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: theme.colorScheme.primary,
            ),
            onPressed: _loadCommunityData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando datos de la comunidad...',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estadísticas generales
                  Text(
                    'Estadísticas de la Comunidad',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Grid de estadísticas
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(
                        title: 'Total Miembros',
                        value: _totalMembers.toString(),
                        icon: Icons.people,
                        color: theme.colorScheme.primary,
                      ),
                      _buildStatCard(
                        title: 'Total Tareas',
                        value: _totalTasks.toString(),
                        icon: Icons.task,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: 'Tareas Completadas',
                        value: _completedTasks.toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                        percentage: _totalTasks > 0 ? (_completedTasks / _totalTasks * 100) : 0,
                      ),
                      _buildStatCard(
                        title: 'Mensajes',
                        value: _messagesCount.toString(),
                        icon: Icons.message,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  
                  // Distribución de tareas por estado
                  if (_tasksByStatus.isNotEmpty) ...[
                    _buildSectionHeader('Distribución de Tareas', Icons.pie_chart),
                    
                    ..._tasksByStatus.map((statusData) {
                      final status = statusData['status'] as String;
                      final count = statusData['count'] as int;
                      final percentage = statusData['percentage'] as double;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: _buildStatCard(
                          title: _getStatusDisplayName(status),
                          value: count.toString(),
                          icon: Icons.assignment,
                          color: _getStatusColor(status),
                          percentage: percentage,
                        ),
                      );
                    }).toList(),
                  ],
                  
                  // Miembros
                  _buildSectionHeader('Miembros ($_totalMembers)', Icons.group),
                  
                  if (_members.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se pudieron cargar los miembros',
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_members.take(10).map((member) => _buildMemberCard(member))),
                  
                  if (_members.length > 10)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Y ${_members.length - 10} miembros más...',
                        style: TextStyle(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Tareas recientes
                  _buildSectionHeader('Tareas Recientes', Icons.schedule),
                  
                  if (_recentTasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.task_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay tareas recientes',
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_recentTasks.map((task) => _buildTaskCard(task))),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}