// lib/utils/task_utils.dart - FUNCIONES COMPARTIDAS PARA TODAS LAS PANTALLAS DE TAREAS
import 'package:flutter/material.dart';

// ✅ ENUM PRINCIPAL DE ESTADOS DE TAREA
enum TaskState { toDo, doing, underReview, done }

extension TaskStateExtension on TaskState {
  String get name {
    switch (this) {
      case TaskState.toDo:
        return 'Por hacer';
      case TaskState.doing:
        return 'Haciendo';
      case TaskState.underReview:
        return 'Por revisar';
      case TaskState.done:
        return 'Hecho';
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case TaskState.toDo:
        return Colors.orange[700]!;
      case TaskState.doing:
        return Colors.blue[700]!;
      case TaskState.underReview:
        return Colors.purple[700]!;
      case TaskState.done:
        return Colors.green[700]!;
    }
  }

  // ✅ FUNCIÓN PARA OBTENER ICONO DEL ESTADO
  IconData getIcon() {
    switch (this) {
      case TaskState.toDo:
        return Icons.radio_button_unchecked;
      case TaskState.doing:
        return Icons.hourglass_empty;
      case TaskState.underReview:
        return Icons.rate_review;
      case TaskState.done:
        return Icons.check_circle;
    }
  }

  // ✅ FUNCIÓN PARA OBTENER NOMBRE PARA DISPLAY (usado en TaskDetailScreen)
  String getDisplayName() {
    switch (this) {
      case TaskState.toDo:
        return 'Por Hacer';
      case TaskState.doing:
        return 'En Progreso';
      case TaskState.underReview:
        return 'Por Revisar';
      case TaskState.done:
        return 'Completado';
    }
  }

  // ✅ FUNCIÓN PARA OBTENER COLOR PARA TaskDetailScreen
  Color getDetailColor(ThemeData theme) {
    switch (this) {
      case TaskState.toDo:
        return Colors.grey.shade600;
      case TaskState.doing:
        return Colors.blue.shade600;
      case TaskState.underReview:
        return Colors.orange.shade600;
      case TaskState.done:
        return Colors.green.shade600;
    }
  }
}

// ✅ ENUM DE PRIORIDADES DE TAREA
enum TaskPriority { low, medium, high, urgent }

extension TaskPriorityExtension on TaskPriority {
  String get name {
    switch (this) {
      case TaskPriority.low:
        return 'Baja';
      case TaskPriority.medium:
        return 'Media';
      case TaskPriority.high:
        return 'Alta';
      case TaskPriority.urgent:
        return 'Urgente';
    }
  }

  Color getColor() {
    switch (this) {
      case TaskPriority.low:
        return Colors.green[600]!;
      case TaskPriority.medium:
        return Colors.blue[600]!;
      case TaskPriority.high:
        return Colors.orange[600]!;
      case TaskPriority.urgent:
        return Colors.red[600]!;
    }
  }

  IconData getIcon() {
    switch (this) {
      case TaskPriority.low:
        return Icons.keyboard_arrow_down;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.keyboard_arrow_up;
      case TaskPriority.urgent:
        return Icons.priority_high;
    }
  }
}

// ✅ CLASE UTILITARIA CON FUNCIONES ESTÁTICAS COMPARTIDAS
class TaskUtils {
  // ✅ FUNCIÓN PRINCIPAL PARA PARSEAR ESTADOS (COPIADA DE TaskDetailScreen)
  static TaskState parseTaskState(String? stateString) {
    if (stateString == null || stateString.isEmpty) {
      return TaskState.toDo;
    }

    // Limpiar espacios y convertir a minúsculas
    final String cleanState = stateString.trim().toLowerCase();

    // Mapeo directo por nombre del enum
    for (TaskState state in TaskState.values) {
      if (state.name.toLowerCase() == cleanState) {
        return state;
      }
    }

    // Mapeo de valores legacy/alternativos
    switch (cleanState) {
      case 'todo':
      case 'to_do':
      case 'por hacer':
        return TaskState.toDo;
      case 'doing':
      case 'in_progress':
      case 'inprogress':
      case 'haciendo':
        return TaskState.doing;
      case 'testing':
      case 'under_review':
      case 'underreview':
      case 'review':
      case 'por revisar':
        return TaskState.underReview;
      case 'done':
      case 'completed':
      case 'finished':
      case 'hecho':
        return TaskState.done;
      default:
        print(
          '⚠️ TaskUtils: Estado no reconocido: "$stateString" → usando toDo',
        );
        return TaskState.toDo;
    }
  }

