// lib/Screen/NewTaskScreen.dart - REFACTORIZADO CON TaskUtils
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';
import 'package:classroom_mejorado/utils/tasks_utils.dart'; // ✅ IMPORT FUNCIONES COMPARTIDAS

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
  TaskPriority _selectedPriority =
      TaskPriority.medium; // ✅ USAR ENUM DE TaskUtils

  // --- VARIABLES DE ESTADO PARA LA ASIGNACIÓN ---
  String? _assignedToId;
  String? _assignedToName;
  String? _assignedToImageUrl;
  List<Map<String, dynamic>> _communityMembers = [];
  bool _fetchingMembers = true;
  bool _membersDataReady = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCommunityMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCommunityMembers() async {
    setState(() {
      _fetchingMembers = true;
      _membersDataReady = false;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('Usuario no autenticado.');
      if (mounted) {
        setState(() {
          _fetchingMembers = false;
          _membersDataReady = false;
        });
      }
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
        if (mounted) {
          setState(() {
            _fetchingMembers = false;
            _membersDataReady = false;
          });
        }
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
            'displayName':
                userData?['name'] ??
                userData?['displayName'] ??
                'Usuario Desconocido',
            'photoURL': userData?['photoURL'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _communityMembers = membersData;
          _fetchingMembers = false;

          if (_communityMembers.isNotEmpty) {
            // Buscar al usuario actual en la lista
            final currentMemberData = _communityMembers.firstWhereOrNull(
              (member) => member['uid'] == currentUser.uid,
            );

            if (currentMemberData != null) {
              _assignedToId = currentMemberData['uid'] as String;
              _assignedToName = currentMemberData['displayName'] as String;
              _assignedToImageUrl = currentMemberData['photoURL'] as String?;
              print('✅ Tarea asignada al usuario actual: $_assignedToName');
            } else {
              final firstMember = _communityMembers.first;
              _assignedToId = firstMember['uid'] as String;
              _assignedToName = firstMember['displayName'] as String;
              _assignedToImageUrl = firstMember['photoURL'] as String?;
              print(
                '⚠️ Usuario actual no encontrado. Asignando a: $_assignedToName',
              );
            }

            _membersDataReady =
                _assignedToId != null && _assignedToName != null;
            print(
              '✅ Datos de miembros listos. Asignado a: $_assignedToName (ID: $_assignedToId)',
            );
          } else {
            _assignedToId = null;
            _assignedToName = null;
            _assignedToImageUrl = null;
            _membersDataReady = false;
            print('⚠️ No hay miembros en la comunidad');
          }
        });
      }
    } catch (e) {
      print('❌ Error al cargar miembros: $e');
      _showError('Error al cargar miembros de la comunidad: $e');
      if (mounted) {
        setState(() {
          _fetchingMembers = false;
          _membersDataReady = false;
        });
      }
    }
  }

  bool _validateAssignment() {
    if (!_membersDataReady) {
      _showError('Espera a que se carguen los miembros de la comunidad');
      return false;
    }

    if (_assignedToId == null || _assignedToName == null) {
      _showError('Debes asignar la tarea a un miembro');
      return false;
    }

    return true;
  }

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

    if (!_validateAssignment()) return;

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

      print('📝 Creando tarea con:');
      print('   - Título: ${_titleController.text.trim()}');
      print('   - Asignado a: $_assignedToName (ID: $_assignedToId)');
      print('   - Prioridad: ${_selectedPriority.name}');
      print(
        '   - Estado: ${TaskState.toDo.name.toLowerCase()}',
      ); // ✅ USAR ENUM DE TaskUtils

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .add({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'state': TaskState.toDo.name
                .toLowerCase(), // ✅ USAR ENUM DE TaskUtils
            'priority': _selectedPriority.name, // ✅ USAR ENUM DE TaskUtils
            'assignedToId': _assignedToId!,
            'assignedToName': _assignedToName!,
            'assignedToUser': _assignedToName!,
            'assignedToImageUrl': _assignedToImageUrl,
            'createdAtId': user.uid,
            'createdAtName': user.displayName ?? 'Usuario',
            'createdAtImageUrl': user.photoURL,
            'dueDate': _selectedDueDate != null
                ? Timestamp.fromDate(_selectedDueDate!)
                : null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'communityId': widget.communityId,
            'communityName': communityName,
          });

      print('✅ Tarea creada exitosamente y asignada a $_assignedToName');
      print('✅ Estado guardado como: ${TaskState.toDo.name.toLowerCase()}');
      _showSuccess('¡Tarea creada y asignada a $_assignedToName!');
      Navigator.of(context).pop();
    } catch (e) {
      print('❌ Error al crear tarea: $e');
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
            onPressed: (_isLoading || !_membersDataReady) ? null : _createTask,
            icon: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.check,
                    color: _membersDataReady
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
            label: Text(
              _isLoading
                  ? 'Creando...'
                  : _membersDataReady
                  ? 'Crear'
                  : 'Cargando...',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
                color: _membersDataReady
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
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

              // Asignar a
              Text(
                'Asignar a',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 12),

              if (_fetchingMembers)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Cargando miembros de la comunidad...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_communityMembers.isEmpty)
                Container(
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
              else
                Container(
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
                          final selectedMember = _communityMembers
                              .firstWhereOrNull(
                                (member) => member['uid'] == newValue,
                              );
                          if (selectedMember != null) {
                            _assignedToName =
                                selectedMember['displayName'] as String;
                            _assignedToImageUrl =
                                selectedMember['photoURL'] as String?;
                            print('✅ Tarea reasignada a: $_assignedToName');
                          } else {
                            _assignedToName = null;
                            _assignedToImageUrl = null;
                            print('⚠️ Asignación limpiada');
                          }
                        });
                      },
                      items: _communityMembers.map<DropdownMenuItem<String>>((
                        member,
                      ) {
                        return DropdownMenuItem<String>(
                          value: member['uid'] as String,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: member['photoURL'] != null
                                    ? NetworkImage(member['photoURL'] as String)
                                    : null,
                                child: member['photoURL'] == null
                                    ? Icon(
                                        Icons.person,
                                        color: theme.colorScheme.onPrimary,
                                      )
                                    : null,
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                member['displayName'] as String,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Selector de prioridad
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
                    // ✅ USAR ENUM DE TaskUtils
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

              // Botón crear tarea
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_membersDataReady)
                      ? null
                      : _createTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _membersDataReady
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.3),
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
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
                              _membersDataReady
                                  ? 'Crear Tarea'
                                  : 'Cargando datos...',
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

              // ✅ DEBUG: Usar función compartida de TaskUtils (TEMPORAL)
            ],
          ),
        ),
      ),
    );
  }
}

// Extensión auxiliar
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
