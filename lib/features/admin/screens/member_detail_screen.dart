import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart';
import 'package:classroom_mejorado/features/communities/widgets/user_avatar_widget.dart';
import 'package:classroom_mejorado/features/communities/widgets/role_badge_widget.dart';
import 'package:classroom_mejorado/core/utils/permission_checker.dart';

class MemberDetailScreen extends StatefulWidget {
  final String communityId;
  final String memberId;
  final String memberName;
  final String? memberEmail;
  final String? memberImageUrl;
  final String memberRole;

  const MemberDetailScreen({
    super.key,
    required this.communityId,
    required this.memberId,
    required this.memberName,
    this.memberEmail,
    this.memberImageUrl,
    required this.memberRole,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  Map<String, dynamic>? memberStats;
  List<Map<String, dynamic>> memberTasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    try {
      // Cargar todas las tareas del miembro
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .where('assignedTo', arrayContains: widget.memberId)
          .orderBy('createdAt', descending: true)
          .get();

      final tasks = tasksSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Calcular estadísticas
      final stats = _calculateStats(tasks);

      setState(() {
        memberTasks = tasks;
        memberStats = stats;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> tasks) {
    int totalTasks = tasks.length;
    int completedTasks = 0;
    int pendingTasks = 0;
    int inProgressTasks = 0;
    int overdueTasks = 0;
    
    DateTime now = DateTime.now();
    
    for (var task in tasks) {
      final status = task['status'] ?? 'toDo';
      final dueDate = (task['dueDate'] as Timestamp?)?.toDate();
      
      switch (status) {
        case 'done':
          completedTasks++;
          break;
        case 'doing':
          inProgressTasks++;
          break;
        default:
          pendingTasks++;
      }
      
      // Verificar si está atrasada
      if (dueDate != null && dueDate.isBefore(now) && status != 'done') {
        overdueTasks++;
      }
    }

    double completionRate = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'pendingTasks': pendingTasks,
      'inProgressTasks': inProgressTasks,
      'overdueTasks': overdueTasks,
      'completionRate': completionRate,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSelf = widget.memberId == currentUser?.uid;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          '${widget.memberName}${isSelf ? " (Tú)" : ""}',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMemberHeader(theme),
                  const SizedBox(height: 24),
                  _buildStatsSection(theme),
                  const SizedBox(height: 24),
                  _buildTasksSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildMemberHeader(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            UserAvatarWidget(
              imageUrl: widget.memberImageUrl,
              radius: 32,
              userRole: widget.memberRole,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.memberName,
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (widget.memberEmail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.memberEmail!,
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  RoleBadgeWidget(role: widget.memberRole),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    if (memberStats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas de Rendimiento',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(
              theme,
              'Tareas Totales',
              '${memberStats!['totalTasks']}',
              Icons.assignment,
              theme.colorScheme.primary,
            ),
            _buildStatCard(
              theme,
              'Completadas',
              '${memberStats!['completedTasks']}',
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatCard(
              theme,
              'En Progreso',
              '${memberStats!['inProgressTasks']}',
              Icons.hourglass_empty,
              Colors.orange,
            ),
            _buildStatCard(
              theme,
              'Atrasadas',
              '${memberStats!['overdueTasks']}',
              Icons.warning,
              Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCompletionRateCard(theme),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRateCard(ThemeData theme) {
    final rate = memberStats!['completionRate'] as double;
    final color = rate >= 80 ? Colors.green : rate >= 60 ? Colors.orange : Colors.red;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.trending_up,
                size: 30,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasa de Finalización',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historial de Tareas (${memberTasks.length})',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 16),
        if (memberTasks.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay tareas asignadas',
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: memberTasks.length,
            itemBuilder: (context, index) {
              final task = memberTasks[index];
              return _buildTaskCard(theme, task);
            },
          ),
      ],
    );
  }

  Widget _buildTaskCard(ThemeData theme, Map<String, dynamic> task) {
    final status = task['status'] ?? 'toDo';
    final title = task['title'] ?? 'Sin título';
    final dueDate = (task['dueDate'] as Timestamp?)?.toDate();
    final createdAt = (task['createdAt'] as Timestamp?)?.toDate();
    
    final (statusColor, statusIcon, statusText) = _getTaskStatusInfo(status);
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && status != 'done';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (isOverdue) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ATRASADA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Vence: ${_formatDate(dueDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue ? Colors.red : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Creada: ${_formatDate(createdAt)}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, IconData, String) _getTaskStatusInfo(String status) {
    switch (status) {
      case 'done':
        return (Colors.green, Icons.check_circle, 'Completada');
      case 'doing':
        return (Colors.orange, Icons.hourglass_empty, 'En Progreso');
      case 'underReview':
        return (Colors.blue, Icons.rate_review, 'Por Revisar');
      default:
        return (Colors.grey, Icons.radio_button_unchecked, 'Pendiente');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'Hoy';
    if (difference == 1) return 'Ayer';
    if (difference == -1) return 'Mañana';
    if (difference < 7 && difference > 0) return 'Hace $difference días';
    if (difference > -7 && difference < 0) return 'En ${-difference} días';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}