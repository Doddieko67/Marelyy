import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/communities/providers/community_provider.dart';
import 'package:classroom_mejorado/features/tasks/providers/task_provider.dart';
import 'package:classroom_mejorado/shared/widgets/common/stat_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/member_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/task_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/section_header.dart';
import 'package:classroom_mejorado/shared/widgets/common/loading_widget.dart';

class RefactoredCommunityAdminScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  
  const RefactoredCommunityAdminScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<RefactoredCommunityAdminScreen> createState() => _RefactoredCommunityAdminScreenState();
}

class _RefactoredCommunityAdminScreenState extends State<RefactoredCommunityAdminScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final communityProvider = context.read<CommunityProvider>();
      final taskProvider = context.read<TaskProvider>();
      
      // Cargar datos de la comunidad
      communityProvider.loadCommunityMembers(widget.communityId);
      communityProvider.loadCommunityStats(widget.communityId);
      
      // Cargar tareas recientes
      taskProvider.loadCommunityTasks(widget.communityId);
    });
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
          Consumer2<CommunityProvider, TaskProvider>(
            builder: (context, communityProvider, taskProvider, child) {
              return IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () {
                  communityProvider.loadCommunityStats(widget.communityId);
                  taskProvider.refresh(widget.communityId);
                },
              );
            },
          ),
        ],
      ),
      body: Consumer2<CommunityProvider, TaskProvider>(
        builder: (context, communityProvider, taskProvider, child) {
          if (communityProvider.isLoadingStats && taskProvider.isLoading) {
            return const LoadingWidget(message: 'Cargando datos de la comunidad...');
          }

          if (communityProvider.error != null) {
            return ErrorWidget(
              message: communityProvider.error!,
              onRetry: () => communityProvider.refresh(),
            );
          }

          final stats = communityProvider.stats;
          final members = communityProvider.members;
          final recentTasks = taskProvider.communityTasks.take(5).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estadísticas de la comunidad
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
                    StatCard(
                      title: 'Total Miembros',
                      value: stats.totalMembers.toString(),
                      icon: Icons.people,
                      color: theme.colorScheme.primary,
                    ),
                    StatCard(
                      title: 'Total Tareas',
                      value: stats.totalTasks.toString(),
                      icon: Icons.task,
                      color: Colors.blue,
                    ),
                    StatCard(
                      title: 'Tareas Completadas',
                      value: stats.completedTasks.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                      percentage: stats.completionPercentage,
                    ),
                    StatCard(
                      title: 'Mensajes',
                      value: stats.messagesCount.toString(),
                      icon: Icons.message,
                      color: Colors.orange,
                    ),
                  ],
                ),
                
                // Distribución de tareas por estado
                if (stats.tasksByStatus.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Distribución de Tareas',
                    icon: Icons.pie_chart,
                  ),
                  
                  ...stats.tasksByStatus.entries.map((entry) {
                    final status = entry.key;
                    final count = entry.value;
                    final percentage = stats.totalTasks > 0 ? (count / stats.totalTasks * 100) : 0.0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: StatCard(
                        title: _getStatusDisplayName(status),
                        value: count.toString(),
                        icon: Icons.assignment,
                        color: _getStatusColor(status),
                        percentage: percentage,
                      ),
                    );
                  }),
                ],
                
                // Miembros
                SectionHeader(
                  title: 'Miembros (${members.length})',
                  icon: Icons.group,
                  actionText: members.length > 5 ? 'Ver todos' : null,
                  onActionPressed: members.length > 5 ? () {
                    // Navegar a vista completa de miembros
                  } : null,
                ),
                
                if (members.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.people_outline,
                    title: 'No se pudieron cargar los miembros',
                    subtitle: 'Intenta refrescar los datos',
                  )
                else
                  ...members.take(10).map((member) {
                    return MemberCard(
                      member: member,
                      showActions: true,
                      onPromote: () => _promoteMember(context, member),
                      onRemove: () => _removeMember(context, member),
                    );
                  }),
                
                if (members.length > 10)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Y ${members.length - 10} miembros más...',
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Tareas recientes
                SectionHeader(
                  title: 'Tareas Recientes',
                  icon: Icons.schedule,
                  actionText: recentTasks.length > 5 ? 'Ver todas' : null,
                  onActionPressed: recentTasks.length > 5 ? () {
                    // Navegar a vista completa de tareas
                  } : null,
                ),
                
                if (recentTasks.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.task_outlined,
                    title: 'No hay tareas recientes',
                    subtitle: 'Las tareas creadas aparecerán aquí',
                  )
                else
                  ...recentTasks.map((task) {
                    return TaskCard(
                      task: task,
                      onTap: () {
                        // Navegar a detalles de la tarea
                      },
                    );
                  }),
                
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
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

  void _promoteMember(BuildContext context, member) {
    final communityProvider = context.read<CommunityProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promover Miembro'),
        content: Text('¿Deseas promover a ${member.name} como administrador?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await communityProvider.updateMemberRole(
                widget.communityId,
                member.userId,
                'admin',
              );
              
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${member.name} promovido a administrador')),
                );
              }
            },
            child: const Text('Promover'),
          ),
        ],
      ),
    );
  }

  void _removeMember(BuildContext context, member) {
    final communityProvider = context.read<CommunityProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Miembro'),
        content: Text('¿Estás seguro de que deseas remover a ${member.name} de la comunidad?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await communityProvider.removeMember(
                widget.communityId,
                member.userId,
              );
              
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${member.name} removido de la comunidad')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}