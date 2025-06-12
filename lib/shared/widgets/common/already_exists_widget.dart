import 'package:flutter/material.dart';

class AlreadyExistsWidget extends StatelessWidget {
  const AlreadyExistsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Usuario Existente'),
      content: const Text('Ya existe una cuenta con este correo electrónico.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ok'),
        ),
      ],
    );
  }
}
