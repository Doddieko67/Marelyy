import 'package:classroom_mejorado/Screen/AuthScreen.dart';
import 'package:classroom_mejorado/Screen/app_shell.dart';
import 'package:classroom_mejorado/function/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:classroom_mejorado/firebase_options.dart';
import 'package:classroom_mejorado/theme/app_colors.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';

// Mantén el GlobalKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationSettings = await FirebaseMessaging.instance
      .requestPermission(provisional: true);

  // For apple platforms, ensure the APNS token is available before making any FCM plugin API calls
  final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  if (apnsToken != null) {
    // APNS token is available, make FCM plugin API requests...
  }
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print("fcmmmm $fcmToken \n\n\n\n");

  // Observa los cambios de autenticación
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user == null) {
      print('User is currently signed out!');
      navigatorKey.currentState?.pushReplacementNamed('/login');
    } else {
      print('User is signed in!');
      navigatorKey.currentState?.pushReplacementNamed('/main');
      print("Redirigiendo a /main (AppShell)");
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define el tema oscuro usando tu paleta de colores (sin cambios)
    final ThemeData appDarkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffoldBg,
      primaryColor: primaryAccentColor,
      colorScheme: ColorScheme.dark(
        primary: primaryAccentColor,
        onPrimary: darkPrimaryText,
        secondary: textMediumColor,
        onSecondary: darkPrimaryText,
        surface:
            darkElementBackground, // Color para superficies (usado en BottomNavBarBgColor)
        onSurface: darkPrimaryText,
        background: darkScaffoldBg,
        onBackground: darkPrimaryText,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkScaffoldBg,
        foregroundColor: darkPrimaryText,
        elevation: 1,
        titleTextStyle: TextStyle(
          fontFamily: fontFamilyPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkPrimaryText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        hintStyle: TextStyle(
          color: darkSecondaryText.withOpacity(0.7),
          fontFamily: fontFamilySecondary,
        ),
        labelStyle: TextStyle(
          color: darkSecondaryText,
          fontFamily: fontFamilySecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: darkInputFill.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: primaryAccentColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16.0),
        iconColor: darkSecondaryText,
        prefixIconColor: darkSecondaryText,
        suffixIconColor: darkSecondaryText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccentColor,
          foregroundColor: darkPrimaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.015 * 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: darkElementBackground,
          foregroundColor: darkPrimaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.015 * 14,
          ),
        ),
      ),
      textTheme: ThemeData.dark().textTheme
          .copyWith(
            displayLarge: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            displayMedium: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            displaySmall: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            headlineLarge: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            headlineMedium: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            headlineSmall: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            titleLarge: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
              fontWeight: FontWeight.bold,
            ),
            titleMedium: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            titleSmall: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
            ),
            bodyLarge: TextStyle(
              fontFamily: fontFamilySecondary,
              color: darkPrimaryText,
              fontSize: 16,
            ),
            bodyMedium: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
              fontSize: 14,
            ),
            bodySmall: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkSecondaryText,
              fontSize: 12,
            ),
            labelLarge: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkPrimaryText,
              fontWeight: FontWeight.bold,
            ),
            labelMedium: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkSecondaryText,
            ),
            labelSmall: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: darkSecondaryText,
            ),
          )
          .apply(
            // bodyColor: darkPrimaryText,
            // displayColor: darkPrimaryText,
          ),
      iconTheme: IconThemeData(color: darkSecondaryText),
      dividerColor: darkSecondaryText.withOpacity(0.3),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryAccentColor,
        selectionColor: primaryAccentColor.withOpacity(0.4),
        selectionHandleColor: primaryAccentColor,
      ),
    );

    return MaterialApp(
      title: 'Taskify App',
      navigatorKey: navigatorKey,
      initialRoute: FirebaseAuth.instance.currentUser != null
          ? '/main'
          : '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return AppAnimations.createFadeThroughWithSymmetricBlurRoute(
              const AuthScreen(),
            );
          case '/main':
            return AppAnimations.createFadeThroughWithBlurRoute(
              const AppShell(), // ¡Ahora se navega al AppShell!
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const Center(
                child: Text(
                  'Error: Ruta desconocida. ¡Vuelve a cargar la aplicación!',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
        }
      },
      themeMode: ThemeMode.dark,
      darkTheme: appDarkTheme,
      debugShowCheckedModeBanner: false,
    );
  }
}
