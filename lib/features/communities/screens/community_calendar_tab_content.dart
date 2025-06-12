import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart';
import 'package:classroom_mejorado/features/tasks/screens/task_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CommunityCalendarTabContent extends StatefulWidget {
  final String communityId;

  const CommunityCalendarTabContent({super.key, required this.communityId});

  @override
  State<CommunityCalendarTabContent> createState() =>
      _CommunityCalendarTabContentState();
}

class _CommunityCalendarTabContentState
    extends State<CommunityCalendarTabContent> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<Map<String, dynamic>>> _tasksByDate = {};
  List<Map<String, dynamic>> _selectedDayTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _loadTasksWithDeadlines();
  }

  Future<void> _loadTasksWithDeadlines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .get();

      Map<DateTime, List<Map<String, dynamic>>> tasksByDate = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dueDateTimestamp = data['dueDate'] as Timestamp?;

        if (dueDateTimestamp != null) {
          final dueDate = dueDateTimestamp.toDate();
          final normalizedDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

          final taskData = {
            'id': doc.id,
            'title': data['title'] ?? 'Sin título',
            'description': data['description'] ?? '',
            'status': data['state'] ?? 'toDo',
            'priority': data['priority'] ?? 'medium',
            'dueDate': dueDate,
            'assignedTo': data['assignedTo'] as String?,
            'assignedToName': data['assignedToName'] as String?,
            'createdBy': data['createdBy'] as String?,
            'createdAt': data['createdAt'] as Timestamp?,
          };

          if (tasksByDate[normalizedDate] == null) {
            tasksByDate[normalizedDate] = [];
          }
          tasksByDate[normalizedDate]!.add(taskData);
        }
      }

      // Ordenar tareas por hora de entrega dentro de cada día
      tasksByDate.forEach((date, tasks) {
        tasks.sort((a, b) {
          final timeA = a['dueDate'] as DateTime;
          final timeB = b['dueDate'] as DateTime;
          return timeA.compareTo(timeB);
        });
      });

      setState(() {
        _tasksByDate = tasksByDate;
        _selectedDayTasks = _getTasksForDay(_selectedDay);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks with deadlines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getTasksForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _tasksByDate[normalizedDay] ?? [];
  }

  TaskState _parseTaskState(String? stateString) {
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

  TaskPriority _parseTaskPriority(String? priorityString) {
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isOverdue(DateTime dueDate) {
    final now = DateTime.now();
    return dueDate.isBefore(now);
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final theme = Theme.of(context);
    final taskState = _parseTaskState(task['status']);
    final taskPriority = _parseTaskPriority(task['priority']);
    final dueDate = task['dueDate'] as DateTime;
    final isOverdue = _isOverdue(dueDate) && taskState != TaskState.done;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue 
              ? Colors.red.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.1),
          width: isOverdue ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOverdue
                ? Colors.red.withOpacity(0.1)
                : theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TaskDetailScreen(
                  taskId: task['id'],
                  communityId: widget.communityId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task['title'] ?? 'Sin título',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          fontWeight: FontWeight.w600,
                          color: isOverdue 
                              ? Colors.red[700] 
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOverdue && taskState != TaskState.done) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'VENCIDA',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                
                // Hora de entrega y estado
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: isOverdue ? Colors.red[600] : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(dueDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: isOverdue ? Colors.red[600] : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: taskState.getColor(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            taskState.getIcon(),
                            size: 14,
                            color: taskState.getColor(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            taskState.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              color: taskState.getColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: taskPriority.getColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        taskPriority.displayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: taskPriority.getColor(),
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
                
                if (task['assignedToName']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Asignado a: ${task['assignedToName']}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarMarker(DateTime day, List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    
    // Contar tareas por estado
    int completedTasks = tasks.where((task) => _parseTaskState(task['status']) == TaskState.done).length;
    int overdueTasks = tasks.where((task) {
      final dueDate = task['dueDate'] as DateTime;
      return _isOverdue(dueDate) && _parseTaskState(task['status']) != TaskState.done;
    }).length;
    
    Color markerColor;
    if (overdueTasks > 0) {
      markerColor = Colors.red;
    } else if (completedTasks == tasks.length) {
      markerColor = Colors.green;
    } else {
      markerColor = theme.colorScheme.primary;
    }

    return Positioned(
      bottom: 1,
      right: 1,
      child: Container(
        width: 20,
        height: 12,
        decoration: BoxDecoration(
          color: markerColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            tasks.length.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              fontFamily: fontFamilyPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          color: theme.colorScheme.background,
          child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando calendario...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Calendario
                Container(
                  margin: const EdgeInsets.all(16),
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
                  child: TableCalendar<Map<String, dynamic>>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: _calendarFormat,
                    eventLoader: _getTasksForDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: TextStyle(
                        color: theme.colorScheme.error,
                        fontFamily: fontFamilyPrimary,
                      ),
                      defaultTextStyle: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontFamily: fontFamilyPrimary,
                      ),
                      todayTextStyle: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      selectedTextStyle: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      todayDecoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                    ),
                    
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonShowsNext: false,
                      formatButtonDecoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      formatButtonTextStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      titleTextStyle: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontFamily: fontFamilyPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        return _buildCalendarMarker(day, events);
                      },
                    ),
                    
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                        _selectedDayTasks = _getTasksForDay(selectedDay);
                      });
                    },
                    
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ),
                
                // Header para tareas del día seleccionado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_note,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isToday(_selectedDay) 
                            ? 'Tareas de hoy (${_selectedDayTasks.length})'
                            : 'Tareas del ${DateFormat('dd/MM/yyyy').format(_selectedDay)} (${_selectedDayTasks.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Lista de tareas del día seleccionado
                Expanded(
                  child: _selectedDayTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 64,
                                color: theme.colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isToday(_selectedDay) 
                                    ? 'No hay tareas para hoy'
                                    : 'No hay tareas para este día',
                                style: TextStyle(
                                  fontFamily: fontFamilyPrimary,
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _selectedDayTasks.length,
                          itemBuilder: (context, index) {
                            return _buildTaskCard(_selectedDayTasks[index]);
                          },
                        ),
                ),
              ],
            ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _loadTasksWithDeadlines,
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              Icons.refresh,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}