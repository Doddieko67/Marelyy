// lib/screen/MyTasksScreen.dart - REFACTORIZADO CON TaskUtils
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/tasks/screens/task_detail_screen.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart'
    as task_utils; // ✅ IMPORT FUNCIONES COMPARTIDAS

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _tasksByDate = {};
  bool _isCalendarView = false;
  
  // Task data
  List<QueryDocumentSnapshot> _allTasks = [];
  bool _isLoading = true; // Start as true for initial load
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadMyTasks();
  }

  Future<void> _loadMyTasks() async {
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collectionGroup('tasks')
          .where('assignedToId', isEqualTo: currentUserUid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _allTasks = snapshot.docs;
        _groupTasksByDate(_allTasks);
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    }
  }

  // Group tasks by date for calendar
  void _groupTasksByDate(List<QueryDocumentSnapshot> tasks) {
    _tasksByDate.clear();
    for (var taskDoc in tasks) {
      final taskData = taskDoc.data() as Map<String, dynamic>;
      final Timestamp? dueDateTimestamp = taskData['dueDate'] as Timestamp?;
      
      if (dueDateTimestamp != null) {
        final dueDate = dueDateTimestamp.toDate();
        final dateKey = DateTime(dueDate.year, dueDate.month, dueDate.day);
        
        if (_tasksByDate[dateKey] == null) {
          _tasksByDate[dateKey] = [];
        }
        
        _tasksByDate[dateKey]!.add({
          'taskDoc': taskDoc,
          'taskData': taskData,
        });
      }
    }
  }

  // Get tasks for selected day
  List<Map<String, dynamic>> _getTasksForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _tasksByDate[dateKey] ?? [];
  }

  Widget _buildTasksContent(ThemeData theme) {
    // Show loading on first load
    if (!_hasLoadedOnce && _isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      );
    }
    
    if (_allTasks.isEmpty && _hasLoadedOnce) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_turned_in_outlined,
                size: 60,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '¡No tienes tareas asignadas!',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Parece que no hay tareas que te hayan asignado',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 16,
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _isCalendarView 
        ? _buildCalendarView(theme, _allTasks)
        : _buildListView(theme, _allTasks);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserUid = _auth.currentUser?.uid;

    if (currentUserUid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Mis Tareas',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onBackground,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.login,
                  size: 60,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Inicia sesión para ver tus tareas',
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Necesitas estar autenticado',
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 16,
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Mis Tareas',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isCalendarView ? Icons.view_list : Icons.calendar_month,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _isCalendarView = !_isCalendarView;
              });
            },
            tooltip: _isCalendarView ? 'Vista de Lista' : 'Vista de Calendario',
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: theme.colorScheme.primary,
            ),
            onPressed: _loadMyTasks,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildTasksContent(theme),
    );
  }

  // Build calendar view
  Widget _buildCalendarView(ThemeData theme, List<QueryDocumentSnapshot> tasks) {
    return Column(
      children: [
        Card(
          key: const ValueKey('calendar_card'),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RepaintBoundary(
              child: TableCalendar<Map<String, dynamic>>(
                key: const ValueKey('my_tasks_calendar'),
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              eventLoader: _getTasksForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.error,
                ),
                defaultTextStyle: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.onSurface,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.onPrimary,
                ),
                titleTextStyle: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              ),
            ),
          ),
        ),
        
        // Tasks for selected day
        Expanded(
          child: _selectedDay != null
              ? _buildTasksForSelectedDay(theme)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Selecciona un día para ver las tareas',
                        style: TextStyle(
                          fontFamily: fontFamilyPrimary,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // Build tasks for selected day
  Widget _buildTasksForSelectedDay(ThemeData theme) {
    final tasksForDay = _getTasksForDay(_selectedDay!);
    
    if (tasksForDay.isEmpty) {
      return Center(
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
              'No hay tareas para este día',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMMM yyyy').format(_selectedDay!),
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Tareas para ${DateFormat('dd MMMM yyyy').format(_selectedDay!)} (${tasksForDay.length})',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tasksForDay.length,
            itemBuilder: (context, index) {
              final taskInfo = tasksForDay[index];
              final taskDoc = taskInfo['taskDoc'] as QueryDocumentSnapshot;
              final taskData = taskInfo['taskData'] as Map<String, dynamic>;
              
              return _buildTaskCard(theme, taskDoc, taskData);
            },
          ),
        ),
      ],
    );
  }

  // Build list view (original)
  Widget _buildListView(ThemeData theme, List<QueryDocumentSnapshot> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final taskDoc = tasks[index];
        final taskData = taskDoc.data() as Map<String, dynamic>;
        
        return _buildTaskCard(theme, taskDoc, taskData);
      },
    );
  }

  // Build individual task card (extracted for reuse)
  Widget _buildTaskCard(ThemeData theme, QueryDocumentSnapshot taskDoc, Map<String, dynamic> taskData) {
    final String taskTitle = taskData['title'] ?? 'Tarea sin título';
    final String communityId = taskData['communityId'] as String? ?? 'unknown';
    final String communityName = taskData['communityName'] as String? ?? 'Comunidad Desconocida';
    final String taskId = taskDoc.id;

    // ✅ USAR FUNCIÓN COMPARTIDA DE TaskUtils
    final task_utils.TaskState taskState = task_utils.TaskUtils.parseTaskState(taskData['state'] as String?);

    // ✅ USAR FUNCIÓN COMPARTIDA DE TaskUtils PARA PRIORIDAD
    final task_utils.TaskPriority taskPriority = task_utils.TaskUtils.parseTaskPriority(taskData['priority'] as String?);

    final Timestamp? dueDateTimestamp = taskData['dueDate'] as Timestamp?;
    final String? description = taskData['description'];

    return Card(
      color: theme.colorScheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(
                communityId: communityId,
                taskId: taskId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y prioridad
              Row(
                children: [
                  Expanded(
                    child: Text(
                      taskTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: taskPriority.getColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: taskPriority.getColor().withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          taskPriority.getIcon(),
                          size: 12,
                          color: taskPriority.getColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          taskPriority.name, // ✅ USAR NOMBRE DEL ENUM
                          style: TextStyle(
                            fontFamily: fontFamilyPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: taskPriority.getColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Nombre de la comunidad
              Row(
                children: [
                  Icon(
                    Icons.group,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      communityName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Descripción si existe
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Estado y fecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: taskState.getColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: taskState.getColor(context).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      taskState.displayName, // ✅ USAR NOMBRE DEL ENUM
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        fontSize: 12,
                        color: taskState.getColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (dueDateTimestamp != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(dueDateTimestamp.toDate()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
