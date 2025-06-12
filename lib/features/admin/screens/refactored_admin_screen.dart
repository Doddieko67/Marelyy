import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/admin/providers/admin_provider.dart';
import 'package:classroom_mejorado/shared/widgets/common/stat_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/community_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/section_header.dart';
import 'package:classroom_mejorado/shared/widgets/common/loading_widget.dart';

class RefactoredAdminDashboardScreen extends StatefulWidget {
  const RefactoredAdminDashboardScreen({super.key});

  @override
  State<RefactoredAdminDashboardScreen> createState() => _RefactoredAdminDashboardScreenState();
}

class _RefactoredAdminDashboardScreenState extends State<RefactoredAdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Panel de Administración',
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
          Consumer<AdminProvider>(
            builder: (context, adminProvider, child) {
              return IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => adminProvider.refresh(),
              );
            },
          ),
        ],
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading) {
            return const LoadingWidget(message: 'Cargando datos del panel...');
          }

          if (adminProvider.error != null) {
            return ErrorWidget(
              message: adminProvider.error!,
              onRetry: () => adminProvider.refresh(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estadísticas generales
                Text(
                  'Estadísticas Generales',
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
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      title: 'Total Comunidades',
                      value: adminProvider.globalStats.totalCommunities.toString(),
                      icon: Icons.groups,
                      color: theme.colorScheme.primary,
                    ),
                    StatCard(
                      title: 'Total Usuarios',
                      value: adminProvider.globalStats.totalUsers.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                    StatCard(
                      title: 'Total Tareas',
                      value: adminProvider.globalStats.totalTasks.toString(),
                      icon: Icons.task,
                      color: Colors.orange,
                    ),
                    StatCard(
                      title: 'Tareas Activas',
                      value: adminProvider.globalStats.activeTasks.toString(),
                      icon: Icons.pending_actions,
                      color: Colors.green,
                      subtitle: '${adminProvider.globalStats.activeRate.toStringAsFixed(1)}% del total',
                    ),
                  ],
                ),
                
                // Comunidades recientes
                SectionHeader(
                  title: 'Comunidades Recientes',
                  icon: Icons.schedule,
                  actionText: 'Ver todas',
                  onActionPressed: () {
                    // Navegar a vista completa de comunidades
                  },
                ),
                
                if (adminProvider.recentCommunities.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.groups_outlined,
                    title: 'No hay comunidades recientes',
                    subtitle: 'Las comunidades creadas recientemente aparecerán aquí',
                  )
                else
                  ...adminProvider.recentCommunities.map((community) {
                    return CommunityCard(
                      community: community,
                      onTap: () {
                        // Navegar a detalles de la comunidad
                      },
                    );
                  }),
                
                // Comunidades más populares
                SectionHeader(
                  title: 'Comunidades Más Populares',
                  icon: Icons.trending_up,
                  actionText: 'Ver ranking',
                  onActionPressed: () {
                    // Navegar a ranking completo
                  },
                ),
                
                if (adminProvider.topCommunities.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.bar_chart_outlined,
                    title: 'No hay datos de popularidad',
                    subtitle: 'Las comunidades más activas aparecerán aquí',
                  )
                else
                  ...adminProvider.topCommunities.map((community) {
                    return CommunityCard(
                      community: community,
                      onTap: () {
                        // Navegar a detalles de la comunidad
                      },
                    );
                  }),
                
                const SizedBox(height: 32),
                
                // Métricas de rendimiento
                SectionHeader(
                  title: 'Métricas de Rendimiento',
                  icon: Icons.analytics,
                ),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildMetricRow(
                          context,
                          'Tasa de Completitud',
                          '${adminProvider.globalStats.completionRate.toStringAsFixed(1)}%',
                          Icons.check_circle,
                          Colors.green,
                        ),
                        const Divider(),
                        _buildMetricRow(
                          context,
                          'Engagement de Usuarios',
                          '${(adminProvider.globalStats.totalTasks / (adminProvider.globalStats.totalUsers.isZero ? 1 : adminProvider.globalStats.totalUsers) * 100).toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.blue,
                        ),
                        const Divider(),
                        _buildMetricRow(
                          context,
                          'Comunidades Activas',
                          '${((adminProvider.globalStats.totalCommunities * 0.8).round())}',
                          Icons.groups_rounded,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

extension on int {
  bool get isZero => this == 0;
}