  // ✅ FUNCIÓN PARA PARSEAR PRIORIDADES
  static TaskPriority parseTaskPriority(String? priorityString) {
    if (priorityString == null || priorityString.isEmpty) {
      return TaskPriority.medium;
    }

    final String cleanPriority = priorityString.trim().toLowerCase();

    // Mapeo directo por nombre del enum
    for (TaskPriority priority in TaskPriority.values) {
      if (priority.name.toLowerCase() == cleanPriority) {
        return priority;
      }
    }

    // Mapeo de valores alternativos
    switch (cleanPriority) {
      case 'baja':
      case 'low':
        return TaskPriority.low;
      case 'media':
      case 'medium':
        return TaskPriority.medium;
      case 'alta':
      case 'high':
        return TaskPriority.high;
      case 'urgente':
      case 'urgent':
        return TaskPriority.urgent;
      default:
        print(
          '⚠️ TaskUtils: Prioridad no reconocida: "$priorityString" → usando medium',
        );
        return TaskPriority.medium;
    }
  }

  // ✅ FUNCIÓN PARA NORMALIZAR PRIORIDAD (usado en TaskDetailScreen)
  static String normalizePriority(String? priority) {
    if (priority == null || priority.isEmpty) return 'Media';

    switch (priority.toLowerCase().trim()) {
      case 'baja':
      case 'low':
        return 'Baja';
      case 'media':
      case 'medium':
        return 'Media';
      case 'alta':
      case 'high':
        return 'Alta';
      case 'urgente':
      case 'urgent':
        return 'Urgente';
      default:
        return 'Media';
    }
  }

  // ✅ FUNCIÓN PARA OBTENER COLOR DE PRIORIDAD (usado en TaskDetailScreen)
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'baja':
        return TaskPriority.low.getColor();
      case 'media':
        return TaskPriority.medium.getColor();
      case 'alta':
        return TaskPriority.high.getColor();
      case 'urgente':
        return TaskPriority.urgent.getColor();
      default:
        return TaskPriority.medium.getColor();
    }
  }

  // ✅ FUNCIÓN PARA FORMATEAR TAMAÑO DE ARCHIVO (usado en TaskDetailScreen)
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // ✅ FUNCIÓN PARA DETECTAR TIPO DE ARCHIVO (usado en TaskDetailScreen)
  static String detectFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
    return imageExtensions.contains(extension) ? 'image' : 'file';
  }

  // ✅ FUNCIÓN PARA VALIDAR TRANSICIONES DE ESTADO
  static bool canTransitionToState(
    TaskState currentState,
    TaskState targetState,
  ) {
    switch (targetState) {
      case TaskState.toDo:
        return true; // Siempre se puede volver a "Por Hacer"

      case TaskState.doing:
        return currentState == TaskState.toDo ||
            currentState == TaskState.underReview;

      case TaskState.underReview:
        return currentState == TaskState.doing; // Solo desde "En Progreso"

      case TaskState.done:
        return currentState ==
            TaskState.underReview; // Solo desde "Por Revisar"
    }
  }

  // ✅ FUNCIÓN DE DEBUG CONSISTENTE PARA TODAS LAS PANTALLAS

  // ✅ FUNCIÓN PARA CREAR WIDGET DE DEBUG VISUAL
}

TaskState parseTaskState(String? stateString) {
  if (stateString == null || stateString.isEmpty) {
    return TaskState.toDo;
  }

  final String stateLower = stateString.toLowerCase();

  // Mapeo directo por nombre del enum
  for (TaskState state in TaskState.values) {
    if (state.name.toLowerCase() == stateLower) {
      return state;
    }
  }

  // Retrocompatibilidad: Mapear valores antiguos o en español
  switch (stateLower) {
    case 'testing':
      return TaskState.underReview;
    case 'todo':
    case 'to_do':
    case 'por hacer':
      return TaskState.toDo;
    case 'inprogress':
    case 'in_progress':
    case 'haciendo':
      return TaskState.doing;
    case 'review':
    case 'under_review':
    case 'por revisar':
      return TaskState.underReview;
    case 'completed':
    case 'finished':
    case 'hecho':
      return TaskState.done;
    default:
      print('⚠️ Estado desconocido: $stateString - usando toDo por defecto');
      return TaskState.toDo;
  }
}
