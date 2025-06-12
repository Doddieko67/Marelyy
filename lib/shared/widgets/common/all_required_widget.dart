import 'package:flutter/material.dart';

class AllRequiredWidget extends StatelessWidget {
  const AllRequiredWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Campos Requeridos'),
      content: const Text('Por favor, complete todos los campos.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ok'),
        ),
      ],
    );
  }
}
