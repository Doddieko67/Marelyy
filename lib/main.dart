import 'package:classroom_mejorado/features/auth/screens/auth_screen.dart';
import 'package:classroom_mejorado/shared/navigation/app_shell.dart';
import 'package:classroom_mejorado/core/services/firebase_notification_service.dart';
import 'package:classroom_mejorado/core/providers/theme_provider.dart';
import 'package:classroom_mejorado/core/theme/app_theme.dart';
import 'package:classroom_mejorado/features/splash/screens/splash_screen.dart';
import 'package:classroom_mejorado/features/onboarding/screens/onboarding_screen.dart';
import 'package:classroom_mejorado/features/search/screens/global_search_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:classroom_mejorado/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationService = FirebaseNotificationService();
  await notificationService.initNotifications();

  // Solicitar permisos de notificación (para iOS y Android 13+)
  await FirebaseMessaging.instance.requestPermission(provisional: true);

  // Observa los cambios de autenticación
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user == null) {
      print('User is currently signed out!');
      FirebaseNotificationService.navigatorKey.currentState
          ?.pushReplacementNamed('/auth');
    } else {
      print('User is signed in!');
      FirebaseNotificationService.navigatorKey.currentState
          ?.pushReplacementNamed('/home');
      print("Redirigiendo a /home (AppShell)");
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(navigatorKey: FirebaseNotificationService.navigatorKey),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Taskify',
          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/auth': (context) => const AuthScreen(),
            '/home': (context) => const AppShell(),
            '/search': (context) => const GlobalSearchScreen(),
          },
        );
      },
    );
  }
}