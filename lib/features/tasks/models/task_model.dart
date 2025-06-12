import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final TaskState status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final String? assignedTo;
  final String? assignedToName;
  final String? createdBy;
  final String? createdByName;
  final String communityId;
  final List<String> attachments;
  final List<TaskComment> comments;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    this.createdAt,
    this.assignedTo,
    this.assignedToName,
    this.createdBy,
    this.createdByName,
    required this.communityId,
    this.attachments = const [],
    this.comments = const [],
  });

  factory Task.fromFirestore(DocumentSnapshot doc, String communityId) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: _parseTaskState(data['status']),
      priority: _parseTaskPriority(data['priority']),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      assignedTo: data['assignedTo'],
      assignedToName: data['assignedToName'],
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      communityId: communityId,
      attachments: List<String>.from(data['attachments'] ?? []),
      comments: [], // Los comentarios se cargan por separado
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'attachments': attachments,
    };
  }

  static TaskState _parseTaskState(String? stateString) {
    if (stateString == null || stateString.isEmpty) {
      return TaskState.toDo;
    }

    final String stateLower = stateString.toLowerCase();

    for (TaskState state in TaskState.values) {
      if (state.name.toLowerCase() == stateLower) {
        return state;
      }
    }

    switch (stateLower) {
      case 'testing':
        return TaskState.underReview;
      case 'todo':
      case 'to_do':
        return TaskState.toDo;
      case 'inprogress':
      case 'in_progress':
        return TaskState.doing;
      case 'review':
      case 'under_review':
        return TaskState.underReview;
      case 'completed':
      case 'finished':
        return TaskState.done;
      default:
        return TaskState.toDo;
    }
  }

  static TaskPriority _parseTaskPriority(String? priorityString) {
    if (priorityString == null || priorityString.isEmpty) {
      return TaskPriority.medium;
    }

    final String priorityLower = priorityString.toLowerCase();

    for (TaskPriority priority in TaskPriority.values) {
      if (priority.name.toLowerCase() == priorityLower) {
        return priority;
      }
    }

    switch (priorityLower) {
      case 'low':
      case 'baja':
        return TaskPriority.low;
      case 'medium':
      case 'media':
        return TaskPriority.medium;
      case 'high':
      case 'alta':
        return TaskPriority.high;
      case 'urgent':
      case 'urgente':
        return TaskPriority.urgent;
      default:
        return TaskPriority.medium;
    }
  }

  bool get isOverdue {
    if (dueDate == null || status == TaskState.done) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return taskDate.isAtSameMomentAs(today);
  }

  bool get isDueSoon {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final diff = dueDate!.difference(now);
    return diff.inHours <= 24 && diff.inHours >= 0;
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskState? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    String? assignedTo,
    String? assignedToName,
    String? createdBy,
    String? createdByName,
    String? communityId,
    List<String>? attachments,
    List<TaskComment>? comments,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      communityId: communityId ?? this.communityId,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
    );
  }
}

class TaskComment {
  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime? createdAt;

  TaskComment({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.createdAt,
  });

  factory TaskComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TaskComment(
      id: doc.id,
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}

class TaskFilter {
  final TaskState? status;
  final TaskPriority? priority;
  final String? assignedTo;
  final DateTime? dueDateFrom;
  final DateTime? dueDateTo;
  final bool? isOverdue;

  TaskFilter({
    this.status,
    this.priority,
    this.assignedTo,
    this.dueDateFrom,
    this.dueDateTo,
    this.isOverdue,
  });

  bool matches(Task task) {
    if (status != null && task.status != status) return false;
    if (priority != null && task.priority != priority) return false;
    if (assignedTo != null && task.assignedTo != assignedTo) return false;
    if (isOverdue != null && task.isOverdue != isOverdue) return false;
    
    if (dueDateFrom != null && task.dueDate != null) {
      if (task.dueDate!.isBefore(dueDateFrom!)) return false;
    }
    
    if (dueDateTo != null && task.dueDate != null) {
      if (task.dueDate!.isAfter(dueDateTo!)) return false;
    }
    
    return true;
  }

  TaskFilter copyWith({
    TaskState? status,
    TaskPriority? priority,
    String? assignedTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    bool? isOverdue,
  }) {
    return TaskFilter(
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDateFrom: dueDateFrom ?? this.dueDateFrom,
      dueDateTo: dueDateTo ?? this.dueDateTo,
      isOverdue: isOverdue ?? this.isOverdue,
    );
  }
}