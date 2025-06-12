import 'package:flutter/foundation.dart';
import 'package:classroom_mejorado/features/communities/models/community_model.dart';
import 'package:classroom_mejorado/features/tasks/models/user_model.dart';
import 'package:classroom_mejorado/features/communities/services/community_service.dart';
import 'package:classroom_mejorado/features/tasks/services/task_service.dart';

class AdminProvider extends ChangeNotifier {
  final CommunityService _communityService = CommunityService();
  final TaskService _taskService = TaskService();

  AdminStats _globalStats = AdminStats.empty();
  List<Community> _recentCommunities = [];
  List<Community> _topCommunities = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  AdminStats get globalStats => _globalStats;
  List<Community> get recentCommunities => _recentCommunities;
  List<Community> get topCommunities => _topCommunities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cargar estadísticas globales del dashboard de administración
  Future<void> loadGlobalStats() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Cargar estadísticas de tareas
      final taskStats = await _taskService.getGlobalTaskStats();
      
      // Cargar comunidades para contar usuarios únicos
      final recentCommunities = await _communityService.getRecentCommunities(limit: 100);
      
      // Contar usuarios únicos
      Set<String> uniqueUsers = {};
      int totalCommunities = recentCommunities.length;
      
      for (var community in recentCommunities) {
        uniqueUsers.addAll(community.members);
      }

      _globalStats = AdminStats(
        totalCommunities: totalCommunities,
        totalUsers: uniqueUsers.length,
        totalTasks: taskStats['totalTasks'] ?? 0,
        activeTasks: taskStats['activeTasks'] ?? 0,
        completedTasks: taskStats['completedTasks'] ?? 0,
        tasksByStatus: Map<String, int>.from(taskStats['tasksByStatus'] ?? {}),
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar comunidades recientes
  Future<void> loadRecentCommunities({int limit = 5}) async {
    try {
      _recentCommunities = await _communityService.getRecentCommunities(limit: limit);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Cargar comunidades más populares
  Future<void> loadTopCommunities({int limit = 5}) async {
    try {
      _topCommunities = await _communityService.getTopCommunities(limit: limit);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Cargar todos los datos del dashboard
  Future<void> loadDashboardData() async {
    await Future.wait([
      loadGlobalStats(),
      loadRecentCommunities(),
      loadTopCommunities(),
    ]);
  }

  // Obtener estadísticas de crecimiento por período
  Future<Map<String, int>> getGrowthStats(String period) async {
    try {
      // Por simplicidad, simulamos datos de crecimiento
      // En una implementación real, esto consultaría datos históricos
      Map<String, int> growthData = {};
      
      switch (period) {
        case 'week':
          for (int i = 6; i >= 0; i--) {
            final date = DateTime.now().subtract(Duration(days: i));
            final dayName = _getDayName(date.weekday);
            growthData[dayName] = (i * 2 + 1); // Datos simulados
          }
          break;
        case 'month':
          for (int i = 29; i >= 0; i--) {
            final date = DateTime.now().subtract(Duration(days: i));
            final day = '${date.day}/${date.month}';
            growthData[day] = (i % 7 + 1); // Datos simulados
          }
          break;
        case 'year':
          for (int i = 11; i >= 0; i--) {
            final date = DateTime.now().subtract(Duration(days: i * 30));
            final month = _getMonthName(date.month);
            growthData[month] = (i * 3 + 5); // Datos simulados
          }
          break;
      }
      
      return growthData;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return {};
    }
  }

  // Obtener estadísticas de actividad por comunidad
  Future<List<Map<String, dynamic>>> getCommunityActivityStats() async {
    try {
      final communities = await _communityService.getRecentCommunities(limit: 10);
      List<Map<String, dynamic>> activityStats = [];

      for (var community in communities) {
        final stats = await _communityService.getCommunityStats(community.id);
        activityStats.add({
          'community': community,
          'stats': stats,
          'activityScore': _calculateActivityScore(stats),
        });
      }

      // Ordenar por puntuación de actividad
      activityStats.sort((a, b) => b['activityScore'].compareTo(a['activityScore']));
      
      return activityStats;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Calcular puntuación de actividad de una comunidad
  double _calculateActivityScore(CommunityStats stats) {
    double score = 0.0;
    
    // Peso por miembros activos
    score += stats.totalMembers * 1.0;
    
    // Peso por tareas completadas
    score += stats.completedTasks * 2.0;
    
    // Peso por tareas activas
    score += stats.activeTasks * 1.5;
    
    // Peso por mensajes
    score += stats.messagesCount * 0.1;
    
    // Bonus por porcentaje de completitud
    if (stats.totalTasks > 0) {
      score += (stats.completedTasks / stats.totalTasks) * 10.0;
    }
    
    return score;
  }

  // Obtener métricas de rendimiento
  Map<String, double> getPerformanceMetrics() {
    return {
      'completionRate': _globalStats.completionRate,
      'activeRate': _globalStats.activeRate,
      'userEngagement': _calculateUserEngagement(),
      'communityGrowth': _calculateCommunityGrowth(),
    };
  }

  // Calcular engagement de usuarios
  double _calculateUserEngagement() {
    if (_globalStats.totalUsers == 0) return 0.0;
    
    // Fórmula simple: tareas activas / usuarios totales
    return (_globalStats.activeTasks / _globalStats.totalUsers) * 100;
  }

  // Calcular crecimiento de comunidades
  double _calculateCommunityGrowth() {
    // En una implementación real, esto compararía con datos históricos
    // Por ahora, simulamos un crecimiento basado en el número actual
    return _globalStats.totalCommunities * 1.5; // Simulado
  }

  // Exportar datos como CSV (simulado)
  String exportStatsAsCSV() {
    StringBuffer csv = StringBuffer();
    
    // Headers
    csv.writeln('Métrica,Valor');
    
    // Datos globales
    csv.writeln('Total Comunidades,${_globalStats.totalCommunities}');
    csv.writeln('Total Usuarios,${_globalStats.totalUsers}');
    csv.writeln('Total Tareas,${_globalStats.totalTasks}');
    csv.writeln('Tareas Activas,${_globalStats.activeTasks}');
    csv.writeln('Tareas Completadas,${_globalStats.completedTasks}');
    csv.writeln('Tasa de Completitud,${_globalStats.completionRate.toStringAsFixed(2)}%');
    
    // Tareas por estado
    _globalStats.tasksByStatus.forEach((status, count) {
      csv.writeln('Tareas $status,$count');
    });
    
    return csv.toString();
  }

  // Helpers para nombres de días y meses
  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refrescar todos los datos
  void refresh() {
    loadDashboardData();
  }
}