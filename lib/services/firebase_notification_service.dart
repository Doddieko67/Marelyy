// lib/services/firebase_notification_service.dart
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

// Función para manejar mensajes de FCM en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');

  // *** NUEVO: Manejar cancelaciones de tareas en segundo plano ***
  if (message.data['type'] == 'task_cancel') {
    final String? taskId = message.data['taskId'];
    if (taskId != null) {
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();
      final int notificationId = taskId.hashCode;
      await notifications.cancel(notificationId);
      print('Cancelled task notification for task: $taskId');
    }
  }
}

// Función de nivel superior para los clics de notificaciones locales en segundo plano
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('notificationTapBackground received a notification response');
  final String? payloadString = notificationResponse.payload;
  if (payloadString != null) {
    try {
      final Map<String, dynamic> data = jsonDecode(payloadString);
      final String type = data['type'] ?? '';

      if (type == 'chat' && data.containsKey('communityId')) {
        final String communityId = data['communityId'];
        print('Background tap: Navigating to chat for community: $communityId');
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

  // *** MAPAS PARA TRACKEAR NOTIFICACIONES ACTIVAS ***
  static final Map<String, int> _activeChatNotifications = {};
  static final Map<String, int> _activeTaskNotifications = {};

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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleNotificationClick(response.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // *** Canal de notificación con configuración avanzada ***
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Este canal se usa para notificaciones importantes.',
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
      showBadge: true,
      playSound: true,
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
        removeToken();
      }
    });

    // 5. Manejar mensajes cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      _handleForegroundMessage(message);
    });

    // 6. Manejar la interacción del usuario con las notificaciones
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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background by notification: ${message.messageId}');
      _handleNotificationClick(jsonEncode(message.data));
    });
  }

  // *** FUNCIÓN MEJORADA: Manejar mensajes en primer plano ***
  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;

    final String type = data['type'] ?? '';

    // *** NUEVO: Manejar cancelaciones de tareas ***
    if (type == 'task_cancel') {
      _handleTaskCancellation(data);
      return; // No mostrar notificación para cancelaciones
    }

    if (notification != null) {
      if (type == 'chat' && data.containsKey('communityId')) {
        _handleChatNotification(notification, data);
      } else if (type == 'task' && data.containsKey('taskId')) {
        _handleTaskNotification(notification, data);
      } else {
        // Notificaciones regulares
        _showRegularNotification(notification, data);
      }
    }
  }

  // *** NUEVA FUNCIÓN: Manejar cancelaciones de tareas ***
  void _handleTaskCancellation(Map<String, dynamic> data) {
    final String? taskId = data['taskId'];
    if (taskId != null) {
      clearTaskNotifications(taskId);
      print('Task notification cancelled for task: $taskId');
    }
  }

  // *** FUNCIÓN MEJORADA: Manejar notificaciones de chat ***
  void _handleChatNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) {
    final String communityId = data['communityId'];
    final String? notificationIdStr = data['notificationId'];

    // Usar un ID consistente basado en la comunidad
    int notificationId;
    if (notificationIdStr != null) {
      notificationId = int.tryParse(notificationIdStr) ?? communityId.hashCode;
    } else {
      notificationId = communityId.hashCode;
    }

    // *** CANCELAR NOTIFICACIÓN ANTERIOR DE LA MISMA COMUNIDAD ***
    if (_activeChatNotifications.containsKey(communityId)) {
      final int previousId = _activeChatNotifications[communityId]!;
      _flutterLocalNotificationsPlugin.cancel(previousId);
      print('Cancelled previous chat notification for community: $communityId');
    }

    // Registrar la nueva notificación
    _activeChatNotifications[communityId] = notificationId;

    // Configuración para chat
    final AndroidNotificationDetails
    androidDetailsWithTag = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Este canal se usa para notificaciones importantes.',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
      tag:
          'chat_$communityId', // *** CLAVE: Mismo tag = reemplazo automático ***
      groupKey: 'chat_notifications',
      setAsGroupSummary: false,
      autoCancel: true,
      ongoing: false,
      silent: false,
    );

    final DarwinNotificationDetails iosDetailsWithThread =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: 'chat_$communityId', // *** Para agrupar en iOS ***
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetailsWithTag,
      iOS: iosDetailsWithThread,
    );

    _flutterLocalNotificationsPlugin.show(
      notificationId,
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(data),
    );

    print(
      'Showed chat notification for community: $communityId with ID: $notificationId',
    );
  }

  // *** NUEVA FUNCIÓN: Manejar notificaciones de tareas ***
  void _handleTaskNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) {
    final String taskId = data['taskId'];
    final String? notificationIdStr = data['notificationId'];

    // Usar un ID consistente basado en la tarea
    int notificationId;
    if (notificationIdStr != null) {
      notificationId = int.tryParse(notificationIdStr) ?? taskId.hashCode;
    } else {
      notificationId = taskId.hashCode;
    }

    // *** CANCELAR NOTIFICACIÓN ANTERIOR DE LA MISMA TAREA ***
    if (_activeTaskNotifications.containsKey(taskId)) {
      final int previousId = _activeTaskNotifications[taskId]!;
      _flutterLocalNotificationsPlugin.cancel(previousId);
      print('Cancelled previous task notification for task: $taskId');
    }

    // Registrar la nueva notificación
    _activeTaskNotifications[taskId] = notificationId;

    // Configuración para tareas
    final AndroidNotificationDetails androidDetailsTask =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'Este canal se usa para notificaciones importantes.',
          importance: Importance.max,
          priority: Priority.high,
          enableLights: true,
          enableVibration: true,
          playSound: true,
          groupKey: 'task_notifications',
          setAsGroupSummary: false,
          autoCancel: true,
          ongoing: false,
          silent: false,
        );

    final DarwinNotificationDetails iosDetailsTask = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'task_$taskId',
    );

    final NotificationDetails notificationDetailsTask = NotificationDetails(
      android: androidDetailsTask,
      iOS: iosDetailsTask,
    );

    _flutterLocalNotificationsPlugin.show(
      notificationId,
      notification.title,
      notification.body,
      notificationDetailsTask,
      payload: jsonEncode(data),
    );

    print(
      'Showed task notification for task: $taskId with ID: $notificationId',
    );
  }

  // *** FUNCIÓN: Mostrar notificación regular ***
  void _showRegularNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) {
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'Este canal se usa para notificaciones importantes.',
          importance: Importance.max,
          priority: Priority.high,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    _flutterLocalNotificationsPlugin.show(
      notificationId,
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  // *** FUNCIÓN: Limpiar notificaciones de chat por comunidad ***
  void clearChatNotifications(String communityId) {
    if (_activeChatNotifications.containsKey(communityId)) {
      final int notificationId = _activeChatNotifications[communityId]!;
      _flutterLocalNotificationsPlugin.cancel(notificationId);
      _activeChatNotifications.remove(communityId);
      print('Cleared chat notifications for community: $communityId');
    }
  }

  // *** FUNCIÓN: Limpiar notificaciones de tarea ***
  void clearTaskNotifications(String taskId) {
    if (_activeTaskNotifications.containsKey(taskId)) {
      final int notificationId = _activeTaskNotifications[taskId]!;
      _flutterLocalNotificationsPlugin.cancel(notificationId);
      _activeTaskNotifications.remove(taskId);
      print('Cleared task notifications for task: $taskId');
    }
  }

  // *** FUNCIÓN: Limpiar todas las notificaciones ***
  void clearAllNotifications() {
    _flutterLocalNotificationsPlugin.cancelAll();
    _activeChatNotifications.clear();
    _activeTaskNotifications.clear();
    print('Cleared all notifications');
  }

  // *** FUNCIÓN: Obtener y guardar token FCM ***
  Future<void> _getTokenAndSave() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
        print('FCM Token: $token');
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }

    // Escuchar cambios de token
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  // *** FUNCIÓN: Guardar token en Firestore ***
  Future<void> _saveTokenToDatabase(String token) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user to save token');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      print('Token saved to database: $token');
    } catch (e) {
      print('Error saving token to database: $e');
    }
  }

  // *** FUNCIÓN: Eliminar token al cerrar sesión ***
  Future<void> removeToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        final User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
          print('Token removed from database');
        }
      }

      // Limpiar notificaciones locales
      clearAllNotifications();
    } catch (e) {
      print('Error removing token: $e');
    }
  }

  // *** FUNCIÓN: Manejar clics en notificaciones ***
  void _handleNotificationClick(String payload) {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final String type = data['type'] ?? '';

      if (type == 'chat' && data.containsKey('communityId')) {
        final String communityId = data['communityId'];
        print('Navigating to chat for community: $communityId');

        // Limpiar notificaciones de esta comunidad
        clearChatNotifications(communityId);

        navigatorKey.currentState?.pushNamed(
          '/communityChat',
          arguments: {'communityId': communityId},
        );
      } else if (type == 'task' &&
          data.containsKey('communityId') &&
          data.containsKey('taskId')) {
        final String communityId = data['communityId'];
        final String taskId = data['taskId'];
        print(
          'Navigating to task detail for community: $communityId, task: $taskId',
        );

        // Limpiar notificaciones de esta tarea
        clearTaskNotifications(taskId);

        navigatorKey.currentState?.pushNamed(
          '/taskDetail',
          arguments: {'communityId': communityId, 'taskId': taskId},
        );
      }
    } catch (e) {
      print('Error parsing or handling notification payload: $e');
    }
  }

  // *** FUNCIÓN: Obtener tokens FCM del dispositivo ***
  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // *** FUNCIÓN: Suscribirse a topic (opcional) ***
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // *** FUNCIÓN: Desuscribirse de topic (opcional) ***
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }
}
