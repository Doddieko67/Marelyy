// lib/screen/TaskDetailScreen.dart - CORREGIDO COMPLETAMENTE
import 'package:cached_network_image/cached_network_image.dart';
import 'package:classroom_mejorado/Screen/CommunityTasksTabContent.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';

// REPETICIÓN DE ENUMS Y EXTENSIONES PARA COMODIDAD (idealmente estarían en un archivo compartido)
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

class TaskDetailScreen extends StatefulWidget {
  final String communityId;
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.communityId,
    required this.taskId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editDescriptionController =
      TextEditingController();

  final FocusNode _commentFocusNode = FocusNode();
  late Future<DocumentSnapshot> _taskFuture;
  late AnimationController _addCommentAnimationController;
  late Animation<double> _addCommentAnimation;

  // ✅ ESTADOS CORREGIDOS
  bool _isAddingComment = false;
  bool _isEditingTask = false;
  bool _isDeletingTask = false;

  // Variables para edición de la tarea
  String _editPriority = 'Media'; // Valor por defecto
  DateTime? _editDueDate;

  // Variables de estado para la asignación en edición
  String? _editAssignedToId;
  String? _editAssignedToName;
  String? _editAssignedToImageUrl;
  List<Map<String, dynamic>> _editCommunityMembers = [];
  bool _fetchingEditMembers = true;

  @override
  void initState() {
    super.initState();
    _taskFuture = _fetchTaskDetails();

    _addCommentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _addCommentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _addCommentAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editTitleController.dispose();
    _editDescriptionController.dispose();
    _commentFocusNode.dispose();
    _addCommentAnimationController.dispose();
    super.dispose();
  }

