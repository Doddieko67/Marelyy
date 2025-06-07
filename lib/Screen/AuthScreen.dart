// lib/screen/AuthScreen.dart (o donde tengas este archivo)

import 'package:classroom_mejorado/Screen/forgot_password_screen.dart';
import 'package:classroom_mejorado/widgets/alert_widet.dart';
import 'package:classroom_mejorado/widgets/all_required_widget.dart';
import 'package:classroom_mejorado/widgets/already_exists_widget.dart';
import 'package:classroom_mejorado/function/animations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ¡NUEVO! Importación de Firestore
import 'package:classroom_mejorado/theme/app_typography.dart';

// --- Función auxiliar para gestionar el perfil de usuario en Firestore ---
// Esta función está fuera de la clase _AuthScreenState para ser más modular y reutilizable.
Future<void> _createOrUpdateUserProfileInFirestore(
  User user, {
  String? initialName,
}) async {
  final userDocRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid);

  try {
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      // Si el documento NO existe, es un nuevo usuario o su primera vez iniciando sesión.
      print('Creando nuevo perfil de Firestore para: ${user.uid}');
      await userDocRef.set({
        'name':
            initialName ??
            user.displayName ??
            user.email?.split('@')[0] ??
            'Usuario Nuevo',
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt':
            FieldValue.serverTimestamp(), // Marca la fecha de creación en el servidor
        'lastSignIn':
            FieldValue.serverTimestamp(), // Marca la fecha del último inicio de sesión
        'role': 'member', // Un rol por defecto, si lo necesitas
        // Puedes añadir más campos iniciales aquí (ej. 'bio': '', 'interests': [])
      });
    } else {
      // Si el documento YA existe, actualiza la fecha del último inicio de sesión
      // y cualquier otro campo que pueda haber cambiado en Auth (como photoURL o displayName)
      print('Actualizando perfil de Firestore para: ${user.uid}');
      Map<String, dynamic> updateData = {
        'lastSignIn': FieldValue.serverTimestamp(),
      };
      // Solo actualiza si el displayName de Auth no es nulo y difiere del 'name' en Firestore
      if (user.displayName != null && user.displayName != userDoc.get('name')) {
        updateData['name'] = user.displayName;
      }
      // Solo actualiza si la photoURL de Auth no es nula y difiere de 'photoURL' en Firestore
      if (user.photoURL != null && user.photoURL != userDoc.get('photoURL')) {
        updateData['photoURL'] = user.photoURL;
      }
      await userDocRef.update(updateData);
    }
  } catch (e) {
    print('Error al crear/actualizar perfil de Firestore para ${user.uid}: $e');
    // Considera mostrar un SnackBar o loggear este error de manera más robusta
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _selectedTabIndex = 0; // 0 for Log In, 1 for Sign Up
  int _previousTabIndex = 0; // Para la dirección de la animación

  // Controladores de texto
  final _createEmailController = TextEditingController();
  final _createPasswordController = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _nameController = TextEditingController(); // Para Sign Up

  final _confirmPasswordController = TextEditingController();

  // Estado para la visibilidad de la contraseña
  bool _obscureCreatePassword = true;
  bool _obscureLoginPassword = true;

  // Instancia de AppAnimations para mostrar los diálogos animados
  final AppAnimations _appAnimations = AppAnimations();

  @override
  void dispose() {
    _createEmailController.dispose();
    _createPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildTab(String title, int index, BuildContext context) {
    bool isActive = _selectedTabIndex == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _previousTabIndex = _selectedTabIndex;
          _selectedTabIndex = index;
          // Limpiar controladores al cambiar de pestaña
          _createEmailController.clear();
          _createPasswordController.clear();
          _confirmPasswordController.clear();
          _loginEmailController.clear();
          _loginPasswordController.clear();
          _nameController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.only(top: 16, bottom: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 3.0,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.015 * 14,
          ),
        ),
      ),
    );
  }

  // --- Widgets Auxiliares para TextField con visibilidad de contraseña ---
  Widget _buildTextField(
    String placeholder,
    double maxWidth, {
    bool isPassword = false,
    TextEditingController? controller,
    required bool obscureTextValue,
    VoidCallback? onToggleVisibility,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            obscureText: obscureTextValue,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: fontFamilySecondary,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureTextValue
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: theme.iconTheme.color?.withOpacity(0.7),
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
    String text,
    double maxWidth, {
    required VoidCallback onPressed,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onPressed, child: Text(text)),
        ),
      ),
    );
  }

  // --- Lógica de Autenticación de Firebase ---

  Future<void> _handleEmailSignUp() async {
    final email = _createEmailController.text.trim();
    final password = _createPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final fullName = _nameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        fullName.isEmpty ||
        confirmPassword.isEmpty) {
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        const AllRequiredWidget(), // Este widget ya debería estar en español o ser genérico
      );
      return;
    }

    if (password != confirmPassword) {
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        const AllAlertWidget(text: 'Las contraseñas no coinciden.'),
      );
      return;
    }

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        print(
          "Usuario registrado: ${credential.user?.email}",
        ); // Mensaje de consola
        // ¡LLAMADA CLAVE PARA CREAR EL PERFIL DE FIRESTORE!
        // Pasamos el fullName para que sea el nombre inicial del perfil de Firestore
        await _createOrUpdateUserProfileInFirestore(
          credential.user!,
          initialName: fullName,
        );

        // Opcional: Ya no es estrictamente necesario llamar a updateDisplayName
        // aquí si _createOrUpdateUserProfileInFirestore ya lo maneja o si el 'name' de Firestore es la fuente principal.
        // await credential.user?.updateDisplayName(fullName);

        // Aquí podrías añadir una navegación a la pantalla principal o un mensaje de éxito
        // if (mounted) {
        //   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
        // }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        _appAnimations.showAnimatedProductCreateDialog(
          context,
          const AllAlertWidget(
            text: 'La contraseña proporcionada es demasiado débil.',
          ),
        );
      } else if (e.code == 'email-already-in-use') {
        _appAnimations.showAnimatedProductCreateDialog(
          context,
          const AlreadyExistsWidget(), // Este widget ya debería estar en español o ser genérico
        );
      } else {
        _appAnimations.showAnimatedProductCreateDialog(
          context,
          AllAlertWidget(text: 'Error de registro: ${e.message}'),
        );
      }
    } catch (e) {
      print(e);
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        AllAlertWidget(text: "Ocurrió un error inesperado: $e"),
      );
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        const AllRequiredWidget(),
      );
      return;
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        print(
          "Usuario inició sesión: ${credential.user?.email}",
        ); // Mensaje de consola
        // ¡LLAMADA CLAVE PARA CREAR/ACTUALIZAR EL PERFIL DE FIRESTORE!
        // Esta llamada asegura que el perfil se cree si no existe (ej. usuario registrado antes de esta lógica)
        // o que se actualice si ya existe (ej. actualizar lastSignIn, photoURL, displayName).
        await _createOrUpdateUserProfileInFirestore(credential.user!);

        // Aquí podrías añadir una navegación a la pantalla principal o un mensaje de éxito
        // if (mounted) {
        //   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
        // }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _appAnimations.showAnimatedProductCreateDialog(
          context,
          const AllAlertWidget(
            text: 'No se encontró ningún usuario con ese correo electrónico.',
          ),
        );
      } else if (e.code == 'wrong-password') {
        _appAnimations.showAnimatedProductCreateDialog(
          context,
          const AllAlertWidget(
            text: 'La contraseña proporcionada no es correcta.',
          ),
        );
      } else {
        _appAnimations.showAnimatedProductCreateDialog(
          context,
          AllAlertWidget(text: 'Error de inicio de sesión: ${e.message}'),
        );
      }
    } catch (e) {
      print('Error al iniciar sesión: $e');
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        AllAlertWidget(text: 'Ocurrió un error inesperado: $e'),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // El usuario canceló el inicio de sesión
        return;
      }

      final GoogleSignInAuthentication? googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        print("Usuario de Google inició sesión!"); // Mensaje de consola
        // ¡LLAMADA CLAVE PARA CREAR/ACTUALIZAR EL PERFIL DE FIRESTORE!
        // Para Google Sign-In, `userCredential.user` ya contiene `displayName` y `photoURL`
        // por lo que no es necesario pasar un `initialName`
        await _createOrUpdateUserProfileInFirestore(userCredential.user!);

        // Aquí podrías añadir una navegación a la pantalla principal o un mensaje de éxito
        // if (mounted) {
        //   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
        // }
      }
    } on FirebaseAuthException catch (e) {
      print(
        'Error de autenticación con Google de Firebase: ${e.code} - ${e.message}',
      ); // Mensaje de consola
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        AllAlertWidget(
          text: 'Error al iniciar sesión con Google: ${e.message}',
        ),
      );
    } catch (e) {
      print('Error de inicio de sesión con Google: $e'); // Mensaje de consola
      _appAnimations.showAnimatedProductCreateDialog(
        context,
        AllAlertWidget(
          text:
              'Ocurrió un error inesperado con el inicio de sesión de Google: $e',
        ),
      );
    }
  }

  // --- Formularios de Log In y Sign Up ---
  Widget _buildLoginForm(double maxContentWidth, BuildContext context) {
    return Column(
      key: const ValueKey<int>(0), // Clave única para AnimatedSwitcher
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildTextField(
          "Correo Electrónico", // Traducido
          maxContentWidth,
          controller: _loginEmailController,
          isPassword: false,
          obscureTextValue: false,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          "Contraseña", // Traducido
          maxContentWidth,
          controller: _loginPasswordController,
          isPassword: true,
          obscureTextValue: _obscureLoginPassword,
          onToggleVisibility: () {
            setState(() {
              _obscureLoginPassword = !_obscureLoginPassword;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton(
          "Iniciar Sesión", // Traducido
          maxContentWidth,
          onPressed: _handleEmailLogin,
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, left: 6),
          child: GestureDetector(
            onTap: () {
              print(
                "¿Olvidaste tu contraseña? presionado",
              ); // Mensaje de consola
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ForgotPasswordScreen(),
                ),
              );
            },
            child: Text(
              "¿Olvidaste tu contraseña?", // Traducido
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(double maxContentWidth, BuildContext context) {
    return Column(
      key: const ValueKey<int>(1), // Clave única para AnimatedSwitcher
      children: [
        _buildTextField(
          "Nombre Completo", // Traducido
          maxContentWidth,
          controller: _nameController,
          isPassword: false,
          obscureTextValue: false,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          "Correo Electrónico", // Traducido
          maxContentWidth,
          controller: _createEmailController,
          isPassword: false,
          obscureTextValue: false,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          "Contraseña", // Traducido
          maxContentWidth,
          controller: _createPasswordController,
          isPassword: true,
          obscureTextValue: _obscureCreatePassword,
          onToggleVisibility: () {
            setState(() {
              _obscureCreatePassword = !_obscureCreatePassword;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          "Confirmar Contraseña", // Traducido
          maxContentWidth,
          controller: _confirmPasswordController,
          isPassword: true,
          obscureTextValue:
              _obscureCreatePassword, // Usar la misma variable para que cambien juntas si es la intención
          onToggleVisibility: () {
            setState(() {
              _obscureCreatePassword = !_obscureCreatePassword;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton(
          "Registrarse", // Traducido
          maxContentWidth,
          onPressed: _handleEmailSignUp,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // --- Social Buttons ---
  Widget _buildSocialButtons(double maxWidth) {
    return Column(
      children: [
        // Este texto ya estaba en español
        // const Text(
        //   'O iniciar con',
        //   style: TextStyle(
        //     fontSize: 16,
        //     color: Colors.white70, // Este color puede no ser del tema
        //   ),
        // ),
        // const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton.icon(
                onPressed:
                    _handleGoogleSignIn, // Llama a la función de Google Sign-In
                icon: Icon(
                  Icons
                      .g_mobiledata, // Considerar un icono más estándar de Google si es posible (ej. FontAwesomeIcons.google)
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
                label: Text(
                  'Continuar con Google', // Ya estaba en español
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.015 * 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxContentWidth = screenWidth > 480 ? 480 : screenWidth - 32;

    return Scaffold(
      body: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                screenHeight -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header "Taskify"
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Text(
                          "Taskify", // Mantener si es el nombre de la app
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.015 * 18,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      ),

                      // Tabs "Log In", "Sign Up"
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3.0),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: theme.dividerColor,
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              _buildTab(
                                "Iniciar Sesión",
                                0,
                                context,
                              ), // Traducido
                              const SizedBox(width: 32),
                              _buildTab("Registrarse", 1, context), // Traducido
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // AnimatedSwitcher para la transición entre formularios
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              final int? currentKey =
                                  (child.key as ValueKey<int>).value;
                              final bool isForward =
                                  currentKey! > _previousTabIndex;

                              final offsetAnimation = Tween<Offset>(
                                begin: isForward
                                    ? const Offset(1.0, 0.0)
                                    : const Offset(-1.0, 0.0),
                                end: Offset.zero,
                              ).animate(animation);

                              return SlideTransition(
                                position: offsetAnimation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                        layoutBuilder:
                            (
                              Widget? currentChild,
                              List<Widget> previousChildren,
                            ) {
                              return Stack(
                                alignment: Alignment.topLeft,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                        child: _selectedTabIndex == 0
                            ? _buildLoginForm(maxContentWidth, context)
                            : _buildSignUpForm(maxContentWidth, context),
                      ),

                      // "Or continue with" Text (Común para ambos formularios)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Text(
                          "O continuar con", // Traducido
                          textAlign: TextAlign
                              .start, // Podría ser TextAlign.center si se prefiere
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.015 * 18,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Social Login Buttons (Común para ambos formularios)
                      _buildSocialButtons(maxContentWidth),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
