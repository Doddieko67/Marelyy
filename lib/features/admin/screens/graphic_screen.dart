import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/admin/providers/admin_provider.dart';
import 'package:classroom_mejorado/shared/widgets/common/stat_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/community_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/section_header.dart';
import 'package:classroom_mejorado/shared/widgets/common/loading_widget.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Variables de estado
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Estadísticas
  int _totalCommunities = 0;
  int _totalUsers = 0;
  int _totalTasks = 0;
  int _activeTasks = 0;
  
  // Listas de datos
  List<Map<String, dynamic>> _recentCommunities = [];
  List<Map<String, dynamic>> _topCommunities = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar estad�sticas generales
      await Future.wait([
        _loadCommunityStats(),
        _loadTaskStats(),
        _loadRecentCommunities(),
        _loadTopCommunities(),
      ]);
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCommunityStats() async {
    try {
      // Contar total de comunidades
      final communitiesSnapshot = await _firestore.collection('communities').get();
      _totalCommunities = communitiesSnapshot.docs.length;

      // Contar usuarios �nicos en todas las comunidades
      Set<String> uniqueUsers = {};
      for (var doc in communitiesSnapshot.docs) {
        final data = doc.data();
        final members = data['members'] as List<dynamic>? ?? [];
        uniqueUsers.addAll(members.cast<String>());
      }
      _totalUsers = uniqueUsers.length;
    } catch (e) {
      print('Error loading community stats: $e');
    }
  }

  Future<void> _loadTaskStats() async {
    try {
      // Contar todas las tareas
      final tasksSnapshot = await _firestore.collectionGroup('tasks').get();
      _totalTasks = tasksSnapshot.docs.length;
      
      // Contar tareas activas (no completadas)
      _activeTasks = tasksSnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        return status != 'completed';
      }).length;
    } catch (e) {
      print('Error loading task stats: $e');
    }
  }

  Future<void> _loadRecentCommunities() async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      _recentCommunities = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sin nombre',
          'description': data['description'] ?? '',
          'memberCount': (data['members'] as List<dynamic>?)?.length ?? 0,
          'createdAt': data['createdAt'] as Timestamp?,
          'imageUrl': data['imageUrl'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error loading recent communities: $e');
    }
  }

  Future<void> _loadTopCommunities() async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .orderBy('memberCount', descending: true)
          .limit(5)
          .get();
      
      _topCommunities = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sin nombre',
          'description': data['description'] ?? '',
          'memberCount': (data['members'] as List<dynamic>?)?.length ?? 0,
          'createdAt': data['createdAt'] as Timestamp?,
          'imageUrl': data['imageUrl'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error loading top communities: $e');
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha desconocida';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
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
          if (subtitle != null) ...[
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

  Widget _buildCommunityCard(Map<String, dynamic> community) {
    final theme = Theme.of(context);
    
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
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: community['imageUrl']?.isNotEmpty == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      community['imageUrl'],
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.group,
                          color: theme.colorScheme.primary,
                          size: 24,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.group,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community['name'] ?? 'Sin nombre',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${community['memberCount']} miembros',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (community['createdAt'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(community['createdAt']),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
          'Panel de Administraci�n',
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
            onPressed: _loadDashboardData,
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
                    'Cargando datos...',
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
                  // Estad�sticas generales
                  Text(
                    'Estad�sticas Generales',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Grid de estad�sticas
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                        title: 'Total Comunidades',
                        value: _totalCommunities.toString(),
                        icon: Icons.groups,
                        color: theme.colorScheme.primary,
                      ),
                      _buildStatCard(
                        title: 'Total Usuarios',
                        value: _totalUsers.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: 'Total Tareas',
                        value: _totalTasks.toString(),
                        icon: Icons.task,
                        color: Colors.orange,
                      ),
                      _buildStatCard(
                        title: 'Tareas Activas',
                        value: _activeTasks.toString(),
                        icon: Icons.pending_actions,
                        color: Colors.green,
                        subtitle: '${((_activeTasks / (_totalTasks.isZero ? 1 : _totalTasks)) * 100).toStringAsFixed(1)}% del total',
                      ),
                    ],
                  ),
                  
                  // Comunidades recientes
                  _buildSectionHeader('Comunidades Recientes', Icons.schedule),
                  
                  if (_recentCommunities.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay comunidades recientes',
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_recentCommunities.map((community) => _buildCommunityCard(community))),
                  
                  // Comunidades m�s populares
                  _buildSectionHeader('Comunidades M�s Populares', Icons.trending_up),
                  
                  if (_topCommunities.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bar_chart_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay datos de popularidad',
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_topCommunities.map((community) => _buildCommunityCard(community))),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

extension on int {
  bool get isZero => this == 0;
}