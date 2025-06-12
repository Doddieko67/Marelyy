// lib/services/firebase_notification_service.dart
import 'dart:convert';
import 'dart:io'; // Asegúrate de tener esta importación si no estaba

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart'; // Necesario para ValueNotifier y GlobalKey
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Función para manejar mensajes de FCM en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print(
    'Background message data: ${message.data}',
  ); // Imprime los datos para depuración

  // *** NUEVO: Manejar cancelaciones de tareas en segundo plano ***
  if (message.data['type'] == 'task_cancel') {
    final String? taskId = message.data['taskId'];
    if (taskId != null) {
      // Es importante inicializar FlutterLocalNotificationsPlugin aquí también si no está ya
      // pero es complejo hacerlo correctamente en un isolate de background.
      // Una mejor aproximación podría ser que el cliente lo maneje al abrir la app
      // o que la notificación de cancelación tenga un tag que la reemplace/elimine.
      // Por ahora, solo logueamos.
      // La cancelación real se hará cuando la app esté en primer plano y procese el mensaje
      // o cuando el usuario abra la app.
      print(
        'Background: Received task cancellation for task: $taskId. Cancellation will be processed by app.',
      );
    }
  }
  // Aquí podrías querer inicializar Firebase si es necesario para otras operaciones
  // await Firebase.initializeApp(); // Descomentar si es necesario
  // (No mostrar notificaciones locales desde aquí directamente si la app está terminada,
  // FCM las muestra automáticamente. Si está en background (no terminada), onMessageOpenedApp lo maneja)
}

// Función de nivel superior para los clics de notificaciones locales en segundo plano
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print(
    'notificationTapBackground received a notification response: ${notificationResponse.payload}',
  );
  // Esta función se llama cuando se toca una notificación local y la app está en segundo plano (pero no terminada).
  // La lógica de navegación ya está en _handleNotificationClick a través de onDidReceiveNotificationResponse
  // y onMessageOpenedApp, que deberían cubrir la mayoría de los casos.
  // Re-usaremos _handleNotificationClick si es posible, pasándole el payload.
  if (notificationResponse.payload != null) {
    // No podemos acceder directamente a la instancia de FirebaseNotificationService aquí
    // La navegación debe ser manejada por la app cuando se abre.
    // El payload se pasa a onDidReceiveNotificationResponse cuando la app se inicializa.
    print("Background tap payload: ${notificationResponse.payload}");
    // Se podría guardar el payload y procesarlo al iniciar la app si es necesario.
  }
}

class FirebaseNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // >>> AÑADIDO: Notificador para el ID de la comunidad del chat actualmente activo <<<
  final ValueNotifier<String?> activeChatCommunityId = ValueNotifier<String?>(
    null,
  );

  // Global NavigatorKey para navegar desde notificaciones
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Mapas para trackear IDs de notificaciones activas y poder cancelarlas/reemplazarlas
  static final Map<String, int> _activeChatNotificationIds =
      {}; // communityId -> notificationId
  static final Map<String, int> _activeTaskNotificationIds =
      {}; // taskId -> notificationId

  // Singleton pattern para asegurar una única instancia
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  Future<void> initNotifications() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
        print(
          "Foreground/Background (not terminated) tap: ${response.payload}",
        );
        if (response.payload != null) {
          _handleNotificationClick(response.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackground, // Para taps en background
    );

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

    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _getTokenAndSave();
      } else {
        removeToken(); // Asegúrate que esto también limpie activeChatCommunityId si es relevante
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground: Got a message!');
      print('Foreground: Message data: ${message.data}');
      _handleForegroundMessage(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print(
          'App opened from terminated state by notification: ${message.messageId}',
        );
        // El payload aquí es message.data, no un string JSON.
        _handleNotificationClick(
          jsonEncode(message.data),
        ); // Asegúrate de codificarlo si _handleNotificationClick espera un string JSON
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        'App opened from background (FCM tap) by notification: ${message.messageId}',
      );
      _handleNotificationClick(jsonEncode(message.data));
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;
    final String type = data['type'] ?? '';

    if (type == 'task_cancel') {
      _handleTaskCancellation(data);
      return;
    }

    // >>> LÓGICA CLAVE PARA SILENCIAR NOTIFICACIONES DE CHAT ACTIVO <<<
    if (type == 'chat' && data.containsKey('communityId')) {
      final String communityIdFromNotification = data['communityId'];
      if (communityIdFromNotification == activeChatCommunityId.value) {
        print(
          'FirebaseNotificationService: Chat notification for ACTIVE chat ($communityIdFromNotification). Suppressing system tray notification.',
        );
        // Opcional: reproducir un sonido in-app aquí si se desea.
        // _playInAppChatSound();
        // Opcional: actualizar un contador de mensajes no leídos en la UI del chat si es necesario,
        // aunque el stream de Firestore debería manejar la visualización del mensaje.
        return; // No mostrar la notificación en la bandeja del sistema
      }
    }
    // >>> FIN DE LA LÓGICA DE SILENCIAMIENTO <<<

    if (notification != null) {
      // Si no fue suprimida y hay contenido de notificación
      if (type == 'chat' && data.containsKey('communityId')) {
        _showChatNotification(notification, data); // Renombrado para claridad
      } else if (type == 'task' && data.containsKey('taskId')) {
        _showTaskNotification(notification, data); // Renombrado para claridad
      } else {
        _showRegularNotification(notification, data);
      }
    } else {
      print(
        "Foreground: Received data-only message or notification was suppressed. Data: $data",
      );
      // Si es un mensaje de solo datos, y no fue suprimido arriba, puedes decidir mostrar una notificación local basada en 'data'.
      // Esto es útil si quieres construir la notificación completamente en el cliente.
      // if (type == 'chat' && data.containsKey('communityId') && activeChatCommunityId.value != data['communityId']) {
      //   _showChatNotificationFromData(data);
      // }
    }
  }

  // >>> AÑADIDO: Método para ser llamado desde CommunityChatTabContent <<<
  void setActiveChatCommunity(String? communityId) {
    activeChatCommunityId.value = communityId;
    print(
      "FirebaseNotificationService: Active chat community ID set to -> ${activeChatCommunityId.value}",
    );
    if (communityId != null) {
      // Al entrar a un chat, cancelamos cualquier notificación pendiente para esa comunidad.
      clearChatNotifications(communityId);
    }
  }

  void _handleTaskCancellation(Map<String, dynamic> data) {
    final String? taskId = data['taskId'];
    if (taskId != null) {
      // Usar el ID de notificación almacenado para esta tarea
      final int? notificationId = _activeTaskNotificationIds[taskId];
      if (notificationId != null) {
        _flutterLocalNotificationsPlugin.cancel(notificationId);
        _activeTaskNotificationIds.remove(taskId); // Limpiar del mapa
        print(
          'Task notification (ID: $notificationId) cancelled for task: $taskId',
        );
      } else {
        // Si no tenemos un ID almacenado (ej. la app fue reiniciada),
        // podríamos intentar cancelar por un tag si lo configuramos así,
        // o simplemente loguearlo. Cancelar por taskId.hashCode es una opción si los IDs son consistentes.
        _flutterLocalNotificationsPlugin.cancel(taskId.hashCode);
        print(
          'Attempted to cancel task notification for task: $taskId using hashCode.',
        );
      }
    }
  }

  void _showChatNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) {
    final String communityId = data['communityId'] as String;
    final String serverNotificationIdStr =
        data['notificationId'] as String? ??
        communityId.hashCode
            .toString(); // ID único de la notificación enviado desde el servidor
    final int messageCount =
        int.tryParse(data['messageCount'] as String? ?? '1') ?? 1;

    // Usamos el serverNotificationIdStr (convertido a int) como nuestro ID local.
    // Esto asegura que si el servidor envía el mismo 'notificationId' (que es communityId.hashCode en tu CF),
    // la notificación se reemplazará.
    final int localNotificationId =
        int.tryParse(serverNotificationIdStr) ?? communityId.hashCode;

    // Cancelar la notificación anterior de este chat si existe y tiene un ID diferente
    // (aunque el tag debería manejar el reemplazo en Android)
    if (_activeChatNotificationIds.containsKey(communityId) &&
        _activeChatNotificationIds[communityId] != localNotificationId) {
      _flutterLocalNotificationsPlugin.cancel(
        _activeChatNotificationIds[communityId]!,
      );
    }
    _activeChatNotificationIds[communityId] = localNotificationId;

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Este canal se usa para notificaciones importantes.',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
      tag: 'chat_$communityId', // Tag para agrupar/reemplazar en Android
      groupKey:
          'chat_group_$communityId', // Agrupa notificaciones de la misma comunidad
      // setAsGroupSummary: messageCount > 1, // Mostrar resumen si hay múltiples mensajes
      number: messageCount, // Muestra el contador de mensajes
      autoCancel: true,
    );
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'chat_$communityId', // Agrupa en iOS
      badgeNumber: messageCount,
    );
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    _flutterLocalNotificationsPlugin.show(
      localNotificationId, // ID único para esta comunidad
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(data), // Guardar todos los datos para el click
    );
    print(
      'Showed chat notification for community: $communityId with ID: $localNotificationId, Count: $messageCount',
    );
  }

  void _showTaskNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) {
    final String taskId = data['taskId'] as String;
    final String serverNotificationIdStr =
        data['notificationId'] as String? ?? taskId.hashCode.toString();
    final int localNotificationId =
        int.tryParse(serverNotificationIdStr) ?? taskId.hashCode;

    if (_activeTaskNotificationIds.containsKey(taskId) &&
        _activeTaskNotificationIds[taskId] != localNotificationId) {
      _flutterLocalNotificationsPlugin.cancel(
        _activeTaskNotificationIds[taskId]!,
      );
    }
    _activeTaskNotificationIds[taskId] = localNotificationId;

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Este canal se usa para notificaciones importantes.',
      importance: Importance.max,
      priority: Priority.high,
      tag:
          'task_$taskId', // Tag para que notificaciones de la misma tarea se reemplacen
      groupKey:
          'task_notifications_group', // O un groupKey más específico si es necesario
      autoCancel: true,
    );
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'task_$taskId',
    );
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    _flutterLocalNotificationsPlugin.show(
      localNotificationId, // ID único para esta tarea
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(data),
    );
    print(
      'Showed task notification for task: $taskId with ID: $localNotificationId',
    );
  }

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
          importance: Importance.max,
          priority: Priority.high,
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

  void clearChatNotifications(String communityId) {
    // Usar el tag para cancelar en Android. En iOS, las notificaciones se borran al abrir la app o el thread.
    // O usar el ID almacenado si es consistente.
    final String tag = 'chat_$communityId';
    _flutterLocalNotificationsPlugin.cancel(
      _activeChatNotificationIds[communityId] ?? communityId.hashCode,
      tag: Platform.isAndroid ? tag : null,
    );
    _activeChatNotificationIds.remove(communityId);
    print('Cleared chat notifications for community: $communityId (tag: $tag)');
  }

  void clearTaskNotifications(String taskId) {
    final String tag = 'task_$taskId';
    _flutterLocalNotificationsPlugin.cancel(
      _activeTaskNotificationIds[taskId] ?? taskId.hashCode,
      tag: Platform.isAndroid ? tag : null,
    );
    _activeTaskNotificationIds.remove(taskId);
    print('Cleared task notifications for task: $taskId (tag: $tag)');
  }

  void clearAllNotifications() {
    _flutterLocalNotificationsPlugin.cancelAll();
    _activeChatNotificationIds.clear();
    _activeTaskNotificationIds.clear();
    print('Cleared all notifications');
  }

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
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user to save token');
      return;
    }
    try {
      // Asegurarse que fcmTokens sea un array
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      if (userDoc.exists && userDoc.data()?['fcmTokens'] is List) {
        await userRef.update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      } else {
        // Si no existe o no es un array, lo crea/reemplaza
        await userRef.set(
          {
            'fcmTokens': [token],
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ); // merge: true para no sobreescribir otros campos del usuario
      }
      print('Token saved to database: $token for user ${user.uid}');
    } catch (e) {
      print('Error saving token to database for user ${user.uid}: $e');
    }
  }

  Future<void> removeToken() async {
    // Limpiar el activeChatCommunityId al cerrar sesión
    activeChatCommunityId.value = null;
    try {
      String? token = await _firebaseMessaging
          .getToken(); // Obtener el token actual para removerlo
      if (token != null) {
        final User? user =
            _auth.currentUser; // El usuario ya estará deslogueado aquí
        // Necesitarías el UID antes de desloguear para remover de un usuario específico.
        // O simplemente invalidar el token localmente.
        // Si el objetivo es remover el token del backend para el usuario que *acaba* de cerrar sesión,
        // esta lógica debe ejecutarse *antes* de que _auth.currentUser se vuelva null.
        // Por ahora, nos enfocaremos en invalidar el token a nivel de dispositivo y limpiar notificaciones.

        // await _firebaseMessaging.deleteToken(); // Invalida el token actual para esta instancia de la app
        // print('FCM token deleted from device.');

        // La lógica de remover de la BD debería estar en el proceso de logout de la app
      }
      clearAllNotifications();
    } catch (e) {
      print('Error removing/deleting token: $e');
    }
  }

  void _handleNotificationClick(String payloadString) {
    print("_handleNotificationClick payload: $payloadString");
    try {
      final Map<String, dynamic> data = jsonDecode(payloadString);
      final String type = data['type'] ?? '';

      if (type == 'chat' && data.containsKey('communityId')) {
        final String communityId = data['communityId'];
        print('Navigating to chat for community: $communityId');
        clearChatNotifications(communityId); // Limpiar al hacer clic también
        navigatorKey.currentState?.pushNamed(
          '/communityChat', // Asegúrate que esta ruta esté definida en tu MaterialApp
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
        clearTaskNotifications(taskId); // Limpiar al hacer clic
        navigatorKey.currentState?.pushNamed(
          '/taskDetail', // Asegúrate que esta ruta esté definida
          arguments: {'communityId': communityId, 'taskId': taskId},
        );
      } else {
        print("Clicked notification with unknown type or missing data: $data");
        // Podrías navegar a una pantalla por defecto o a la Home.
        // navigatorKey.currentState?.pushNamed('/');
      }
    } catch (e) {
      print('Error parsing or handling notification click payload: $e');
    }
  }

  // No es necesario get, subscribe, unsubscribe aquí si no los usas directamente en la app
  // a menos que quieras exponerlos.

  /// Enviar notificación a múltiples tokens (para administradores)
  Future<void> sendNotificationToMultipleTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Para cada token, enviar notificación individual
      // En un proyecto real, usarías un servicio backend para envío masivo
      for (final token in tokens) {
        try {
          await sendNotificationToToken(
            token: token,
            title: title,
            body: body,
            data: data,
          );
        } catch (e) {
          print('Error enviando notificación a token $token: $e');
          // Continuar con los demás tokens aunque uno falle
        }
      }
      print('Notificaciones enviadas a ${tokens.length} tokens');
    } catch (e) {
      print('Error enviando notificaciones múltiples: $e');
    }
  }

  /// Enviar notificación a un token específico
  Future<void> sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Aquí implementarías la lógica para enviar notificaciones push
      // usando tu backend o Firebase Functions
      // Por ahora, solo simulamos el envío
      print('Simulando envío de notificación a token: $token');
      print('Título: $title');
      print('Cuerpo: $body');
      print('Datos: $data');
      
      // En una implementación real, harías una llamada HTTP a tu backend
      // que use Firebase Admin SDK para enviar la notificación
    } catch (e) {
      print('Error enviando notificación individual: $e');
    }
  }
}
