// lib/widgets/task_detail/dialogs/change_status_dialog.dart
import 'package:classroom_mejorado/features/tasks/services/task_service.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart';
import 'package:flutter/material.dart';

class ChangeStatusDialog extends StatefulWidget {
  final String communityId;
  final String taskId;
  final TaskState currentTaskState;
  final bool canComplete; // Permiso para marcar como 'done'
  final bool hasFiles; // Si la tarea tiene archivos subidos

  const ChangeStatusDialog({
    super.key,
    required this.communityId,
    required this.taskId,
    required this.currentTaskState,
    required this.canComplete,
    required this.hasFiles,
  });

  @override
  _ChangeStatusDialogState createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<ChangeStatusDialog> {
  late int _selectedStateIndex;
  late PageController _pageController;
  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _selectedStateIndex = TaskState.values.indexOf(
      widget.currentTaskState,
    );
    _pageController = PageController(initialPage: _selectedStateIndex);
  }

  // ... (código de _getStateColor y _getStateIcon y _getStateDisplayName que también necesita este widget)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedState = TaskState.values[_selectedStateIndex];

    String? validationMessage;
    bool canApplyState = true;

    // Lógica de validación
    if (selectedState == TaskState.underReview && !widget.hasFiles) {
      canApplyState = false;
      validationMessage = 'Debes subir un archivo para activar "Por Revisar"';
    } else if (selectedState == TaskState.done) {
      if (widget.currentTaskState != TaskState.underReview) {
        canApplyState = false;
        validationMessage = 'Debes pasar por "Por Revisar" antes de completar';
      } else if (!widget.canComplete) {
        canApplyState = false;
        validationMessage =
            'No tienes permiso para marcar esta tarea como completada';
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      title: Text(
        'Cambiar Estado',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 300,
        height: 350,
        child: Column(
          children: [
            // El carrusel de estados (PageView)
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _selectedStateIndex = index),
                itemCount: TaskState.values.length,
                itemBuilder: (context, index) {
                  // Lógica para construir cada tarjeta del PageView...
                  // (Este es el mismo código que tenías dentro del AlertDialog original)
                  // ...
                  return Center(
                    child: Text(TaskState.values[index].name),
                  );
                },
              ),
            ),
            const Spacer(),
            if (validationMessage != null)
              Text(validationMessage, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: canApplyState && selectedState != widget.currentTaskState
              ? () {
                  _taskService
                      .updateTaskStatus(
                        widget.communityId,
                        widget.taskId,
                        selectedState,
                      )
                      .then((_) {
                        Navigator.pop(
                          context,
                          true,
                        ); // Devuelve true para indicar éxito
                      });
                }
              : null,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
