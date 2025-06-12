// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/shared/widgets/common/alert_widget.dart'; // Si usas tu widget de alerta animado
import 'package:classroom_mejorado/core/utils/animations.dart'; // Si usas tu clase de animaciones

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AppAnimations _appAnimations =
      AppAnimations(); // Instancia para tus diálogos

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        const AllAlertWidget(text: 'Por favor, ingresa tu correo electrónico.'),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      // Éxito: Notificar al usuario y opcionalmente volver a la pantalla de login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se ha enviado un correo electrónico para restablecer tu contraseña. Revisa tu bandeja de entrada.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Opcional: Navegar de regreso a la pantalla de inicio de sesión después de un breve retraso
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop();
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage =
            'No se encontró ningún usuario con ese correo electrónico.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico no es válido.';
      } else {
        errorMessage =
            'Error al enviar el correo de restablecimiento: ${e.message}';
      }
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        AllAlertWidget(text: errorMessage),
      );
    } catch (e) {
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        AllAlertWidget(text: 'Ocurrió un error inesperado: $e'),
      );
    }
  }

  // Widget auxiliar para el TextField
  Widget _buildTextField(
    String placeholder,
    double maxWidth, {
    TextEditingController? controller,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: fontFamilySecondary,
            ),
            decoration: InputDecoration(hintText: placeholder),
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para el botón primario
  Widget _buildPrimaryButton(
    String text,
    double maxWidth, {
    required VoidCallback onPressed,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(onPressed: onPressed, child: Text(text)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxContentWidth = screenWidth > 480 ? 480 : screenWidth - 32;

    return Scaffold(
      // backgroundColor: theme.colorScheme.background, // Ya definido en ThemeData
      appBar: AppBar(
        backgroundColor: Colors
            .transparent, // Transparente para usar el color de fondo del Scaffold
        elevation: 0, // Sin sombra
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onBackground),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          "Forgot Password",
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.015 * 18,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 40), // Espacio superior
              Text(
                "¿Olvidaste tu contraseña?",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.015 * 18,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                "Correo electrónico",
                maxContentWidth,
                controller: _emailController,
              ),
              const SizedBox(height: 24),
              _buildPrimaryButton(
                "Restablecer contraseña",
                maxContentWidth,
                onPressed: _sendPasswordResetEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
