import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/tasks/providers/task_provider.dart';
import 'package:classroom_mejorado/shared/widgets/common/task_card.dart';
import 'package:classroom_mejorado/shared/widgets/common/loading_widget.dart';
import 'package:classroom_mejorado/shared/widgets/common/section_header.dart';
import 'package:classroom_mejorado/features/tasks/screens/task_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class RefactoredCommunityCalendarTabContent extends StatefulWidget {
  final String communityId;

  const RefactoredCommunityCalendarTabContent({super.key, required this.communityId});

  @override
  State<RefactoredCommunityCalendarTabContent> createState() =>
      _RefactoredCommunityCalendarTabContentState();
}

class _RefactoredCommunityCalendarTabContentState
    extends State<RefactoredCommunityCalendarTabContent> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadCalendarTasks(widget.communityId);
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildCalendarMarker(BuildContext context, DateTime day, List<dynamic> events) {
    if (events.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final taskProvider = context.read<TaskProvider>();
    final tasks = taskProvider.getTasksForDay(day);
    
    if (tasks.isEmpty) return const SizedBox.shrink();
    
    // Contar tareas por estado
    int completedTasks = tasks.where((task) => task.status.name == 'done').length;
    int overdueTasks = tasks.where((task) => task.isOverdue && task.status.name != 'done').length;
    
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
          child: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          if (taskProvider.isLoading) {
            return const LoadingWidget(message: 'Cargando calendario...');
          }

          if (taskProvider.error != null) {
            return ErrorWidget(
              message: taskProvider.error!,
              onRetry: () => taskProvider.loadCalendarTasks(widget.communityId),
            );
          }

          final selectedDayTasks = taskProvider.getTasksForDay(_selectedDay);

          return Column(
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
                child: TableCalendar<dynamic>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  eventLoader: (day) => taskProvider.getTasksForDay(day),
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
                      return _buildCalendarMarker(context, day, events);
                    },
                  ),
                  
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
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
                child: SectionHeader(
                  title: _isToday(_selectedDay) 
                      ? 'Tareas de hoy (${selectedDayTasks.length})'
                      : 'Tareas del ${DateFormat('dd/MM/yyyy').format(_selectedDay)} (${selectedDayTasks.length})',
                  icon: Icons.event_note,
                ),
              ),
              
              // Lista de tareas del día seleccionado
              Expanded(
                child: selectedDayTasks.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.event_available,
                        title: _isToday(_selectedDay) 
                            ? 'No hay tareas para hoy'
                            : 'No hay tareas para este día',
                        subtitle: 'Las tareas con fechas de entrega aparecerán aquí',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: selectedDayTasks.length,
                        itemBuilder: (context, index) {
                          final task = selectedDayTasks[index];
                          return TaskCard(
                            task: task,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => TaskDetailScreen(
                                    taskId: task.id,
                                    communityId: widget.communityId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              return FloatingActionButton(
                onPressed: () => taskProvider.loadCalendarTasks(widget.communityId),
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.refresh,
                  color: theme.colorScheme.onPrimary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}