  // ✅ FUNCIÓN: Normalizar prioridad para ser case-insensitive
  String _normalizePriority(String? priority) {
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
        return 'Media'; // Fallback seguro
    }
  }

  Future<DocumentSnapshot> _fetchTaskDetails() async {
    return await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('tasks')
        .doc(widget.taskId)
        .get();
  }

  // Función para cargar miembros en el diálogo de edición.
  Future<void> _fetchCommunityMembersForEdit(
    Function(void Function()) setModalState,
  ) async {
    setModalState(() {
      _fetchingEditMembers = true;
      _editCommunityMembers = []; // Limpiar antes de cargar
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Usuario no autenticado.', isError: true);
      setModalState(() => _fetchingEditMembers = false);
      return;
    }

    try {
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (!communityDoc.exists) {
        _showSnackBar('Comunidad no encontrada.', isError: true);
        setModalState(() => _fetchingEditMembers = false);
        return;
      }

      final List<String> memberUids = List<String>.from(
        communityDoc.get('members') ?? [],
      );
      List<Map<String, dynamic>> membersData = [];

      if (memberUids.isNotEmpty) {
        // Obtenemos los perfiles de usuario de la colección 'users'
        final QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: memberUids)
            .get();

        for (var doc in userQuery.docs) {
          if (doc.exists) {
            final userData = doc.data() as Map<String, dynamic>;
            membersData.add({
              'uid': doc.id,
              'displayName':
                  userData['name'] ??
                  userData['displayName'] ??
                  'Usuario Desconocido',
              'photoURL': userData['photoURL'],
            });
          }
        }
      }

      setModalState(() {
        _editCommunityMembers = membersData;
        _fetchingEditMembers = false;

        if (_editAssignedToId != null &&
            _editCommunityMembers.any(
              (member) => member['uid'] == _editAssignedToId,
            )) {
          // Si el ID asignado ya existe en la lista, no cambiar nada
        } else if (currentUser.uid != null &&
            _editCommunityMembers.any(
              (member) => member['uid'] == currentUser.uid,
            )) {
          // Si el usuario actual está en la lista y no había asignado, asignarlo por defecto
          final currentMemberData = _editCommunityMembers.firstWhereOrNull(
            (member) => member['uid'] == currentUser.uid,
          );
          _editAssignedToId = currentMemberData?['uid'] as String?;
          _editAssignedToName = currentMemberData?['displayName'] as String?;
          _editAssignedToImageUrl = currentMemberData?['photoURL'] as String?;
        } else if (_editCommunityMembers.isNotEmpty) {
          // Si no hay asignado y el usuario actual no es un miembro, asignar al primer miembro de la lista
          _editAssignedToId = _editCommunityMembers.first['uid'] as String;
          _editAssignedToName =
              _editCommunityMembers.first['displayName'] as String;
          _editAssignedToImageUrl =
              _editCommunityMembers.first['photoURL'] as String?;
        } else {
          // Si no hay miembros en la comunidad
          _editAssignedToId = null;
          _editAssignedToName = 'Nadie';
          _editAssignedToImageUrl = null;
        }
      });
    } catch (e) {
      _showSnackBar(
        'Error al cargar miembros de la comunidad: $e',
        isError: true,
      );
      setModalState(() => _fetchingEditMembers = false);
    }
  }

  // ✅ FUNCIÓN: Mostrar diálogo de confirmación para eliminar tarea
  void _showDeleteTaskDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Eliminar Tarea',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que quieres eliminar esta tarea?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción no se puede deshacer. Se eliminarán todos los comentarios asociados.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isDeletingTask
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _deleteTask();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isDeletingTask
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Eliminar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ✅ FUNCIÓN: Eliminar tarea de Firestore
  void _deleteTask() async {
    setState(() {
      _isDeletingTask = true;
    });

    try {
      final taskRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId);

      // Primero, eliminar todos los comentarios
      final commentsSnapshot = await taskRef.collection('comments').get();

      // Eliminar comentarios en lotes para mejor rendimiento
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (QueryDocumentSnapshot commentDoc in commentsSnapshot.docs) {
        batch.delete(commentDoc.reference);
      }

      // Eliminar la tarea principal
      batch.delete(taskRef);

      // Ejecutar todas las eliminaciones
      await batch.commit();

      if (mounted) {
        _showSnackBar('✓ Tarea eliminada correctamente', isError: false);

        // Navegar de vuelta con un pequeño delay para mostrar el mensaje
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(
              context,
            ).pop(true); // Retornar true para indicar que se eliminó
          }
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error deleting task: $e');
        _showSnackBar('Error al eliminar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingTask = false;
        });
      }
    }
  }

  void _showChangeStatusDialog(TaskState currentTaskState) {
    final theme = Theme.of(context);
    int selectedStateIndex = TaskState.values.indexOf(currentTaskState);
    PageController pageController = PageController(
      initialPage: selectedStateIndex,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInsideDialog) {
            TaskState selectedState = TaskState.values[selectedStateIndex];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.all(24),
              title: Text(
                'Cambiar Estado',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: 300,
                height: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),

                    // Carrusel de estados
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        controller: pageController,
                        onPageChanged: (index) {
                          setStateInsideDialog(() {
                            selectedStateIndex = index;
                          });
                        },
                        itemCount: TaskState.values.length,
                        itemBuilder: (context, index) {
                          TaskState state = TaskState.values[index];
                          bool isSelected = index == selectedStateIndex;
                          Color stateColor = _getStateColor(state, theme);
                          IconData stateIcon = _getStateIcon(state);

                          return Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: isSelected ? 8 : 16,
                              vertical: isSelected ? 8 : 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  stateColor.withOpacity(
                                    isSelected ? 0.2 : 0.1,
                                  ),
                                  stateColor.withOpacity(
                                    isSelected ? 0.1 : 0.05,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: stateColor.withOpacity(
                                  isSelected ? 0.6 : 0.3,
                                ),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: stateColor.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: isSelected ? 60 : 50,
                                  height: isSelected ? 60 : 50,
                                  decoration: BoxDecoration(
                                    color: stateColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: stateColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    stateIcon,
                                    color: Colors.white,
                                    size: isSelected ? 30 : 25,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _getStateDisplayName(state),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: fontFamilyPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: stateColor,
                                    fontSize: isSelected ? 18 : 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Indicadores de página
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        TaskState.values.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: selectedStateIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selectedStateIndex == index
                                ? _getStateColor(TaskState.values[index], theme)
                                : theme.colorScheme.outline.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Instrucciones
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swipe,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Desliza para cambiar',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () {
                          _updateTaskState(
                            TaskState.values[selectedStateIndex],
                          );
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getStateColor(selectedState, theme),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Aplicar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getStateIcon(TaskState state) {
    switch (state) {
      case TaskState.toDo:
        return Icons.radio_button_unchecked;
      case TaskState.doing:
        return Icons.hourglass_empty;
      case TaskState.done:
        return Icons.check_circle;
      default:
        return Icons.circle;
    }
  }

  Color _getStateColor(TaskState state, ThemeData theme) {
    switch (state) {
      case TaskState.toDo:
        return Colors.grey.shade600;
      case TaskState.doing:
        return Colors.blue.shade600;
      case TaskState.done:
        return Colors.green.shade600;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _getStateDisplayName(TaskState state) {
    switch (state) {
      case TaskState.toDo:
        return 'Por Hacer';
      case TaskState.doing:
        return 'En Progreso';
      case TaskState.done:
        return 'Completado';
      default:
        return state.name;
    }
  }

  void _updateTaskState(TaskState newState) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .update({'state': newState.name.toLowerCase()});

      if (mounted) {
        _showSnackBar(
          '✓ Estado actualizado a ${_getStateDisplayName(newState)}',
          isError: false,
        );
        setState(() {
          _taskFuture = _fetchTaskDetails(); // Refrescar los detalles
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error updating task state: $e');
        _showSnackBar('Error al actualizar: $e', isError: true);
      }
    }
  }

  void _showAddCommentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Agregar Comentario',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _commentController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Escribe tu comentario aquí...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _commentController.clear();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        _addComment();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Publicar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showSnackBar('El comentario no puede estar vacío', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para comentar', isError: true);
      return;
    }

    setState(() {
      _isAddingComment = true;
    });

    try {
      // Obtener el nombre y la foto del creador desde Firestore
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String senderName =
          user.displayName ?? user.email?.split('@')[0] ?? 'Anónimo';
      String? senderPhotoUrl = user.photoURL;

      if (creatorDoc.exists) {
        final creatorData = creatorDoc.data() as Map<String, dynamic>;
        senderName =
            creatorData['name'] ?? creatorData['displayName'] ?? senderName;
        senderPhotoUrl = creatorData['photoURL'] ?? senderPhotoUrl;
      }

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('comments')
          .add({
            'text': _commentController.text.trim(),
            'senderId': user.uid,
            'senderName': senderName,
            'senderImageUrl': senderPhotoUrl,
            'timestamp': FieldValue.serverTimestamp(),
          });

      _commentController.clear();

      if (mounted) {
        _showSnackBar('✓ Comentario agregado', isError: false);
      }
    } catch (e) {
      if (mounted) {
        print('Error adding comment: $e');
        _showSnackBar('Error al agregar comentario: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingComment = false;
        });
      }
    }
  }

  void _showEditTaskDialog(Map<String, dynamic> taskData) {
    // Inicializar controladores y variables con datos actuales
    _editTitleController.text = taskData['title'] ?? '';
    _editDescriptionController.text = taskData['description'] ?? '';

    // Inicializar nuevas variables de asignación
    _editAssignedToId = taskData['assignedToId'] as String?;
    _editAssignedToName = taskData['assignedToName'] as String?;
    _editAssignedToImageUrl = taskData['assignedToImageUrl'] as String?;

    // ✅ CORREGIDO: Usar función de normalización para prioridad
    _editPriority = _normalizePriority(taskData['priority']);

    _editDueDate = taskData['dueDate'] != null
        ? (taskData['dueDate'] as Timestamp).toDate()
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Cargar miembros de la comunidad al abrir el diálogo
          if (_editCommunityMembers.isEmpty && _fetchingEditMembers) {
            _fetchCommunityMembersForEdit(setModalState);
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Handle bar y header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Editar Tarea',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Contenido scrolleable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Título
                        _buildEditField(
                          'Título',
                          _editTitleController,
                          'Título de la tarea',
                          icon: Icons.title,
                        ),
                        const SizedBox(height: 20),

                        // Descripción
                        _buildEditField(
                          'Descripción',
                          _editDescriptionController,
                          'Descripción de la tarea',
                          maxLines: 4,
                          icon: Icons.description,
                        ),
                        const SizedBox(height: 20),

                        // Sección: Asignar a (Dropdown)
                        Text(
                          'Asignar a',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontFamily: fontFamilyPrimary,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _fetchingEditMembers
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : _editCommunityMembers.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  'No hay miembros en esta comunidad para asignar.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontFamily: fontFamilyPrimary,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _editAssignedToId,
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    onChanged: (String? newValue) {
                                      setModalState(() {
                                        _editAssignedToId = newValue;
                                        final selectedMember =
                                            _editCommunityMembers
                                                .firstWhereOrNull(
                                                  (member) =>
                                                      member['uid'] == newValue,
                                                );
                                        if (selectedMember != null) {
                                          _editAssignedToName =
                                              selectedMember['displayName']
                                                  as String;
                                          _editAssignedToImageUrl =
                                              selectedMember['photoURL']
                                                  as String?;
                                        } else {
                                          _editAssignedToName = 'Nadie';
                                          _editAssignedToImageUrl = null;
                                        }
                                      });
                                    },
                                    items: _editCommunityMembers
                                        .map<DropdownMenuItem<String>>((
                                          member,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: member['uid'] as String,
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundImage:
                                                      member['photoURL'] !=
                                                              null &&
                                                          (member['photoURL']
                                                                  as String)
                                                              .isNotEmpty
                                                      ? NetworkImage(
                                                          member['photoURL']
                                                              as String,
                                                        )
                                                      : null,
                                                  child:
                                                      (member['photoURL'] ==
                                                              null ||
                                                          (member['photoURL']
                                                                  as String)
                                                              .isEmpty)
                                                      ? Icon(
                                                          Icons.person,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                        )
                                                      : null,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withOpacity(0.2),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  member['displayName']
                                                      as String,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        fontFamily:
                                                            fontFamilyPrimary,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 20),

                        // Prioridad
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Prioridad',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _editPriority, // ✅ Ya está normalizado
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  items: TaskPriority.values
                                      .map(
                                        (priority) => DropdownMenuItem(
                                          value: priority
                                              .name, // "Baja", "Media", etc.
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: priority.getColor(),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(priority.name),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setModalState(() {
                                      _editPriority = value ?? 'Media';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Fecha límite
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _editDueDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setModalState(() {
                                  _editDueDate = date;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Fecha límite',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontFamily: fontFamilyPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _editDueDate != null
                                              ? DateFormat(
                                                  'dd MMM yyyy',
                                                ).format(_editDueDate!)
                                              : 'Seleccionar fecha',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: _editDueDate != null
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.6),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_editDueDate != null)
                                    IconButton(
                                      onPressed: () {
                                        setModalState(() {
                                          _editDueDate = null;
                                        });
                                      },
                                      icon: const Icon(Icons.clear),
                                      iconSize: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Botones de acción
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isEditingTask
                              ? null
                              : () {
                                  _updateTask();
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isEditingTask
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Guardar',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Función mejorada para colores de prioridad
  Color _getPriorityColor(String priority) {
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

  // Función de actualización de tarea
  void _updateTask() async {
    if (_editTitleController.text.trim().isEmpty) {
      _showSnackBar('El título no puede estar vacío', isError: true);
      return;
    }

    setState(() {
      _isEditingTask = true;
    });

    try {
      Map<String, dynamic> updateData = {
        'title': _editTitleController.text.trim(),
        'description': _editDescriptionController.text.trim(),
        'priority': _editPriority, // ✅ Ya está normalizado
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Actualizar asignación con los nuevos campos
      updateData['assignedToId'] = _editAssignedToId;
      updateData['assignedToName'] = _editAssignedToName;
      updateData['assignedToImageUrl'] = _editAssignedToImageUrl;

      // Solo actualizar fecha si se selecciona una
      if (_editDueDate != null) {
        updateData['dueDate'] = Timestamp.fromDate(_editDueDate!);
      } else {
        // Si la fecha se borra, establecerla en null en Firestore
        updateData['dueDate'] = null;
      }

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .update(updateData);

      if (mounted) {
        _showSnackBar('✓ Tarea actualizada correctamente', isError: false);
        setState(() {
          _taskFuture =
              _fetchTaskDetails(); // Forzar recarga de los detalles de la tarea
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error updating task: $e');
        _showSnackBar('Error al actualizar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEditingTask = false;
        });
      }
    }
  }

  // Helper para SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDetailItem({
    required BuildContext context,
    IconData? icon,
    String? imageUrl,
    required String title,
    required String subtitle,
    Color? iconBgColor,
    Color? statusColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            )
          else if (icon != null)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    iconBgColor ?? theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: statusColor ?? theme.colorScheme.primary,
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(BuildContext context, DocumentSnapshot commentDoc) {
    final theme = Theme.of(context);
    final data = commentDoc.data() as Map<String, dynamic>;
    final String senderName = data['senderName'] ?? 'Anónimo';
    final String commentText = data['text'] ?? '';
    final String senderImageUrl = data['senderImageUrl'] ?? '';
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;

    String formattedTime = '';
    if (timestamp != null) {
      final now = DateTime.now();
      final commentDate = timestamp.toDate();
      final diff = now.difference(commentDate);

      if (diff.inDays > 0) {
        formattedTime = '${diff.inDays}d';
      } else if (diff.inHours > 0) {
        formattedTime = '${diff.inHours}h';
      } else if (diff.inMinutes > 0) {
        formattedTime = '${diff.inMinutes}m';
      } else {
        formattedTime = 'ahora';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: senderImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: senderImageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      senderName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onBackground.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
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
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot>(
          future: _taskFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando tarea...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar la tarea',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_outlined,
                      size: 64,
                      color: theme.colorScheme.onBackground.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tarea no encontrada',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            }

            final taskData = snapshot.data!.data() as Map<String, dynamic>;
            final String taskTitle = taskData['title'] ?? 'Sin Título';
            final String taskDescription =
                taskData['description'] ?? 'Sin descripción.';
            final TaskState taskState = TaskState.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  (taskData['state'] as String? ?? 'to_do').toLowerCase(),
              orElse: () => TaskState.toDo,
            );

            final String assignedToName =
                taskData['assignedToName'] ?? 'Sin asignar';
            final String? assignedToImageUrl =
                taskData['assignedToImageUrl'] as String?;
            final Timestamp? dueDateTimestamp =
                taskData['dueDate'] as Timestamp?;

            // ✅ USAR PRIORIDAD NORMALIZADA PARA MOSTRAR
            final String priority = _normalizePriority(taskData['priority']);

            String formattedDueDate = dueDateTimestamp != null
                ? DateFormat('dd MMM yyyy').format(dueDateTimestamp.toDate())
                : 'Sin fecha límite';

            return Column(
              children: <Widget>[
                // Header mejorado con menú
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surface.withOpacity(0.5),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: theme.colorScheme.onBackground,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Detalles de Tarea",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      ),
                      // ✅ MENÚ CORREGIDO
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surface.withOpacity(0.5),
                        ),
                        child: PopupMenuButton<String>(
                          onSelected: (String value) {
                            switch (value) {
                              case 'edit':
                                _showEditTaskDialog(taskData);
                                break;
                              case 'delete':
                                _showDeleteTaskDialog();
                                break;
                            }
                          },
                          icon: Icon(
                            Icons.more_vert,
                            color: theme.colorScheme.onBackground,
                            size: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: theme.colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Editar',
                                    style: TextStyle(
                                      fontFamily: fontFamilyPrimary,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: theme.colorScheme.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      fontFamily: fontFamilyPrimary,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // Tarjeta principal de la tarea
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withOpacity(
                                  0.1,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStateColor(
                                        taskState,
                                        theme,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _getStateColor(
                                              taskState,
                                              theme,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getStateDisplayName(taskState),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: fontFamilyPrimary,
                                                color: _getStateColor(
                                                  taskState,
                                                  theme,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                taskTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onBackground,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                taskDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  color: theme.colorScheme.onBackground
                                      .withOpacity(0.8),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de detalles
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            "Detalles",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildDetailItem(
                          context: context,
                          imageUrl: assignedToImageUrl,
                          title: assignedToName,
                          subtitle: "Asignado a",
                        ),
                        _buildDetailItem(
                          context: context,
                          icon: Icons.calendar_today_outlined,
                          title: formattedDueDate,
                          subtitle: "Fecha límite",
                        ),
                        _buildDetailItem(
                          context: context,
                          icon: Icons.flag_outlined,
                          title: priority, // ✅ Ya normalizado
                          subtitle: "Prioridad",
                          statusColor: _getPriorityColor(priority),
                        ),

                        const SizedBox(height: 24),

                        // Sección de comentarios
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Comentarios",
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onBackground,
                                ),
                              ),
                              IconButton(
                                onPressed: _showAddCommentDialog,
                                icon: Icon(
                                  Icons.add_comment_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('communities')
                              .doc(widget.communityId)
                              .collection('tasks')
                              .doc(widget.taskId)
                              .collection('comments')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'Error al cargar comentarios',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 48,
                                      color: theme.colorScheme.onBackground
                                          .withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Sin comentarios aún',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.7),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sé el primero en comentar',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final comments = snapshot.data!.docs;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                return _buildCommentItem(
                                  context,
                                  comments[index],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(
                          height: 90,
                        ), // Espacio para los botones flotantes
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // Botones flotantes
      floatingActionButton: FutureBuilder<DocumentSnapshot>(
        future: _taskFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final currentState = TaskState.values.firstWhere(
            (e) =>
                e.name.toLowerCase() ==
                (data['state'] as String? ?? 'to_do').toLowerCase(),
            orElse: () => TaskState.toDo,
          );

          return FloatingActionButton.extended(
            onPressed: () => _showChangeStatusDialog(currentState),
            backgroundColor: theme.colorScheme.primary.withOpacity(0.4),
            foregroundColor: theme.colorScheme.onPrimary,
            label: const Text('Cambiar Estado'),
            icon: const Icon(Icons.swap_horiz),
            heroTag: "change_status",
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// Extensión para firstWhereOrNull
extension _ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (T element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
