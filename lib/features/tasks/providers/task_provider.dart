import 'package:flutter/foundation.dart';
import 'package:classroom_mejorado/features/tasks/models/task_model.dart';
import 'package:classroom_mejorado/features/tasks/services/task_service.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();

  List<Task> _communityTasks = [];
  List<Task> _userTasks = [];
  Task? _selectedTask;
  List<TaskComment> _taskComments = [];
  Map<DateTime, List<Task>> _calendarTasks = {};
  TaskFilter? _currentFilter;
  bool _isLoading = false;
  bool _isLoadingComments = false;
  String? _error;

  // Getters
  List<Task> get communityTasks => _communityTasks;
  List<Task> get userTasks => _userTasks;
  Task? get selectedTask => _selectedTask;
  List<TaskComment> get taskComments => _taskComments;
  Map<DateTime, List<Task>> get calendarTasks => _calendarTasks;
  TaskFilter? get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  bool get isLoadingComments => _isLoadingComments;
  String? get error => _error;

  // Cargar tareas de una comunidad
  void loadCommunityTasks(String communityId, {TaskFilter? filter}) {
    _isLoading = true;
    _error = null;
    _currentFilter = filter;
    notifyListeners();

    _taskService.getCommunityTasks(communityId, filter: filter).listen(
      (tasks) {
        _communityTasks = tasks;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Cargar tareas del usuario
  void loadUserTasks({TaskFilter? filter}) {
    _isLoading = true;
    _error = null;
    _currentFilter = filter;
    notifyListeners();

    _taskService.getUserTasks(filter: filter).listen(
      (tasks) {
        _userTasks = tasks;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Seleccionar una tarea
  void selectTask(Task task) {
    _selectedTask = task;
    notifyListeners();
    loadTaskComments(task.communityId, task.id);
  }

  // Obtener tarea por ID (para streams)
  void loadTaskStream(String communityId, String taskId) {
    _taskService.getTaskStream(communityId, taskId).listen(
      (task) {
        if (task != null) {
          _selectedTask = task;
          notifyListeners();
        }
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Cargar comentarios de tarea
  void loadTaskComments(String communityId, String taskId) {
    _isLoadingComments = true;
    notifyListeners();

    _taskService.getTaskComments(communityId, taskId).listen(
      (comments) {
        _taskComments = comments;
        _isLoadingComments = false;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoadingComments = false;
        notifyListeners();
      },
    );
  }

  // Cargar tareas para calendario
  Future<void> loadCalendarTasks(String communityId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _calendarTasks = await _taskService.getTasksForCalendar(communityId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Obtener tareas para un día específico
  List<Task> getTasksForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _calendarTasks[normalizedDay] ?? [];
  }

  // Crear nueva tarea
  Future<String?> createTask(Task task) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final taskId = await _taskService.createTask(task);
      _isLoading = false;
      notifyListeners();
      
      return taskId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Actualizar tarea
  Future<bool> updateTask(String communityId, String taskId, Map<String, dynamic> updates) async {
    try {
      _error = null;
      await _taskService.updateTask(communityId, taskId, updates);
      
      // Actualizar la tarea seleccionada si es la misma
      if (_selectedTask?.id == taskId) {
        final updatedTask = await _taskService.getTask(communityId, taskId);
        if (updatedTask != null) {
          _selectedTask = updatedTask;
          notifyListeners();
        }
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Actualizar estado de tarea
  Future<bool> updateTaskStatus(String communityId, String taskId, TaskState newStatus) async {
    try {
      _error = null;
      await _taskService.updateTaskStatus(communityId, taskId, newStatus);
      
      // Actualizar la tarea seleccionada si es la misma
      if (_selectedTask?.id == taskId) {
        _selectedTask = _selectedTask!.copyWith(status: newStatus);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Asignar tarea
  Future<bool> assignTask(String communityId, String taskId, String userId, String userName) async {
    try {
      _error = null;
      await _taskService.assignTask(communityId, taskId, userId, userName);
      
      // Actualizar la tarea seleccionada si es la misma
      if (_selectedTask?.id == taskId) {
        _selectedTask = _selectedTask!.copyWith(
          assignedTo: userId,
          assignedToName: userName,
        );
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Eliminar tarea
  Future<bool> deleteTask(String communityId, String taskId) async {
    try {
      _error = null;
      await _taskService.deleteTask(communityId, taskId);
      
      // Si era la tarea seleccionada, limpiar selección
      if (_selectedTask?.id == taskId) {
        _selectedTask = null;
        _taskComments.clear();
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Agregar comentario
  Future<bool> addTaskComment(String communityId, String taskId, String content) async {
    try {
      _error = null;
      await _taskService.addTaskComment(communityId, taskId, content);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Obtener tareas que vencen hoy
  Future<List<Task>> getTasksDueToday(String communityId) async {
    try {
      return await _taskService.getTasksDueToday(communityId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Obtener tareas vencidas
  Future<List<Task>> getOverdueTasks(String communityId) async {
    try {
      return await _taskService.getOverdueTasks(communityId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Buscar tareas
  Future<List<Task>> searchTasks(String communityId, String query) async {
    try {
      return await _taskService.searchTasks(communityId, query);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Aplicar filtro
  void applyFilter(TaskFilter? filter) {
    _currentFilter = filter;
    
    if (_communityTasks.isNotEmpty) {
      // Si hay tareas de comunidad cargadas, recargar con filtro
      final communityId = _communityTasks.first.communityId;
      loadCommunityTasks(communityId, filter: filter);
    }
    
    if (_userTasks.isNotEmpty) {
      // Si hay tareas de usuario cargadas, recargar con filtro
      loadUserTasks(filter: filter);
    }
  }

  // Limpiar filtro
  void clearFilter() {
    applyFilter(null);
  }

  // Obtener estadísticas de tareas filtradas
  Map<String, int> getTaskStatistics(List<Task> tasks) {
    Map<String, int> stats = {
      'total': tasks.length,
      'completed': 0,
      'active': 0,
      'overdue': 0,
      'dueToday': 0,
    };

    for (var task in tasks) {
      if (task.status == TaskState.done) {
        stats['completed'] = stats['completed']! + 1;
      } else {
        stats['active'] = stats['active']! + 1;
      }
      
      if (task.isOverdue) {
        stats['overdue'] = stats['overdue']! + 1;
      }
      
      if (task.isDueToday) {
        stats['dueToday'] = stats['dueToday']! + 1;
      }
    }

    return stats;
  }

  // Ordenar tareas
  void sortTasks(List<Task> tasks, String sortBy, {bool ascending = true}) {
    switch (sortBy) {
      case 'title':
        tasks.sort((a, b) => ascending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
        break;
      case 'dueDate':
        tasks.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return ascending ? 1 : -1;
          if (b.dueDate == null) return ascending ? -1 : 1;
          return ascending ? a.dueDate!.compareTo(b.dueDate!) : b.dueDate!.compareTo(a.dueDate!);
        });
        break;
      case 'priority':
        tasks.sort((a, b) => ascending ? a.priority.index.compareTo(b.priority.index) : b.priority.index.compareTo(a.priority.index));
        break;
      case 'status':
        tasks.sort((a, b) => ascending ? a.status.index.compareTo(b.status.index) : b.status.index.compareTo(a.status.index));
        break;
      case 'createdAt':
      default:
        tasks.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return ascending ? 1 : -1;
          if (b.createdAt == null) return ascending ? -1 : 1;
          return ascending ? a.createdAt!.compareTo(b.createdAt!) : b.createdAt!.compareTo(a.createdAt!);
        });
        break;
    }
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Limpiar selección
  void clearSelection() {
    _selectedTask = null;
    _taskComments.clear();
    notifyListeners();
  }

  // Refrescar datos
  void refresh(String? communityId) {
    if (communityId != null) {
      loadCommunityTasks(communityId, filter: _currentFilter);
      loadCalendarTasks(communityId);
    }
    loadUserTasks(filter: _currentFilter);
    
    if (_selectedTask != null) {
      loadTaskComments(_selectedTask!.communityId, _selectedTask!.id);
    }
  }
}