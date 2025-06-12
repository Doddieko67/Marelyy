import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/admin/screens/member_detail_screen.dart';
import 'package:classroom_mejorado/features/communities/widgets/user_avatar_widget.dart';
import 'package:classroom_mejorado/features/communities/widgets/role_badge_widget.dart';
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
  
  // Estadísticas de la comunidad
  int _totalMembers = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;
  int _messagesCount = 0;
  
  // Listas de datos
  final List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _recentTasks = [];
  List<Map<String, dynamic>> _tasksByStatus = [];
  final List<Map<String, dynamic>> _memberStats = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunityData();
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
      
      // Load member productivity stats after members are loaded
      await _loadMemberProductivityStats();
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
      
      Map<String, int> statusCount = {};
      
      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        final status = data['state'] as String? ?? 'toDo';
        
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        
        if (status == 'done' || status == 'completed') {
          _completedTasks++;
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
            
            // Get user photo URL
            String? photoURL;
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              photoURL = userData['photoURL'];
            }
            
            _members.add({
              'id': memberId,
              'name': userName,
              'email': userEmail,
              'role': role,
              'joinedAt': joinedAt,
              'photoURL': photoURL,
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
          'status': data['state'] ?? 'toDo',
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

  Future<void> _loadMemberProductivityStats() async {
    try {
      _memberStats.clear();
      
      for (var member in _members) {
        final memberId = member['id'] as String;
        
        // Get all tasks assigned to this member
        final tasksSnapshot = await _firestore
            .collection('communities')
            .doc(widget.communityId)
            .collection('tasks')
            .where('assignedTo', arrayContains: memberId)
            .get();
        
        int totalTasks = tasksSnapshot.docs.length;
        int completedTasks = 0;
        int inProgressTasks = 0;
        int overdueTasks = 0;
        DateTime now = DateTime.now();
        
        for (var taskDoc in tasksSnapshot.docs) {
          final taskData = taskDoc.data();
          final status = taskData['state'] ?? 'toDo';
          final dueDate = (taskData['dueDate'] as Timestamp?)?.toDate();
          
          switch (status) {
            case 'done':
              completedTasks++;
              break;
            case 'doing':
              inProgressTasks++;
              break;
          }
          
          // Check if overdue
          if (dueDate != null && dueDate.isBefore(now) && status != 'done') {
            overdueTasks++;
          }
        }
        
        double completionRate = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;
        
        _memberStats.add({
          'memberId': memberId,
          'name': member['name'],
          'email': member['email'],
          'role': member['role'],
          'photoURL': member['photoURL'],
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'inProgressTasks': inProgressTasks,
          'overdueTasks': overdueTasks,
          'completionRate': completionRate,
        });
      }
      
      // Sort by completion rate and total tasks
      _memberStats.sort((a, b) {
        // First by completion rate (descending)
        final rateComparison = (b['completionRate'] as double).compareTo(a['completionRate'] as double);
        if (rateComparison != 0) return rateComparison;
        
        // Then by total tasks (descending)
        return (b['totalTasks'] as int).compareTo(a['totalTasks'] as int);
      });
      
    } catch (e) {
      print('Error loading member productivity stats: $e');
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


  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double? percentage,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      width: 150,
      height: 230,
      margin: const EdgeInsets.all(8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon con fondo circular
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 52,
                ),
              ),
              
              // Value - siempre en el mismo lugar
              Text(
                value,
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Title - siempre 2 líneas reservadas
              SizedBox(
                height: 32,
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Progress area - siempre reservado (transparente si no hay progreso)
              SizedBox(
                height: 8,
                child: percentage != null
                    ? LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      )
                    : Container(), // Espacio transparente reservado
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final theme = Theme.of(context);
    final role = member['role'] as String;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberDetailScreen(
              communityId: widget.communityId,
              memberId: member['id'],
              memberName: member['name'] ?? 'Usuario',
              memberEmail: member['email'],
              memberImageUrl: member['photoURL'],
              memberRole: role,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatarWidget(
                imageUrl: member['photoURL'],
                radius: 24,
                userRole: role,
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
                    RoleBadgeWidget(role: role),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberStatsCard(Map<String, dynamic> memberStats, int rank) {
    final theme = Theme.of(context);
    final completionRate = memberStats['completionRate'] as double;
    final totalTasks = memberStats['totalTasks'] as int;
    final completedTasks = memberStats['completedTasks'] as int;
    final role = memberStats['role'] as String;
    
    Color rankColor = Colors.grey;
    IconData? rankIcon;
    
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        rankIcon = Icons.workspace_premium;
        break;
      case 3:
        rankColor = Colors.orange.shade700;
        rankIcon = Icons.military_tech;
        break;
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberDetailScreen(
              communityId: widget.communityId,
              memberId: memberStats['memberId'],
              memberName: memberStats['name'] ?? 'Usuario',
              memberEmail: memberStats['email'],
              memberImageUrl: memberStats['photoURL'],
              memberRole: role,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: rank <= 3 ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: rank <= 3 
              ? BorderSide(color: rankColor.withOpacity(0.3), width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3 ? rankColor.withOpacity(0.2) : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: rank <= 3 && rankIcon != null
                      ? Icon(rankIcon, color: rankColor, size: 16)
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            fontFamily: fontFamilyPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              UserAvatarWidget(
                imageUrl: memberStats['photoURL'],
                radius: 20,
                userRole: role,
              ),
              const SizedBox(width: 12),
              // Member info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            memberStats['name'] ?? 'Usuario',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        RoleBadgeWidget(role: role),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$completedTasks/$totalTasks tareas',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          '${completionRate.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            fontWeight: FontWeight.bold,
                            color: completionRate >= 80 
                                ? Colors.green 
                                : completionRate >= 60 
                                    ? Colors.orange 
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: totalTasks > 0 ? completedTasks / totalTasks : 0,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completionRate >= 80 
                            ? Colors.green 
                            : completionRate >= 60 
                                ? Colors.orange 
                                : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
                  
                  // Cards de estadísticas principales
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatCard(
                        title: 'Miembros',
                        value: _totalMembers.toString(),
                        icon: Icons.people,
                        color: theme.colorScheme.primary,
                      ),
                      _buildStatCard(
                        title: 'Tareas',
                        value: _totalTasks.toString(),
                        icon: Icons.task,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: 'Completadas',
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
                    const SizedBox(height: 32),
                    _buildSectionHeader('Distribución de Tareas', Icons.pie_chart),
                    const SizedBox(height: 16),
                    
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: _tasksByStatus.map((statusData) {
                        final status = statusData['status'] as String;
                        final count = statusData['count'] as int;
                        final percentage = statusData['percentage'] as double;
                        
                        return _buildStatCard(
                          title: _getStatusDisplayName(status),
                          value: count.toString(),
                          icon: Icons.assignment,
                          color: _getStatusColor(status),
                          percentage: percentage,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                  
                  // Ranking de Productividad
                  const SizedBox(height: 16),
                  _buildSectionHeader('Ranking de Productividad', Icons.leaderboard),
                  
                  if (_memberStats.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay datos de productividad disponibles',
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_memberStats.asMap().entries.map((entry) {
                      final index = entry.key;
                      final memberStats = entry.value;
                      return _buildMemberStatsCard(memberStats, index + 1);
                    })),
                  
                  // Miembros
                  const SizedBox(height: 32),
                  _buildSectionHeader('Todos los Miembros ($_totalMembers)', Icons.group),
                  
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
                    ...(_members.map((member) => _buildMemberCard(member))),
                  
                  // Tareas recientes
                  const SizedBox(height: 32),
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