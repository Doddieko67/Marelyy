// lib/Screen/NewTaskScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';

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

class NewTaskScreen extends StatefulWidget {
  final String communityId;

  const NewTaskScreen({super.key, required this.communityId});

  @override
  State<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends State<NewTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDueDate;
  TaskPriority _selectedPriority = TaskPriority.medium;

  // --- NUEVAS VARIABLES DE ESTADO PARA LA ASIGNACIÓN ---
  String? _assignedToId; // UID del usuario asignado
  String? _assignedToName; // Nombre del usuario asignado
  String? _assignedToImageUrl; // URL de la foto del usuario asignado
  List<Map<String, dynamic>> _communityMembers =
      []; // Lista de miembros para el dropdown
  bool _fetchingMembers =
      true; // Estado para indicar si se están cargando los miembros
  // --- FIN NUEVAS VARIABLES ---

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCommunityMembers(); // Llamar a la función para cargar miembros
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- NUEVA FUNCIÓN: Obtener miembros de la comunidad ---
  Future<void> _fetchCommunityMembers() async {
    setState(() {
      _fetchingMembers = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('Usuario no autenticado.');
      if (mounted) setState(() => _fetchingMembers = false);
      return;
    }

    try {
      // 1. Obtener los UIDs de los miembros de la comunidad
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (!communityDoc.exists) {
        _showError('Comunidad no encontrada.');
        if (mounted) setState(() => _fetchingMembers = false);
        return;
      }

      final List<dynamic> memberUids = communityDoc.get('members') ?? [];
      List<Map<String, dynamic>> membersData = [];

      // 2. Para cada UID, obtener la información del perfil del usuario
      for (String uid in memberUids) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          membersData.add({
            'uid': uid,
            'displayName': userData?['name'] ?? 'Usuario Desconocido',
            'photoURL': userData?['photoURL'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _communityMembers = membersData;
          _fetchingMembers = false;

          // Asignar al usuario actual por defecto si es miembro de la comunidad
          final currentMemberData = _communityMembers.firstWhereOrNull(
            (member) => member['uid'] == currentUser.uid,
          );

          if (currentMemberData != null) {
            _assignedToId = currentMemberData['uid'] as String;
            _assignedToName = currentMemberData['displayName'] as String;
            _assignedToImageUrl = currentMemberData['photoURL'] as String?;
          } else if (_communityMembers.isNotEmpty) {
            // Si el usuario actual no está en la lista (raro si está creando la tarea),
            // se asigna al primer miembro disponible
            _assignedToId = _communityMembers.first['uid'] as String;
            _assignedToName = _communityMembers.first['displayName'] as String;
            _assignedToImageUrl =
                _communityMembers.first['photoURL'] as String?;
          } else {
            // Si no hay miembros, dejar en null (o asignar a "nadie")
            _assignedToId = null;
            _assignedToName = 'Nadie';
            _assignedToImageUrl = null;
          }
        });
      }
    } catch (e) {
      _showError('Error al cargar miembros de la comunidad: $e');
      if (mounted) setState(() => _fetchingMembers = false);
    }
  }

  // --- Función auxiliar para firstWhereOrNull (si no la tienes en tus extensiones) ---
  // Puedes agregarla como una extensión de List o una función global si no usas paquete como collection
  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (T element in list) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
  // Uso: _communityMembers.firstWhereOrNull( (member) => member['uid'] == currentUser.uid);
  // Reemplazar '_communityMembers.firstWhereOrNull' con '_firstWhereOrNull(_communityMembers, ...)' si no tienes la extensión.
  // O añadir la extensión:
  // extension ListExtension<T> on List<T> {
  //   T? firstWhereOrNull(bool Function(T) test) {
  //     for (T element in this) {
  //       if (test(element)) {
  //         return element;
  //       }
  //     }
  //     return null;
  //   }
  // }

  Future<void> _selectDueDate() async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Puedes agregar una validación para _assignedToId si la asignación es obligatoria
    // if (_assignedToId == null) {
    //   _showError('Debes asignar la tarea a un miembro.');
    //   return;
    // }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Debes estar autenticado para crear tareas');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final communitySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();
      final communityName = communitySnapshot.exists
          ? (communitySnapshot.get('name') as String? ??
                'Comunidad Desconocida')
          : 'Comunidad Desconocida';
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .add({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'state': 'por hacer', // Estado inicial
            'priority': _selectedPriority.name,
            'assignedToId': _assignedToId, // <<< ASIGNADO: ID
            'assignedToUser': _assignedToName, // <<< ASIGNADO: Nombre
            'assignedToImageUrl':
                _assignedToImageUrl, // <<< ASIGNADO: URL de imagen
            'createdAtId': user.uid, // Quien crea la tarea
            'createdAtName':
                user.displayName ?? 'Usuario', // Nombre de quien crea
            'createdAtImageUrl': user.photoURL, // Foto de quien crea
            'dueDate': _selectedDueDate != null
                ? Timestamp.fromDate(_selectedDueDate!)
                : null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'communityId': widget.communityId, // <-- ¡AÑADE ESTA LÍNEA!
            'communityName': communityName, // <-- ¡AÑADE ESTA LÍNEA!
          });

      _showSuccess('¡Tarea creada exitosamente!');
      Navigator.of(context).pop();
    } catch (e) {
      _showError('Error al crear la tarea: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green[600]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Nueva Tarea',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _createTask,
            icon: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(Icons.check, color: theme.colorScheme.primary),
            label: Text(
              _isLoading ? 'Creando...' : 'Crear',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título de la tarea
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _titleController,
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Título de la tarea',
                    labelStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    hintText: 'Ingresa un título descriptivo...',
                    hintStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.title,
                      color: theme.colorScheme.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El título es obligatorio';
                    }
                    if (value.trim().length < 3) {
                      return 'El título debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                  maxLength: 100,
                ),
              ),

              const SizedBox(height: 24),

              // Descripción de la tarea
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    labelStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    hintText: 'Agrega detalles sobre la tarea...',
                    hintStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.description,
                      color: theme.colorScheme.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
              ),

