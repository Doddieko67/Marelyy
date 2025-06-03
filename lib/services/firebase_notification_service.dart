// lib/services/firebase_notification_service.dart
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // Para jsonDecode

// Función para manejar mensajes de FCM en segundo plano (Top-level function)
// Esta ya estaba bien.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegúrate de inicializar Firebase si no lo has hecho ya
  // await Firebase.initializeApp(); // Si tu main ya lo hace, no es estrictamente necesario aquí, pero es una buena práctica.
  print('Handling a background message: ${message.messageId}');
}

// NUEVA FUNCIÓN DE NIVEL SUPERIOR para los clics de notificaciones locales en segundo plano
// Esta es la que necesita ser static/top-level para flutter_local_notifications.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('notificationTapBackground received a notification response');
  final String? payloadString = notificationResponse.payload;
  if (payloadString != null) {
    // Reutilizamos la lógica de _handleNotificationClick, pero en un contexto estático
    // o de nivel superior.
    try {
      final Map<String, dynamic> data = jsonDecode(payloadString);
      final String type = data['type'] ?? '';

      if (type == 'chat' && data.containsKey('communityId')) {
        final String communityId = data['communityId'];
        print('Background tap: Navigating to chat for community: $communityId');
        // Usa la clave estática para navegar
        FirebaseNotificationService.navigatorKey.currentState?.pushNamed(
          '/communityChat',
          arguments: {'communityId': communityId},
        );
      } else if (type == 'task' &&
          data.containsKey('communityId') &&
          data.containsKey('taskId')) {
        final String communityId = data['communityId'];
        final String taskId = data['taskId'];
        print(
          'Background tap: Navigating to task detail for community: $communityId, task: $taskId',
        );
        // Usa la clave estática para navegar
        FirebaseNotificationService.navigatorKey.currentState?.pushNamed(
          '/taskDetail',
          arguments: {'communityId': communityId, 'taskId': taskId},
        );
      }
    } catch (e) {
      print('Error parsing or handling background notification payload: $e');
    }
  }
}

class FirebaseNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Global NavigatorKey para navegar desde notificaciones
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> initNotifications() async {
    // 1. Configurar el manejador de mensajes en segundo plano de FCM
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Solicitar permisos de notificación
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // 3. Inicializar flutter_local_notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // Cuando la notificación se recibe y se toca en primer plano:
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          // Esta sí puede llamar a la función de instancia porque la app está en primer plano
          _handleNotificationClick(response.payload!);
        }
      },
      // CUANDO LA NOTIFICACIÓN SE RECIBE Y SE TOCA EN SEGUNDO PLANO/TERMINADA:
      // ¡Aquí usamos la nueva función de nivel superior!
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Crear un canal de notificación para Android (obligatorio en Android 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Este canal se usa para notificaciones importantes.',
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // 4. Obtener y guardar el token de FCM
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _getTokenAndSave();
      } else {
        // Opcional: limpiar token si el usuario cierra sesión
        removeToken();
      }
    });

    // 5. Manejar mensajes cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
            ),
          ),
          payload: jsonEncode(
            message.data,
          ), // Pasa el mapa de datos completo como JSON string
        );
      } else if (notification != null && Platform.isIOS) {
        _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(iOS: DarwinNotificationDetails()),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 6. Manejar la interacción del usuario con las notificaciones
    // Cuando la aplicación se abre desde una notificación (estado terminado)
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print(
          'App opened from terminated state by notification: ${message.messageId}',
        );
        _handleNotificationClick(jsonEncode(message.data));
      }
    });

    // Cuando la aplicación se abre desde una notificación (estado de segundo plano)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background by notification: ${message.messageId}');
      _handleNotificationClick(jsonEncode(message.data));
    });
  }

  // --- Helpers ---

  Future<void> _getTokenAndSave() async {
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    if (token != null && _auth.currentUser != null) {
      String userId = _auth.currentUser!.uid;
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      print('FCM token saved for user $userId');
    }
  }

  Future<void> removeToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null && _auth.currentUser != null) {
      String userId = _auth.currentUser!.uid;
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
      print('FCM token removed for user $userId');
    }
  }

  // Esta función puede seguir siendo de instancia porque solo se llama
  // cuando la app ya está en primer plano (desde onDidReceiveNotificationResponse)
  // o cuando se recupera un mensaje inicial/apertura de app (donde ya hay un contexto).
  void _handleNotificationClick(String payloadString) {
    try {
      final Map<String, dynamic> data = jsonDecode(payloadString);

      final String type = data['type'] ?? '';

      // Usar la clave estática para navegar
      if (type == 'chat' && data.containsKey('communityId')) {
        final String communityId = data['communityId'];
        print('Foreground tap: Navigating to chat for community: $communityId');
        FirebaseNotificationService.navigatorKey.currentState?.pushNamed(
          '/communityChat',
          arguments: {'communityId': communityId},
        );
      } else if (type == 'task' &&
          data.containsKey('communityId') &&
          data.containsKey('taskId')) {
        final String communityId = data['communityId'];
        final String taskId = data['taskId'];
        print(
          'Foreground tap: Navigating to task detail for community: $communityId, task: $taskId',
        );
        FirebaseNotificationService.navigatorKey.currentState?.pushNamed(
          '/taskDetail',
          arguments: {'communityId': communityId, 'taskId': taskId},
        );
      }
    } catch (e) {
      print('Error parsing or handling notification payload: $e');
    }
  }
}
