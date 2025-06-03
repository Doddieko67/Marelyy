import 'package:flutter/material.dart';

class AllAlertWidget extends StatelessWidget {
  final String text;
  const AllAlertWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alerta'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ok'),
        ),
      ],
    );
  }
}
