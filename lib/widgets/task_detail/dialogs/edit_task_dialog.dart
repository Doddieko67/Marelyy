// lib/widgets/task_detail/dialogs/edit_task_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// Importa tus otros archivos necesarios aquí...

class EditTaskDialog extends StatefulWidget {
  final String communityId;
  final String taskId;
  final Map<String, dynamic> initialData;

  const EditTaskDialog({
    super.key,
    required this.communityId,
    required this.taskId,
    required this.initialData,
  });

  @override
  _EditTaskDialogState createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  // ... todos los otros estados de edición que tenías
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData['title']);
    _descriptionController = TextEditingController(
      text: widget.initialData['description'],
    );
    // ... inicializa el resto de los estados
  }

  void _saveChanges() {
    setState(() => _isLoading = true);

    Map<String, dynamic> updateData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      // ... el resto de los datos a actualizar
    };

    FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('tasks')
        .doc(widget.taskId)
        .update(updateData)
        .then((_) {
          if (mounted) {
            Navigator.pop(
              context,
              true,
            ); // Devuelve true para indicar que se debe recargar
          }
        })
        .catchError((e) {
          // Manejar error
        })
        .whenComplete(() {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Tarea'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 4,
            ),
            // ... Todos tus otros campos de edición (prioridad, fecha, asignado a)
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