              const SizedBox(height: 24),

              // Fecha de vencimiento
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: InkWell(
                  onTap: _selectDueDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha de vencimiento',
                                style: TextStyle(
                                  fontFamily: fontFamilyPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedDueDate != null
                                    ? DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_selectedDueDate!)
                                    : 'Sin fecha límite',
                                style: TextStyle(
                                  fontFamily: fontFamilyPrimary,
                                  fontSize: 14,
                                  color: _selectedDueDate != null
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withOpacity(
                                          0.5,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedDueDate != null)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedDueDate = null;
                              });
                            },
                            icon: Icon(
                              Icons.clear,
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- NUEVA SECCIÓN: Asignar a ---
              Text(
                'Asignar a',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 12),
              _fetchingMembers // Mostrar indicador de carga o el selector
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : _communityMembers.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        'No hay otros miembros en esta comunidad para asignar.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _assignedToId,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: theme.colorScheme.primary,
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _assignedToId = newValue;
                              // Encontrar el miembro seleccionado para actualizar nombre e imagen
                              final selectedMember = _firstWhereOrNull(
                                _communityMembers,
                                (member) => member['uid'] == newValue,
                              );
                              if (selectedMember != null) {
                                _assignedToName =
                                    selectedMember['displayName'] as String;
                                _assignedToImageUrl =
                                    selectedMember['photoURL'] as String?;
                              } else {
                                // Esto no debería pasar si newValue siempre es un UID válido de la lista
                                _assignedToName = null;
                                _assignedToImageUrl = null;
                              }
                            });
                          },
                          items: _communityMembers
                              .map<DropdownMenuItem<String>>((member) {
                                return DropdownMenuItem<String>(
                                  value: member['uid'] as String,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            member['photoURL'] != null
                                            ? NetworkImage(
                                                member['photoURL'] as String,
                                              )
                                            : null,
                                        child: member['photoURL'] == null
                                            ? Icon(
                                                Icons.person,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              )
                                            : null,
                                        backgroundColor: theme
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.2),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        member['displayName'] as String,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontFamily: fontFamilyPrimary,
                                              color:
                                                  theme.colorScheme.onSurface,
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

              // --- FIN NUEVA SECCIÓN ---
              const SizedBox(
                height: 24,
              ), // Espacio antes del selector de prioridad
              // Selector de prioridad (movido abajo para mejor flujo de UI)
              Text(
                'Prioridad',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: TaskPriority.values.map((priority) {
                    final isSelected = _selectedPriority == priority;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedPriority = priority;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? priority.getColor().withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: priority.getColor().withOpacity(
                                  isSelected ? 1 : 0.2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                priority.getIcon(),
                                color: isSelected
                                    ? Colors.white
                                    : priority.getColor(),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                priority.name,
                                style: TextStyle(
                                  fontFamily: fontFamilyPrimary,
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? priority.getColor()
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: priority.getColor(),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),

              // Botón de crear
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: theme.colorScheme.outline
                        .withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Creando tarea...',
                              style: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_task, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Crear Tarea',
                              style: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Puedes añadir esta extensión si no usas algún paquete que ya la provea (como collection)
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
