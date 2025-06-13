// lib/screen/AIAssistantScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart'
    as task_utils; // ✅ IMPORTADO
import 'package:classroom_mejorado/core/services/ai_history_service.dart';

// Configuración de Gemini - REEMPLAZA CON TU API KEY
const String GEMINI_API_KEY = String.fromEnvironment('GEMINI_API_KEY');

enum MessageType { user, ai, suggestion, analysis, error }

enum AnalysisType { chat, workload, sentiment, productivity, deadlines, multimedia }

class AIMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>?
  taskSuggestion; // Solo para una tarea, obsoleto si se usa multipleTasks
  final List<Map<String, dynamic>>? multipleTasks;
  final Map<String, dynamic>?
  updateTaskData; // Para sugerencias de actualización
  final Map<String, dynamic>? deleteTaskData; // Para sugerencias de eliminación
  final Map<String, dynamic>? analysisData;
  final bool isStreaming;

  AIMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.taskSuggestion,
    this.multipleTasks,
    this.updateTaskData, // Añadido
    this.deleteTaskData, // Añadido
    this.analysisData,
    this.isStreaming = false,
  });
}

class CommunityData {
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> tasks;
  final Map<String, dynamic> communityInfo;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> files;

  CommunityData({
    required this.members,
    required this.messages,
    required this.tasks,
    required this.communityInfo,
    required this.images,
    required this.files,
  });
}

class AIAssistantScreen extends StatefulWidget {
  final String communityId;

  const AIAssistantScreen({super.key, required this.communityId});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AIMessage> _messages = [];

  bool _isTyping = false;
  bool _isAnalyzing = false;
  bool _isLoadingData = false;
  // String _currentStreamingMessage = ''; // Ya no es necesario, el mensaje se actualiza directamente

  CommunityData? _communityData;
  GenerativeModel? _model; // Puede ser null si la API key no está
  ChatSession? _chatSession; // Puede ser null

  final int _maxMessagesToAnalyze = 100;
  final int _maxTasksToAnalyze = 50;
  // final Duration _analysisTimeout = const Duration(minutes: 2); // No se usa actualmente
  
  // Variables para manejo de múltiples imágenes
  List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeAI(); // Solo inicializar el modelo, no la sesión de chat
    _loadCommunityData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Solo inicializar el modelo de IA, no la sesión de chat
  void _initializeAI() {
    if (GEMINI_API_KEY.isEmpty) {
      _showErrorOnUIThread(
        'Error de Configuración: GEMINI_API_KEY no encontrada. El asistente de IA está deshabilitado. Por favor, configura la variable de entorno.',
      );
      return;
    }

    try {
      _model = GenerativeModel(
        model:
            'gemini-2.5-flash-preview-05-20', // Modelo actualizado y más capaz
        apiKey: GEMINI_API_KEY,
        generationConfig: GenerationConfig(
          temperature: 0.7, // Un buen balance para creatividad y coherencia
          topK: 40,
          topP: 0.9,
          maxOutputTokens:
              4096, // Aumentado para respuestas más largas si es necesario
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );

      // Cargar historial después de inicializar el modelo
      _loadChatHistory();
    } catch (e) {
      print("Error inicializando Gemini: $e");
      _showErrorOnUIThread(
        'Error inicializando Gemini: $e. El asistente podría no funcionar.',
      );
    }
  }

  // Crear sesión de chat con historial específico
  void _createChatSession(List<Content> history) {
    if (_model == null) return;
    
    try {
      _chatSession = _model!.startChat(history: history);
    } catch (e) {
      print("Error creando sesión de chat: $e");
      // Fallback: crear sesión solo con prompt del sistema
      _chatSession = _model!.startChat(history: [Content.text(_getSystemPrompt())]);
    }
  }

  void _initializeWelcomeMessage() {
    // Solo añadir mensaje de bienvenida si Gemini se inicializó y no hay mensajes cargados
    if (_model != null && _chatSession != null && _messages.isEmpty) {
      _messages.add(
        AIMessage(
          id: 'initial-welcome',
          content:
              '¡Hola! Soy tu asistente de IA avanzado para gestión de tareas. Estoy cargando los datos de tu comunidad para ofrecerte análisis inteligentes y sugerencias personalizadas.\n\nPuedo ayudarte con:\n\n🔍 **Análisis Profundo**\n• Análisis de conversaciones del chat\n• Evaluación de carga de trabajo\n• Análisis de sentimientos del equipo\n• Métricas de productividad\n\n📋 **Gestión Inteligente**\n• Creación automática de tareas\n• Asignaciones optimizadas\n• Planificación de deadlines\n• Sugerencias de mejora\n\n¿Qué te gustaría explorar primero?',
          type: MessageType.ai,
          timestamp: DateTime.now(),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  // Cargar historial de chat desde Firebase
  Future<void> _loadChatHistory() async {
    try {
      setState(() {
        _isLoadingData = true;
      });

      print('Loading chat history for community: ${widget.communityId}');
      final history = await AIHistoryService.getAIChatHistory(widget.communityId);
      print('Loaded ${history.length} messages from history');
      
      if (history.isNotEmpty) {
        final List<AIMessage> loadedMessages = [];
        
        for (final messageData in history) {
          final messageType = messageData['messageType'] as String;
          final content = messageData['content'] as String? ?? '';
          final timestamp = messageData['timestamp'] as Timestamp?;
          
          if (messageType == 'user') {
            loadedMessages.add(
              AIMessage(
                id: messageData['id'],
                content: content,
                type: MessageType.user,
                timestamp: timestamp?.toDate() ?? DateTime.now(),
              ),
            );
          } else if (messageType == 'ai') {
            loadedMessages.add(
              AIMessage(
                id: messageData['id'],
                content: content,
                type: MessageType.ai,
                timestamp: timestamp?.toDate() ?? DateTime.now(),
                taskSuggestion: messageData['taskSuggestion'],
                multipleTasks: messageData['multipleTasks'] != null 
                    ? List<Map<String, dynamic>>.from(messageData['multipleTasks'])
                    : null,
                updateTaskData: messageData['updateTaskData'],
                deleteTaskData: messageData['deleteTaskData'],
                analysisData: messageData['analysisData'],
              ),
            );
          }
        }
        
        setState(() {
          _messages.clear();
          _messages.addAll(loadedMessages);
        });

        // Crear sesión de chat con historial completo
        _createChatSessionWithHistory(loadedMessages);
      } else {
        // No hay historial, crear sesión nueva y mostrar mensaje de bienvenida
        _createChatSession([Content.text(_getSystemPrompt())]);
        _initializeWelcomeMessage();
      }
      
    } catch (e) {
      print('Error loading chat history: $e');
      // Si hay error, crear sesión básica y mostrar mensaje de bienvenida
      _createChatSession([Content.text(_getSystemPrompt())]);
      _initializeWelcomeMessage();
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  // Crear sesión de chat con historial de mensajes específico
  void _createChatSessionWithHistory(List<AIMessage> messages) {
    if (_model == null) return;

    try {
      // Crear historial para Gemini (limitar a los últimos 30 mensajes para mantener más contexto)
      final recentMessages = messages.length > 30 
          ? messages.sublist(messages.length - 30)
          : messages;

      final List<Content> history = [Content.text(_getSystemPrompt())];
      
      for (final message in recentMessages) {
        if (message.type == MessageType.user) {
          history.add(Content.text(message.content));
        } else if (message.type == MessageType.ai) {
          history.add(Content.model([TextPart(message.content)]));
        }
      }

      // Crear nueva sesión de chat con historial
      _chatSession = _model!.startChat(history: history);
      print('Chat session created with ${history.length} messages in history');
    } catch (e) {
      print('Error creating chat session with history: $e');
      // Si falla, crear sesión nueva sin historial
      _createChatSession([Content.text(_getSystemPrompt())]);
    }
  }

  // En AIAssistantScreen.dart
  String _getSystemPrompt() {
    return '''
  Eres un asistente de IA especializado en gestión de tareas y análisis de comunidades. Tu trabajo es:

  1.  ANALIZAR conversaciones de chat para identificar tareas pendientes, problemas y oportunidades.
  2.  SUGERIR tareas específicas con asignaciones inteligentes. Asegúrate de que `assignedToId` sea un UID válido de un miembro de la comunidad si lo conoces, y `assignedToName` el nombre correspondiente.
  3.  SUGERIR ACTUALIZACIONES a tareas existentes si la conversación lo indica (ej. cambio de prioridad, fecha, asignado).
  4.  SUGERIR ELIMINACIONES de tareas si se indica que ya no son necesarias o fueron un error.
  5.  EVALUAR carga de trabajo y disponibilidad de miembros.
  6.  PROPORCIONAR insights sobre productividad y colaboración.

  CONTEXTO: Trabajas con una comunidad/equipo que usa una app de gestión de tareas. Tienes acceso a:
  -   Mensajes del chat de la comunidad.
  -   Tareas existentes y su estado (ej: 'por hacer', 'en progreso', 'completado'), incluyendo sus IDs.
  -   Información de miembros (nombre, ID, tareas activas, disponibilidad).
  -   Fechas y deadlines.

  FORMATO DE RESPUESTA:
  -   Para sugerencias de NUEVAS tareas, usa JSON con esta estructura. Trata de ser lo más completo posible.
      {
        "type": "task_suggestion", // Para crear nuevas tareas
        "tasks": [ // Siempre devuelve una lista, incluso si es una sola tarea
          {
            "title": "Título claro y conciso (máx 100 chars)",
            "description": "Descripción detallada y accionable (máx 500 chars)",
            "priority": "Baja|Media|Alta|Urgente", // Usa estos strings exactos
            "assignedToId": "uid_del_usuario_sugerido_o_null",
            "assignedToName": "Nombre del usuario sugerido o 'Sin asignar'",
            "dueDate": "YYYY-MM-DD", // Formato de fecha, o null si no aplica
            "reason": "Explicación breve de por qué esta tarea es necesaria y cómo se identificó.",
            "confidence": 0.85
          }
        ]
      }

  -   Para sugerencias de ACTUALIZACIÓN de tareas existentes:
      {
        "type": "update_task_suggestion",
        "taskId": "id_de_la_tarea_existente_a_actualizar", // MUY IMPORTANTE: ID de la tarea
        "updates": { // Objeto con los campos a actualizar y sus nuevos valores
          "title": "Nuevo título si cambia",
          "description": "Nueva descripción si cambia",
          "priority": "Baja|Media|Alta|Urgente", // Nuevo valor si cambia
          "assignedToId": "nuevo_uid_asignado_o_null",
          "assignedToName": "Nuevo nombre asignado o 'Sin asignar'",
          "dueDate": "YYYY-MM-DD", // Nueva fecha o null para quitarla
          "state": "por hacer|en progreso|por revisar|completado" // Nuevo estado si cambia (usa los firestoreName)
          // Solo incluye los campos que realmente necesitan actualizarse
        },
        "reason": "Explicación de por qué se sugiere esta actualización.",
        "confidence": 0.90
      }

  -   Para sugerencias de ELIMINACIÓN de tareas existentes:
      {
        "type": "delete_task_suggestion",
        "taskId": "id_de_la_tarea_existente_a_eliminar", // MUY IMPORTANTE: ID de la tarea
        "taskTitle": "Título de la tarea a eliminar (para confirmación)",
        "reason": "Explicación de por qué se sugiere esta eliminación.",
        "confidence": 0.75
      }

  -   Para análisis, usa JSON con esta estructura:
      {
        "type": "analysis",
        "summary": "Resumen ejecutivo del análisis solicitado.",
        "insights": ["Insight clave 1.", "Insight clave 2.", "..."],
        "metrics": {"metrica_1": "valor_1", "metrica_2": "valor_2"},
        "recommendations": ["Recomendación accionable 1.", "Recomendación accionable 2.", "..."]
      }

  REGLAS IMPORTANTES:
  -   Sé específico y ofrece sugerencias que sean directamente utilizables.
  -   Cuando sugieras una actualización, en el objeto `updates` solo incluye los campos que realmente necesitan cambiar.
  -   Considera la carga de trabajo actual de los miembros al sugerir asignaciones.
  -   Basa las asignaciones en habilidades (si se conocen) y disponibilidad.
  -   Usa fechas realistas para `dueDate`. Si no se especifica un plazo, puedes omitir `dueDate` o ponerlo como `null`.
  -   Explica brevemente tu razonamiento en el campo `reason`.
  -   Mantén un tono profesional pero amigable y colaborativo.
  -   Si el usuario pide algo que no puedes hacer, explícalo amablemente.
  -   Asegúrate que los valores de `priority` sean exactamente "Baja", "Media", "Alta", o "Urgente".
  -   Para el campo `state` en actualizaciones, usa los valores literales: "por hacer", "en progreso", "por revisar", "completado".
  -   El `title` no debe exceder los 100 caracteres y `description` los 500 caracteres.
  -   Para actualizaciones y eliminaciones, ES CRUCIAL que incluyas el `taskId` correcto de la tarea existente. Puedes obtenerlo del contexto de "TAREAS ACTUALES" buscando la etiqueta "ID_TAREA". Tu tienes acceso, el usuario no, asi que no le pidas y tu busques, ya se te proporcionó, simplemente búscala".
  ''';
  }

  Future<void> _loadCommunityData() async {
    if (_model == null) return; // No cargar si Gemini no está listo

    setState(() => _isLoadingData = true);
    try {
      final members = await _fetchCommunityMembers();
      final messages = await _fetchCommunityMessages();
      final tasks = await _fetchCommunityTasks();
      final communityInfo = await _fetchCommunityInfo();
      final images = await _fetchCommunityImages();
      final files = await _fetchCommunityFiles();

      _communityData = CommunityData(
        members: members,
        messages: messages,
        tasks: tasks,
        communityInfo: communityInfo,
        images: images,
        files: files,
      );

      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content:
              '✅ **Datos cargados exitosamente**\n\n📊 **Resumen de la comunidad:**\n• ${members.length} miembros activos\n• ${messages.length} mensajes recientes analizados\n• ${tasks.length} tareas en seguimiento\n• 📷 ${images.length} imágenes compartidas\n• 📎 ${files.length} archivos compartidos\n\n¡Listo para asistirte! Puedo analizar todo el contenido incluyendo imágenes y archivos del chat.',
          type: MessageType.ai,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content:
              '❌ Error cargando datos de la comunidad: $e\n\nPuedo seguir funcionando con capacidades limitadas, pero los análisis y sugerencias podrían no ser precisos.',
          type: MessageType.error,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
      _scrollToBottom();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityMembers() async {
    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    if (!communityDoc.exists) return [];

    final List<dynamic> memberUidsDyn = communityDoc.data()?['members'] ?? [];
    final List<String> memberUids = memberUidsDyn
        .map((uid) => uid.toString())
        .toList();

    if (memberUids.isEmpty) return [];

    List<Map<String, dynamic>> membersData = [];
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: memberUids)
        .get();

    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final userTasks = await _getUserActiveTasks(userDoc.id);
      membersData.add({
        'uid': userDoc.id,
        'displayName':
            userData['name'] ??
            userData['displayName'] ??
            'Usuario Desconocido',
        'photoURL': userData['photoURL'],
        'email': userData['email'],
        'activeTasks': userTasks.length,
        'lastActive': userData['lastActive'] is Timestamp
            ? (userData['lastActive'] as Timestamp).toDate().toIso8601String()
            : null,
        'skills': userData['skills'] ?? [],
        'availability': userData['availability'] ?? 'disponible',
      });
    }
    return membersData;
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityMessages() async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_maxMessagesToAnalyze)
        .get();
    return messagesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'text': data['text'] ?? '',
        'senderId': data['senderId'] ?? '',
        'senderUser': data['senderUser'] ?? '',
        'timestamp': data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate().toIso8601String()
            : null,
        // Agregar información de archivos e imágenes
        'isFile': data['isFile'] ?? false,
        'fileType': data['fileType'],
        'fileUrl': data['fileUrl'],
        'fileName': data['fileName'],
        'fileSize': data['fileSize'],
      };
    }).toList();
  }

  // Método para recolectar imágenes del chat de la comunidad
  Future<List<Map<String, dynamic>>> _fetchCommunityImages() async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('messages')
        .where('isFile', isEqualTo: true)
        .where('fileType', isEqualTo: 'image')
        .orderBy('timestamp', descending: true)
        .limit(20) // Limitar a las últimas 20 imágenes para no sobrecargar la IA
        .get();
    
    return messagesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'fileUrl': data['fileUrl'],
        'fileName': data['fileName'],
        'senderUser': data['senderUser'] ?? 'Usuario desconocido',
        'timestamp': data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate().toIso8601String()
            : null,
      };
    }).toList();
  }

  // Método para recolectar archivos del chat de la comunidad
  Future<List<Map<String, dynamic>>> _fetchCommunityFiles() async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('messages')
        .where('isFile', isEqualTo: true)
        .where('fileType', isEqualTo: 'file')
        .orderBy('timestamp', descending: true)
        .limit(10) // Limitar archivos para no sobrecargar
        .get();
    
    return messagesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'fileUrl': data['fileUrl'],
        'fileName': data['fileName'] ?? 'Archivo sin nombre',
        'fileSize': data['fileSize'],
        'senderUser': data['senderUser'] ?? 'Usuario desconocido',
        'timestamp': data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate().toIso8601String()
            : null,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityTasks() async {
    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('tasks')
        .limit(
          _maxTasksToAnalyze,
        ) // Considerar también ordenar por `updatedAt` o `createdAt`
        .get();
    return tasksSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'description': data['description'] ?? '',
        'state': data['state'] ?? task_utils.TaskState.toDo.firestoreName,
        'priority':
            data['priority'] ?? task_utils.TaskPriority.medium.displayName,
        'assignedToId': data['assignedToId'],
        'assignedToName': data['assignedToName'] ?? data['assignedToUser'],
        'assignedToImageUrl': data['assignedToImageUrl'],
        'createdAt': data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
            : null,
        'dueDate': data['dueDate'] is Timestamp
            ? (data['dueDate'] as Timestamp).toDate().toIso8601String()
            : null,
        'updatedAt': data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
            : null,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> _fetchCommunityInfo() async {
    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    return communityDoc.exists ? communityDoc.data()! : {};
  }

  Future<List<Map<String, dynamic>>> _getUserActiveTasks(String userId) async {
    final activeStates = [
      task_utils.TaskState.toDo.firestoreName,
      task_utils.TaskState.doing.firestoreName,
      // Añade otros nombres si usas diferentes en la DB, por ej. "to_do", "doing"
      "to_do", "doing",
    ];
    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('tasks')
        .where('assignedToId', isEqualTo: userId)
        .where(
          'state',
          whereIn: activeStates.toSet().toList(),
        ) // toSet to remove duplicates
        .get();
    return tasksSnapshot.docs.map((doc) => doc.data()).toList();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    if (_model == null || _chatSession == null) {
      _showErrorOnUIThread(
        'El asistente IA no está inicializado. No se pueden enviar mensajes.',
      );
      return;
    }

    final userMessage = AIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: _messageController.text.trim(),
      type: MessageType.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true; // El indicador de "escribiendo..." general se activa
    });

    // Guardar el mensaje del usuario en el chat persistente
    _saveMessageToChat(userMessage);

    final userInput = _messageController.text.trim();
    _messageController.clear();
    _scrollToBottom();

    _generateGeminiResponse(userInput);
  }

  // Método para seleccionar imagen desde galería
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedImage != null) {
        setState(() {
          _selectedImages.add(File(pickedImage.path));
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagen añadida (${_selectedImages.length} total). Usa el botón de imagen para analizarlas.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorOnUIThread('Error al seleccionar imagen: $e');
    }
  }

  // Método para tomar foto con cámara
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (pickedImage != null) {
        setState(() {
          _selectedImages.add(File(pickedImage.path));
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto añadida (${_selectedImages.length} total). Usa el botón de imagen para analizarlas.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorOnUIThread('Error al tomar foto: $e');
    }
  }

  // Método para seleccionar múltiples imágenes de galería
  Future<void> _pickMultipleImagesFromGallery() async {
    try {
      final List<XFile> pickedImages = await _imagePicker.pickMultiImage(
        imageQuality: 80,
      );
      
      if (pickedImages.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedImages.map((xfile) => File(xfile.path)));
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedImages.length} imágenes añadidas (${_selectedImages.length} total). Usa el botón de imagen para analizarlas.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorOnUIThread('Error al seleccionar imágenes: $e');
    }
  }

  // Método para analizar todas las imágenes seleccionadas
  Future<void> _analyzeSelectedImages() async {
    if (_selectedImages.isEmpty || _model == null || _chatSession == null) {
      _showErrorOnUIThread('Error: No hay imágenes seleccionadas o IA no disponible');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _isTyping = true;
    });

    try {
      // Agregar mensaje del usuario indicando que subió imágenes
      final userMessage = AIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '📷 ${_selectedImages.length} imagen(es) subida(s) para análisis conjunto',
        type: MessageType.user,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(userMessage);
      });

      // Crear lista de partes multimodales con todas las imágenes
      List<Part> contentParts = [];
      
      // Agregar prompt para análisis conjunto
      contentParts.add(TextPart(
        'Analiza estas ${_selectedImages.length} imágenes de forma conjunta. Proporciona:\n'
        '1. Un resumen general de lo que muestran todas las imágenes\n'
        '2. Patrones o temas comunes entre ellas\n'
        '3. Diferencias importantes que observes\n'
        '4. Cualquier insights o observaciones relevantes\n'
        '5. Si parecen estar relacionadas (secuencia, proyecto, etc.)\n'
      ));

      // Añadir todas las imágenes
      for (int i = 0; i < _selectedImages.length; i++) {
        final imageBytes = await _selectedImages[i].readAsBytes();
        
        contentParts.add(DataPart('image/jpeg', imageBytes));
      }

      // Enviar a la IA para análisis conjunto
      final response = await _chatSession!.sendMessage(Content.multi(contentParts));
      final aiResponseText = response.text ?? 'No pude analizar las imágenes.';

      // Agregar respuesta de la IA
      final aiMessage = AIMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        content: aiResponseText,
        type: MessageType.ai,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isTyping = false;
        _selectedImages.clear(); // Limpiar imágenes después del análisis
      });

      _scrollToBottom();

    } catch (e) {
      setState(() {
        _isTyping = false;
        _selectedImages.clear();
      });
      _showErrorOnUIThread('Error analizando imágenes: $e');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // Método para limpiar las imágenes seleccionadas
  void _clearSelectedImages() {
    setState(() {
      _selectedImages.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imágenes eliminadas de la selección'),
        duration: Duration(seconds: 1),
      ),
    );
  }


  // Método para mostrar opciones de imagen
  void _showImagePickerOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Análisis de Imágenes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elige cómo analizar las imágenes',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.analytics, color: Colors.green),
                title: Text('Analizar todas las imágenes del chat'),
                subtitle: Text('Análisis automático del contenido multimedia'),
                onTap: () {
                  Navigator.pop(context);
                  _performDeepAnalysis(AnalysisType.multimedia);
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.photo_library, color: theme.colorScheme.primary),
                title: Text('Una imagen de galería'),
                subtitle: Text('Seleccionar imagen individual'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: theme.colorScheme.secondary),
                title: Text('Múltiples imágenes'),
                subtitle: Text('Seleccionar varias imágenes juntas'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleImagesFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: theme.colorScheme.tertiary),
                title: Text('Cámara'),
                subtitle: Text('Tomar nueva foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              if (_selectedImages.isNotEmpty) ...[
                Divider(),
                ListTile(
                  leading: Icon(Icons.psychology, color: Colors.green),
                  title: Text('Analizar imágenes seleccionadas'),
                  subtitle: Text('${_selectedImages.length} imagen(es)'),
                  onTap: () {
                    Navigator.pop(context);
                    _analyzeSelectedImages();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.clear, color: Colors.red),
                  title: Text('Limpiar selección'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearSelectedImages();
                  },
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateGeminiResponse(String userInput) async {
    if (_chatSession == null) {
      _handleGeminiError("Chat session no inicializada.");
      return;
    }
    try {
      final context = _prepareCommunityContext();
      final fullPrompt =
          'CONTEXTO DE LA COMUNIDAD:\n$context\n\nSOLICITUD DEL USUARIO: $userInput\n\nAnaliza la solicitud y proporciona una respuesta útil. Si es una solicitud de análisis o creación de tareas, usa el formato JSON especificado en el prompt del sistema.';

      final responseStream = _chatSession!.sendMessageStream(
        Content.text(fullPrompt),
      );
      String fullResponseText = '';
      String currentMessageId = DateTime.now().millisecondsSinceEpoch
          .toString();
      bool firstChunk = true;

      setState(() {
        // Dejar el indicador _isTyping = true hasta que llegue el primer chunk
        _isTyping = true;
      });

      await for (final chunk in responseStream) {
        final text = chunk.text ?? '';
        fullResponseText += text;

        if (firstChunk) {
          setState(() {
            _isTyping = false; // Quitar el indicador general
            _messages.add(
              AIMessage(
                id: currentMessageId,
                content: fullResponseText,
                type: MessageType.ai, // Tipo por defecto, se ajustará después
                timestamp: DateTime.now(),
                isStreaming: true,
              ),
            );
          });
          firstChunk = false;
        } else {
          setState(() {
            int msgIndex = _messages.indexWhere(
              (m) => m.id == currentMessageId,
            );
            if (msgIndex != -1) {
              _messages[msgIndex] = AIMessage(
                id: _messages[msgIndex].id,
                content: fullResponseText,
                type: _messages[msgIndex].type,
                timestamp: _messages[msgIndex].timestamp,
                isStreaming: true,
              );
            }
          });
        }
        _scrollToBottom();
      }
      // Asegurarse que _isTyping está en false al final del stream
      if (mounted) setState(() => _isTyping = false);

      // Procesar la respuesta completa y actualizar el mensaje existente
      await _processFinalGeminiResponse(fullResponseText, currentMessageId);
    } catch (e) {
      if (mounted) setState(() => _isTyping = false);
      _handleGeminiError(e);
      // Si había un mensaje en streaming, marcarlo como error o eliminarlo
      int streamingMsgIndex = _messages.indexWhere(
        (m) => m.isStreaming && m.type == MessageType.ai,
      );
      if (streamingMsgIndex != -1) {
        setState(() {
          _messages[streamingMsgIndex] = AIMessage(
            id: _messages[streamingMsgIndex].id,
            content: "Error al generar respuesta: ${e.toString()}",
            type: MessageType.error,
            timestamp: _messages[streamingMsgIndex].timestamp,
            isStreaming: false,
          );
        });
      }
    }
  }

  String _prepareCommunityContext() {
    if (_communityData == null) {
      return 'Datos de la comunidad no disponibles en este momento.';
    }
    final members = _communityData!.members
        .map(
          (m) =>
              '- ${m['displayName']} (ID: ${m['uid']}, Tareas Activas: ${m['activeTasks']}, Disponibilidad: ${m['availability']})',
        )
        .join('\n');

    final recentMessages = _communityData!.messages
        .take(15)
        .map((m) {
          // Limitar a 15-20 mensajes
          final timeStr = m['timestamp'] != null
              ? DateFormat('dd/MM HH:mm').format(DateTime.parse(m['timestamp']))
              : 'Fecha desc.';
          return '[$timeStr] ${m['senderUser'] ?? m['senderId']}: ${m['text']}';
        })
        .join('\n');

    final currentTasks = _communityData!.tasks
        .take(15)
        .map((t) {
          // Limitar a 15-20 tareas
          final taskId = t['id'] ?? 'ID_DESCONOCIDO';
          final assigned = t['assignedToName'] ?? 'Nadie';
          final dueDateStr = t['dueDate'] != null
              ? DateFormat('dd/MM/yy').format(DateTime.parse(t['dueDate']))
              : 'Sin fecha';
          return '- Título: ${t['title']} (ID_TAREA: $taskId, Estado: ${t['state']}, Prioridad: ${t['priority']}, Asignado: $assigned, Vence: $dueDateStr)';
        })
        .join('\n');

    final toDoCount = _communityData!.tasks
        .where(
          (t) =>
              t['state'] == task_utils.TaskState.toDo.firestoreName ||
              t['state'] == "to_do",
        )
        .length;
    final doingCount = _communityData!.tasks
        .where(
          (t) =>
              t['state'] == task_utils.TaskState.doing.firestoreName ||
              t['state'] == "doing",
        )
        .length;

    return '''
MIEMBROS DE LA COMUNIDAD (${_communityData!.members.length} total):
$members

MENSAJES RECIENTES DEL CHAT (últimos ${_communityData!.messages.take(15).length}):
$recentMessages

TAREAS ACTUALES (primeras ${_communityData!.tasks.take(15).length} de ${_communityData!.tasks.length} total):
$currentTasks

MÉTRICAS RESUMEN:
- Total miembros: ${_communityData!.members.length}
- Tareas "Por Hacer": $toDoCount
- Tareas "En Progreso": $doingCount
''';
  }

  Future<void> _processFinalGeminiResponse(
    String fullResponseText,
    String messageId,
  ) async {
    setState(() {
      int msgIndex = _messages.indexWhere((m) => m.id == messageId);
      if (msgIndex == -1) {
        // Mensaje no encontrado, podría haber sido un error
        print(
          "Error: Mensaje con ID $messageId no encontrado para procesar respuesta final.",
        );
        // Añadir como nuevo mensaje si no existe, aunque esto es un fallback
        _messages.add(
          AIMessage(
            id: messageId,
            content: fullResponseText,
            type: MessageType.ai,
            timestamp: DateTime.now(),
            isStreaming: false,
          ),
        );
        _processParsedContent(
          fullResponseText,
          _messages.last,
        ); // Procesar el contenido del nuevo mensaje
        return;
      }

      // Actualizar el mensaje existiente con el contenido final y marcar isStreaming false
      AIMessage existingMessage = _messages[msgIndex];
      _messages[msgIndex] = AIMessage(
        id: existingMessage.id,
        content: fullResponseText, // El texto completo ya está aquí
        type: existingMessage.type, // El tipo se determinará al parsear
        timestamp: existingMessage.timestamp,
        isStreaming: false, // Importante: streaming ha terminado
      );
      _processParsedContent(
        fullResponseText,
        _messages[msgIndex],
      ); // Ahora procesar el contenido
    });
    
    // Guardar el mensaje de IA en el chat persistente
    final aiMessage = _messages.firstWhere((m) => m.id == messageId);
    await _saveMessageToChat(aiMessage);
    
    _scrollToBottom();
  }

  // Guardar mensaje en el chat persistente
  Future<void> _saveMessageToChat(AIMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in, cannot save message');
        return;
      }

      print('Saving message: ${message.content.substring(0, math.min(50, message.content.length))}...');
      
      final messageId = await AIHistoryService.saveAIMessage(
        communityId: widget.communityId,
        content: message.content,
        messageType: message.type == MessageType.user ? 'user' : 'ai',
        userId: user.uid,
        userName: user.displayName ?? 'Usuario',
        userPhotoURL: user.photoURL,
        taskSuggestion: message.taskSuggestion,
        multipleTasks: message.multipleTasks,
        updateTaskData: message.updateTaskData,
        deleteTaskData: message.deleteTaskData,
        analysisData: message.analysisData,
      );
      
      print('Message saved with ID: $messageId');
    } catch (e) {
      print('Error saving message to chat: $e');
      // No mostrar error al usuario, es una funcionalidad secundaria
    }
  }

  // Mostrar diálogo para limpiar el chat
  Future<void> _showClearChatDialog() async {
    final theme = Theme.of(context);
    
    // Verificar si el usuario es admin
    bool isAdmin = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final communityDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .get();
        
        if (communityDoc.exists) {
          final data = communityDoc.data()!;
          isAdmin = data['ownerId'] == user.uid || 
                   (data['admins'] as List?)?.contains(user.uid) == true;
        }
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solo los administradores pueden limpiar el chat'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Limpiar chat',
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres limpiar todo el historial del chat con la IA? Esta acción no se puede deshacer y será visible para todos los miembros.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: fontFamilyPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Limpiar',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AIHistoryService.clearChatHistory(widget.communityId);
        setState(() {
          _messages.clear();
        });
        _initializeWelcomeMessage();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat limpiado exitosamente'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al limpiar el chat: $e'),
              backgroundColor: theme.colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // En AIAssistantScreen.dart ... dentro de _AIAssistantScreenState

  Future<void> _handleUpdateTaskSuggestion(
    Map<String, dynamic> updateSuggestion,
  ) async {
    final taskId = updateSuggestion['taskId'] as String?;
    final updates = updateSuggestion['updates'] as Map<String, dynamic>?;
    final reason = updateSuggestion['reason'] as String?;

    if (taskId == null || updates == null || updates.isEmpty) {
      _showErrorOnUIThread(
        'Sugerencia de actualización inválida: faltan datos.',
      );
      return;
    }

    // Confirmación del usuario
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar Actualización de Tarea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SizedBox(height: 16),
            Text(
              'Cambios propuestos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...updates.entries.map(
              (entry) => Text('  • ${entry.key}: ${entry.value}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Actualizar Tarea'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Convertir priority y state a los formatos correctos si están presentes
      Map<String, dynamic> finalUpdates = Map.from(
        updates,
      ); // Copia para modificar

      if (finalUpdates.containsKey('priority')) {
        finalUpdates['priority'] = task_utils.TaskUtils.parseTaskPriority(
          finalUpdates['priority'] as String?,
        ).displayName;
      }
      if (finalUpdates.containsKey('state')) {
        finalUpdates['state'] = task_utils.TaskUtils.parseTaskState(
          finalUpdates['state'] as String?,
        ).firestoreName;
      }
      if (finalUpdates.containsKey('dueDate') &&
          finalUpdates['dueDate'] != null) {
        try {
          finalUpdates['dueDate'] = Timestamp.fromDate(
            DateTime.parse(finalUpdates['dueDate'] as String),
          );
        } catch (e) {
          print(
            "Error parsing dueDate for update: ${finalUpdates['dueDate']}. Removing it.",
          );
          finalUpdates.remove('dueDate'); // O manejar el error de otra forma
          _showErrorOnUIThread(
            'Formato de fecha inválido para la actualización: ${finalUpdates['dueDate']}. No se actualizará la fecha.',
          );
        }
      }

      bool success = await task_utils.TaskUtils.updateTaskDetails(
        communityId: widget.communityId,
        taskId: taskId,
        updateData: finalUpdates,
      );

      if (success) {
        _showSuccessOnUIThread('Tarea actualizada exitosamente.');
        _loadCommunityData(); // Recargar datos para ver los cambios
      } else {
        _showErrorOnUIThread('Error al actualizar la tarea.');
      }
    } else {
      _showInfo('Actualización cancelada por el usuario.');
    }
  }

  Future<void> _handleDeleteTaskSuggestion(
    Map<String, dynamic> deleteSuggestion,
  ) async {
    final taskId = deleteSuggestion['taskId'] as String?;
    final taskTitle =
        deleteSuggestion['taskTitle']
            as String?; // Para mostrar en la confirmación
    final reason = deleteSuggestion['reason'] as String?;

    if (taskId == null) {
      _showErrorOnUIThread(
        'Sugerencia de eliminación inválida: falta el ID de la tarea.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar Eliminación de Tarea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La IA sugiere eliminar la tarea${taskTitle != null ? ': "$taskTitle"' : ' con ID: $taskId'}.',
            ),
            if (reason != null) ...[
              SizedBox(height: 8),
              Text(
                'Razón: $reason',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            SizedBox(height: 16),
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar Tarea',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool success = await task_utils.TaskUtils.deleteTask(
        communityId: widget.communityId,
        taskId: taskId,
      );
      if (success) {
        _showSuccessOnUIThread('Tarea eliminada exitosamente.');
        _loadCommunityData(); // Recargar datos
      } else {
        _showErrorOnUIThread('Error al eliminar la tarea.');
      }
    } else {
      _showInfo('Eliminación cancelada por el usuario.');
    }
  }

  void _processParsedContent(String rawResponse, AIMessage messageToUpdate) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawResponse);
      final textContent = _extractTextFromResponse(rawResponse);

      Map<String, dynamic>? jsonData;
      MessageType newType = MessageType.ai;
      List<Map<String, dynamic>>? multipleTasksData;
      Map<String, dynamic>? updateSuggestionData; // Nuevo
      Map<String, dynamic>? deleteSuggestionData; // Nuevo
      Map<String, dynamic>? analysisDataMap;

      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        jsonData = json.decode(jsonStr) as Map<String, dynamic>;

        String? suggestionType = jsonData['type'] as String?;

        if (suggestionType == 'task_suggestion' && jsonData['tasks'] is List) {
          newType =
              MessageType.suggestion; // Sigue siendo suggestion para creación
          multipleTasksData = List<Map<String, dynamic>>.from(
            jsonData['tasks'],
          );
        } else if (suggestionType == 'update_task_suggestion') {
          newType = MessageType
              .suggestion; // Reutilizamos el tipo, pero el dato es diferente
          updateSuggestionData =
              jsonData; // Guardamos todo el JSON de actualización
        } else if (suggestionType == 'delete_task_suggestion') {
          newType = MessageType.suggestion; // Reutilizamos el tipo
          deleteSuggestionData =
              jsonData; // Guardamos todo el JSON de eliminación
        } else if (suggestionType == 'analysis') {
          newType = MessageType.analysis;
          analysisDataMap = jsonData;
        }
      }

      int msgIndex = _messages.indexWhere((m) => m.id == messageToUpdate.id);
      if (msgIndex != -1) {
        _messages[msgIndex] = AIMessage(
          id: messageToUpdate.id,
          content: textContent.isNotEmpty
              ? textContent
              : (jsonData == null ? rawResponse : ""),
          type: newType,
          timestamp: messageToUpdate.timestamp,
          multipleTasks: multipleTasksData,
          updateTaskData: updateSuggestionData, // Añadido
          deleteTaskData: deleteSuggestionData, // Añadido
          analysisData: analysisDataMap,
          isStreaming: false,
        );
      } else {
        print(
          "Error: No se pudo encontrar el mensaje ${messageToUpdate.id} para actualizar post-parseo.",
        );
      }
    } catch (e) {
      print(
        "Error parseando la respuesta de Gemini o actualizando mensaje: $e. Respuesta: $rawResponse",
      );
      int msgIndex = _messages.indexWhere((m) => m.id == messageToUpdate.id);
      if (msgIndex != -1) {
        _messages[msgIndex] = AIMessage(
          id: messageToUpdate.id,
          content: rawResponse,
          type: MessageType.ai,
          timestamp: messageToUpdate.timestamp,
          isStreaming: false,
        );
      }
    }
  }

  String _extractTextFromResponse(String response) {
    // Extraer texto antes del JSON, o después si el texto antes es muy corto o inexistente.
    // Esto asume que el JSON es la parte "estructurada" y el texto es el acompañamiento.
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    if (jsonMatch != null) {
      String beforeJson = response.substring(0, jsonMatch.start).trim();
      String afterJson = response.substring(jsonMatch.end).trim();

      if (beforeJson.isNotEmpty && beforeJson.length > 10) {
        // Si hay texto significativo antes
        return beforeJson;
      } else if (afterJson.isNotEmpty) {
        // Si no, y hay texto después
        return afterJson;
      }
      return beforeJson; // Fallback al texto de antes (podría estar vacío)
    }
    return response.trim(); // Si no hay JSON, toda la respuesta es texto
  }

  void _handleGeminiError(dynamic error) {
    if (!mounted) return;
    String errorMessage = 'Error de comunicación con IA: ';
    if (error.toString().contains('API_KEY')) {
      errorMessage +=
          'Clave de API inválida o no configurada. Por favor configura GEMINI_API_KEY.';
    } else if (error.toString().contains('quota')) {
      errorMessage += 'Límite de uso excedido. Intenta más tarde.';
    } else if (error.toString().contains('network') ||
        error.toString().contains('SocketException')) {
      errorMessage += 'Error de conexión. Verifica tu internet.';
    } else {
      errorMessage += error.toString();
    }

    setState(() {
      _isTyping = false; // Detener indicador general
      // Buscar si hay un mensaje de IA en streaming para actualizarlo a error
      int streamingMsgIndex = _messages.lastIndexWhere(
        (m) => m.isStreaming && m.type == MessageType.ai,
      );
      if (streamingMsgIndex != -1) {
        _messages[streamingMsgIndex] = AIMessage(
          id: _messages[streamingMsgIndex].id,
          content: errorMessage,
          type: MessageType.error,
          timestamp: _messages[streamingMsgIndex].timestamp,
          isStreaming: false,
        );
      } else {
        // Si no, añadir un nuevo mensaje de error
        _messages.add(
          AIMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: errorMessage,
            type: MessageType.error,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _scrollToBottom();
  }

  Future<void> _performDeepAnalysis(AnalysisType type) async {
    if (_model == null || _chatSession == null) {
      _showErrorOnUIThread(
        'El asistente IA no está inicializado. No se pueden realizar análisis.',
      );
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _messages.add(
        AIMessage(
          // Mensaje placeholder
          id: 'analysis_placeholder_${DateTime.now().millisecondsSinceEpoch}',
          content:
              '🧠 Realizando análisis profundo de ${type.name}... Esto podría tardar un momento.',
          type: MessageType.ai, // Placeholder
          timestamp: DateTime.now(),
          isStreaming: true, // Para el estilo de "typing"
        ),
      );
      _scrollToBottom();
    });

    try {
      String analysisPrompt = _getAnalysisPrompt(type);
      final context = _prepareCommunityContext();
      
      // Caso especial para análisis multimedia: incluir imágenes del chat
      if (type == AnalysisType.multimedia) {
        await _performMultimediaAnalysis(analysisPrompt, context);
        return;
      }
      
      final fullPrompt =
          '$analysisPrompt\n\nDATOS DE LA COMUNIDAD:\n$context\n\nRealiza un análisis profundo y proporciona insights accionables en formato JSON.';

      final responseStream = _chatSession!.sendMessageStream(
        Content.text(fullPrompt),
      );
      String fullResponseText = '';
      String currentMessageId = DateTime.now().millisecondsSinceEpoch
          .toString(); // ID para el mensaje real
      bool firstChunk = true;

      // Remover el placeholder antes de añadir el mensaje real
      _messages.removeWhere((m) => m.id.startsWith('analysis_placeholder'));

      await for (final chunk in responseStream) {
        final text = chunk.text ?? '';
        fullResponseText += text;

        if (firstChunk) {
          setState(() {
            _messages.add(
              AIMessage(
                id: currentMessageId,
                content: fullResponseText,
                type: MessageType.ai, // Se actualizará a Analysis
                timestamp: DateTime.now(),
                isStreaming: true,
              ),
            );
          });
          firstChunk = false;
        } else {
          setState(() {
            int msgIndex = _messages.indexWhere(
              (m) => m.id == currentMessageId,
            );
            if (msgIndex != -1) {
              _messages[msgIndex] = AIMessage(
                id: _messages[msgIndex].id,
                content: fullResponseText,
                type: _messages[msgIndex].type,
                timestamp: _messages[msgIndex].timestamp,
                isStreaming: true,
              );
            }
          });
        }
        _scrollToBottom();
      }
      await _processFinalGeminiResponse(fullResponseText, currentMessageId);
    } catch (e) {
      _messages.removeWhere(
        (m) => m.id.startsWith('analysis_placeholder'),
      ); // Asegurar que se quite
      _handleGeminiError(e);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // Método especializado para análisis multimedia con imágenes del chat
  Future<void> _performMultimediaAnalysis(String analysisPrompt, String context) async {
    if (_communityData == null) {
      _showErrorOnUIThread('No hay datos de la comunidad cargados para análisis.');
      return;
    }

    try {
      // Crear partes de contenido multimodal
      List<Part> contentParts = [];
      
      // Agregar el prompt de análisis y contexto
      contentParts.add(TextPart(
        '$analysisPrompt\n\nDATOS DE LA COMUNIDAD:\n$context\n\n'
        'ANÁLISIS DE IMÁGENES: A continuación se incluyen todas las imágenes compartidas en el chat. '
        'Analízalas junto con el contexto para proporcionar insights completos.\n\n'
        'Realiza un análisis profundo y proporciona insights accionables en formato JSON.'
      ));

      // Agregar todas las imágenes del chat
      int imagesProcessed = 0;
      for (var imageData in _communityData!.images) {
        try {
          final imageUrl = imageData['fileUrl'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            // Descargar la imagen desde Firebase Storage
            final response = await http.get(Uri.parse(imageUrl));
            if (response.statusCode == 200) {
              contentParts.add(DataPart('image/jpeg', response.bodyBytes));
              imagesProcessed++;
            }
          }
        } catch (e) {
          print('Error procesando imagen ${imageData['fileName']}: $e');
          // Continuar con la siguiente imagen
        }
      }

      // Agregar información sobre archivos (sin contenido binario)
      if (_communityData!.files.isNotEmpty) {
        String filesInfo = '\n\nARCHIVOS COMPARTIDOS:\n';
        for (var file in _communityData!.files) {
          filesInfo += '- ${file['fileName']} (${_formatFileSize(file['fileSize'] ?? 0)}) - '
              'Compartido por: ${file['senderUser']} - '
              'Fecha: ${file['timestamp']}\n';
        }
        contentParts.add(TextPart(filesInfo));
      }

      // Remover el placeholder
      _messages.removeWhere((m) => m.id.startsWith('analysis_placeholder'));

      // Enviar análisis multimedia a la IA
      final response = await _chatSession!.sendMessage(Content.multi(contentParts));
      final aiResponseText = response.text ?? 'No se pudo completar el análisis multimedia.';

      // Crear mensaje con el resultado
      final aiMessage = AIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: aiResponseText,
        type: MessageType.analysis,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
      });

      _scrollToBottom();
      _processParsedContent(aiResponseText, aiMessage);

    } catch (e) {
      _showErrorOnUIThread('Error en análisis multimedia: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // Helper para formatear tamaño de archivos
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getAnalysisPrompt(AnalysisType type) {
    // Tus prompts de análisis son buenos. Solo asegúrate que "type": "analysis" esté en el JSON.
    // Y que los nombres de campos como "summary", "insights", "recommendations" sean consistentes.
    switch (type) {
      case AnalysisType.chat:
        return '''
Analiza las conversaciones del chat para identificar:
1. Tareas mencionadas pero no creadas
2. Problemas o bloqueadores discutidos
3. Decisiones que requieren seguimiento
4. Colaboraciones sugeridas
5. Deadlines mencionados

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Resumen ejecutivo del análisis del chat.",
  "insights": ["Insight sobre tema X.", "Observación sobre patrón Y."],
  "action_items": ["Crear tarea para Z.", "Hacer seguimiento de decisión A."],
  "mentioned_deadlines": [{"task": "Descripción tarea", "date": "YYYY-MM-DD"}],
  "collaboration_opportunities": ["Conectar a Miembro1 con Miembro2 sobre tema B."]
}
''';
      case AnalysisType.workload:
        return '''
Analiza la distribución de carga de trabajo basado en el número de tareas activas por miembro y su disponibilidad:
1. Balance de tareas entre miembros.
2. Identificar posible sobrecarga o subutilización.
3. Sugerir redistribución si es necesario y posible.
4. Evaluar capacidad general del equipo para nuevas tareas.

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Estado general de la carga de trabajo del equipo.",
  "workload_distribution": {"nombre_miembro (id_miembro)": "numero_tareas_activas"},
  "overloaded_members": ["miembro_sobrecargado_1 (id)", "miembro_sobrecargado_2 (id)"],
  "underutilized_members": ["miembro_subutilizado_1 (id)"],
  "redistribution_suggestions": ["Sugerencia para redistribuir tarea X.", "Considerar asignar nueva tarea a Miembro Y."]
}
''';
      case AnalysisType.sentiment:
        return '''
Analiza el sentimiento y moral del equipo basado en los mensajes recientes:
1. Tono general de las conversaciones (positivo, neutral, negativo).
2. Indicadores de estrés, frustración o desmotivación.
3. Niveles de colaboración y apoyo mutuo visibles.
4. Satisfacción general implícita o explícita.

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Estado emocional general del equipo.",
  "overall_sentiment": "positivo|neutral|negativo",
  "key_themes_positive": ["Tema positivo 1.", "Tema positivo 2."],
  "key_themes_negative_or_stress": ["Indicador de estrés 1.", "Frustración sobre tema X."],
  "collaboration_level_observed": "alto|medio|bajo",
  "recommendations": ["Recomendación para mejorar el ánimo.", "Sugerencia para fomentar colaboración en X."]
}
''';
      case AnalysisType.productivity:
        return '''
Analiza la productividad del equipo basado en las tareas actuales y su estado:
1. Proporción de tareas completadas vs. pendientes/en progreso (si se tiene historial).
2. Posibles cuellos de botella (ej. muchas tareas en un estado específico o con un miembro).
3. Eficiencia en la transición entre estados de tareas.
4. Tareas que llevan mucho tiempo en un estado.

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Análisis general de la productividad del equipo.",
  "task_status_breakdown": {"por hacer": "count1", "en progreso": "count2", "por revisar": "count3", "completado": "count4"},
  "potential_bottlenecks": ["Muchas tareas asignadas a Miembro X.", "Tareas estancadas en estado 'Por Revisar'."],
  "long_pending_tasks": [{"task_title": "Tarea A", "days_pending": "N days"}, {"task_title": "Tarea B", "days_pending": "M days"}],
  "efficiency_tips": ["Sugerencia para agilizar revisiones.", "Considerar dividir tarea compleja Y."]
}
''';
      case AnalysisType.deadlines:
        return '''
Analiza deadlines y planificación de las tareas actuales:
1. Tareas con riesgo de retraso (comparar `dueDate` con fecha actual y estado actual).
2. Conflictos de calendario o deadlines muy ajustados entre tareas del mismo miembro.
3. Optimización de fechas o prioridades sugeridas.
4. Alertas tempranas sobre tareas críticas próximas a vencer.

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Estado general de los deadlines y la planificación.",
  "at_risk_tasks": [{"task_title": "Tarea X", "due_date": "YYYY-MM-DD", "assigned_to": "NombreMiembro", "risk_level": "alto|medio|bajo", "reason": "Motivo del riesgo (ej. muy cerca y aún 'por hacer')."}],
  "upcoming_critical_deadlines_next_7_days": [{"task_title": "Tarea Crítica Y", "due_date": "YYYY-MM-DD", "priority": "Urgente|Alta"}],
  "planning_recommendations": ["Sugerencia para re-planificar Tarea Z.", "Considerar priorizar Tarea A debido a su deadline."]
}
''';
      case AnalysisType.multimedia:
        return '''
Analiza todo el contenido multimedia (imágenes y archivos) compartido en el chat de la comunidad:
1. Patrones en el tipo de contenido compartido (documentos, capturas, fotos, etc.)
2. Relación del contenido multimedia con las tareas y proyectos activos
3. Oportunidades de organización o mejora basadas en los archivos compartidos
4. Insights sobre la colaboración y comunicación visual del equipo
5. Sugerencias para mejor gestión de los recursos compartidos

IMPORTANTE: Analizarás las imágenes del chat automáticamente. Este análisis incluye TODAS las imágenes compartidas en el chat.

Formato de respuesta:
{
  "type": "analysis", 
  "summary": "Resumen del análisis del contenido multimedia de la comunidad.",
  "content_patterns": ["Patrón observado en tipo de archivos", "Tendencia en compartir imágenes"],
  "project_relationships": ["Conexión entre imagen X y proyecto Y", "Archivos relacionados con tarea Z"],
  "collaboration_insights": ["Insight sobre cómo el equipo usa multimedia", "Observación sobre comunicación visual"],
  "organization_suggestions": ["Sugerencia para organizar archivos", "Recomendación para gestión de imágenes"],
  "images_analyzed": "numero_total_de_imagenes_analizadas",
  "files_analyzed": "numero_total_de_archivos_analizados"
}
''';
    }
  }

  Future<void> _createTaskFromSuggestion(
    Map<String, dynamic> suggestion,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorOnUIThread('Debes estar autenticado para crear tareas.');
      return;
    }

    try {
      final communitySnap = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();
      final communityName =
          communitySnap.data()?['name'] as String? ?? 'Comunidad Desconocida';

      DateTime? dueDate;
      if (suggestion['dueDate'] is String &&
          (suggestion['dueDate'] as String).isNotEmpty) {
        try {
          dueDate = DateTime.parse(suggestion['dueDate']);
        } catch (e) {
          print(
            'Error parsing dueDate from suggestion: ${suggestion['dueDate']}. Error: $e',
          );
          // No asignar fecha si el parseo falla, o asignar un default si se prefiere
        }
      }

      String? assignedToId = suggestion['assignedToId'] == 'null'
          ? null
          : suggestion['assignedToId'];
      String? assignedToName =
          suggestion['assignedToName'] == 'null' ||
              suggestion['assignedToName'] == 'Sin asignar'
          ? null
          : suggestion['assignedToName'];
      String? assignedToImageUrl;

      // Si tenemos ID pero no nombre, o viceversa, intentar obtenerlo de _communityData
      if (assignedToId != null &&
          (assignedToName == null || assignedToName == "Sin asignar") &&
          _communityData != null) {
        final member = _communityData!.members.firstWhere(
          (m) => m['uid'] == assignedToId,
          orElse: () => {},
        );
        if (member.isNotEmpty) {
          assignedToName = member['displayName'];
          assignedToImageUrl = member['photoURL'];
        }
      } else if (assignedToName != null &&
          assignedToName != "Sin asignar" &&
          assignedToId == null &&
          _communityData != null) {
        final member = _communityData!.members.firstWhere(
          (m) => m['displayName'] == assignedToName,
          orElse: () => {},
        );
        if (member.isNotEmpty) {
          assignedToId = member['uid'];
          assignedToImageUrl = member['photoURL'];
        }
      } else if (assignedToId != null && _communityData != null) {
        // Si tenemos ID y nombre (o el nombre es "Sin asignar"), buscar imagen
        final member = _communityData!.members.firstWhere(
          (m) => m['uid'] == assignedToId,
          orElse: () => {},
        );
        if (member.isNotEmpty) {
          assignedToImageUrl = member['photoURL'];
          if (assignedToName == null || assignedToName == "Sin asignar")
            assignedToName =
                member['displayName']; // Corregir nombre si es genérico
        }
      }

      final taskPriority = task_utils.TaskUtils.parseTaskPriority(
        suggestion['priority'] as String?,
      );

      final docRef = await task_utils.TaskUtils.createTask(
        communityId: widget.communityId,
        title: suggestion['title'] as String? ?? 'Tarea Sugerida',
        description: suggestion['description'] as String? ?? '',
        priority: taskPriority,
        initialState: task_utils.TaskState.toDo,
        assignedToId: assignedToId,
        assignedToName: assignedToName, // Puede ser null si no se asigna
        assignedToImageUrl: assignedToImageUrl,
        dueDate: dueDate,
        creatorId: user.uid, // O un ID/Nombre especial para la IA
        creatorName: 'Asistente IA',
        creatorImageUrl: null, // O un avatar genérico para la IA
        communityName: communityName,
        aiGenerated: true,
        aiReason: suggestion['reason'] as String?,
        aiConfidence: (suggestion['confidence'] as num?)?.toDouble(),
      );

      if (docRef != null) {
        _showSuccessOnUIThread(
          '✅ Tarea "${suggestion['title']}" creada exitosamente.',
        );
        _loadCommunityData(); // Recargar datos para reflejar la nueva tarea.
      } else {
        _showErrorOnUIThread(
          'Error al crear la tarea desde la sugerencia de IA.',
        );
      }
    } catch (e) {
      print("Error creando tarea desde sugerencia: $e");
      _showErrorOnUIThread(
        'Error procesando sugerencia de tarea: ${e.toString()}',
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // En _AIAssistantScreenState

  Widget _buildMessageBubble(AIMessage message) {
    final theme = Theme.of(context);
    final isUser = message.type == MessageType.user;
    final isError = message.type == MessageType.error;

    Color backgroundColor;
    Color textColor;
    IconData? leadingIcon;

    if (isError) {
      backgroundColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
      leadingIcon = Icons.error_outline_rounded;
    } else if (isUser) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.surfaceContainerHighest;
    } else {
      backgroundColor = theme.colorScheme.surface;
      textColor = theme.colorScheme.onSurface;
      switch (message.type) {
        case MessageType
            .suggestion: // Este tipo ahora cubre crear, actualizar y eliminar
          // El icono específico (bombilla, editar, eliminar) se podría manejar
          // dentro de las tarjetas o decidir uno genérico aquí.
          // Por ahora, usaremos uno genérico para sugerencias.
          if (message.multipleTasks != null) {
            leadingIcon = Icons.add_task_rounded; // Para crear
          } else if (message.updateTaskData != null) {
            leadingIcon = Icons.edit_note_rounded; // Para actualizar
          } else if (message.deleteTaskData != null) {
            leadingIcon = Icons.delete_sweep_rounded; // Para eliminar
          } else {
            leadingIcon =
                Icons.lightbulb_outline_rounded; // Genérico si no es ninguno
          }
          break;
        case MessageType.analysis:
          leadingIcon = Icons.analytics_outlined;
          break;
        default: // AI general
          leadingIcon = Icons.psychology_outlined;
      }
    }

    Widget contentTextWidget;
    // Texto por defecto si el contenido está vacío pero hay datos específicos
    String defaultText = "";
    if (message.content.isEmpty) {
      if (message.multipleTasks != null) {
        defaultText = "He encontrado algunas tareas que podrían interesarte:";
      } else if (message.updateTaskData != null) {
        defaultText = "Tengo una sugerencia para actualizar una tarea:";
      } else if (message.deleteTaskData != null) {
        defaultText = "Creo que podríamos eliminar una tarea:";
      } else if (message.analysisData != null) {
        defaultText = "Aquí tienes un análisis:";
      }
    }
    final String messageContentToShow = message.content.isNotEmpty
        ? message.content
        : defaultText;

    if (message.isStreaming && !isUser && !isError) {
      contentTextWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              messageContentToShow, // Usar el contenido con posible default
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
          if (messageContentToShow.isNotEmpty) const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    } else {
      contentTextWidget = Text(
        messageContentToShow, // Usar el contenido con posible default
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: fontFamilyPrimary,
          color: textColor,
          height: 1.4,
        ),
      );
    }

    // Para depuración:
    // if (message.type == MessageType.suggestion) {
    //    print("----------- BUBBLE DEBUG (ID: ${message.id}) -----------");
    //    print("Content: ${message.content}");
    //    print("IsStreaming: ${message.isStreaming}");
    //    print("Has multipleTasks: ${message.multipleTasks != null}");
    //    print("Has updateTaskData: ${message.updateTaskData != null}");
    //    print("Has deleteTaskData: ${message.deleteTaskData != null}");
    //    print("----------------------------------------------------");
    // }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: isError
                        ? LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade700],
                          )
                        : LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    leadingIcon ?? Icons.psychology_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              if (!isUser) const SizedBox(width: 12),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                    border: !isUser && !isError
                        ? Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (messageContentToShow
                          .isNotEmpty) // Solo mostrar si hay algún contenido textual
                        contentTextWidget,
                      if (messageContentToShow
                          .isNotEmpty) // Solo mostrar timestamp si hubo texto
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(message.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: textColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isUser)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        FirebaseAuth.instance.currentUser?.photoURL != null
                        ? NetworkImage(
                            FirebaseAuth.instance.currentUser!.photoURL!,
                          )
                        : null,
                    child: FirebaseAuth.instance.currentUser?.photoURL == null
                        ? Icon(
                            Icons.person,
                            size: 20,
                            color: theme.colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ),
            ],
          ),

          // --- SECCIÓN DE TARJETAS ADICIONALES ---
          // Solo se muestran si el mensaje NO está en streaming Y los datos existen.

          // Tarjeta de Análisis
          if (message.analysisData != null && !message.isStreaming)
            _buildAnalysisCard(message.analysisData!),

          // Tarjetas de Sugerencias de Tareas (Crear)
          if (message.multipleTasks != null && !message.isStreaming)
            ...message.multipleTasks!.map(
              (taskJson) => _buildTaskSuggestionCard(taskJson),
            ),

          // Tarjeta de Sugerencia de Actualización de Tarea
          if (message.updateTaskData != null &&
              !message.isStreaming) // ✅ AÑADIDO
            _buildUpdateTaskSuggestionCard(message.updateTaskData!),

          // Tarjeta de Sugerencia de Eliminación de Tarea
          if (message.deleteTaskData != null &&
              !message.isStreaming) // ✅ AÑADIDO
            _buildDeleteTaskSuggestionCard(message.deleteTaskData!),
        ],
      ),
    );
  }

  // En AIAssistantScreen.dart ... dentro de _AIAssistantScreenState

  // ... (Widget _buildMessageBubble y otros constructores de UI)

  // Modificar _buildMessageBubble para que llame a los nuevos constructores de tarjetas
  // (Esta parte ya se hizo implícitamente al modificar AIMessage y _processParsedContent,
  // ahora solo necesitamos asegurarnos que se rendericen correctamente)

  // Asegúrate que en _buildMessageBubble, después de renderizar el contenido principal,
  // se añadan las tarjetas correspondientes:

  // ... dentro del Column de _buildMessageBubble, después de mostrar message.content y timestamp:
  /*
    // ...
    // Análisis adicional (solo si no está en streaming)
    if (message.analysisData != null && !message.isStreaming)
      _buildAnalysisCard(message.analysisData!),

    // Sugerencias de NUEVAS tareas (solo si no está en streaming)
    if (message.multipleTasks != null && !message.isStreaming)
      ...message.multipleTasks!.map((task) => _buildTaskSuggestionCard(task)), // Para crear

    // Sugerencias de ACTUALIZACIÓN de tareas (solo si no está en streaming)
    if (message.updateTaskData != null && !message.isStreaming) // Nuevo
      _buildUpdateTaskSuggestionCard(message.updateTaskData!),

    // Sugerencias de ELIMINACIÓN de tareas (solo si no está en streaming)
    if (message.deleteTaskData != null && !message.isStreaming) // Nuevo
      _buildDeleteTaskSuggestionCard(message.deleteTaskData!),
    // ...
  */
  // Esta lógica ya está en tu _buildMessageBubble, solo confirma que los if conditions
  // para updateTaskData y deleteTaskData estén ahí y llamen a los nuevos constructores de widgets.

  // NUEVO: Widget para mostrar sugerencia de ACTUALIZACIÓN
  Widget _buildUpdateTaskSuggestionCard(Map<String, dynamic> suggestion) {
    final theme = Theme.of(context);
    final taskId = suggestion['taskId'] as String?;
    final updates = suggestion['updates'] as Map<String, dynamic>? ?? {};
    final reason = suggestion['reason'] as String?;

    if (taskId == null) return SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12, left: 48), // Alineado
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(
          0.1,
        ), // Color distintivo para actualización
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Sugerencia de Actualización',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Tarea ID: $taskId',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
            ),
          ),
          if (updates.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Cambios propuestos:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            ...updates.entries.map((entry) {
              String displayValue = entry.value.toString();
              if (entry.key == 'priority')
                displayValue = task_utils.TaskUtils.parseTaskPriority(
                  entry.value as String?,
                ).displayName;
              if (entry.key == 'state')
                displayValue = task_utils.TaskUtils.parseTaskState(
                  entry.value as String?,
                ).displayName;
              if (entry.key == 'dueDate' && entry.value != null)
                displayValue = _formatDate(entry.value);

              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                child: Text(
                  '• ${entry.key}: $displayValue',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                  ),
                ),
              );
            }),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.orange.shade700.withOpacity(0.7),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade700.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    _showInfo('Sugerencia de actualización rechazada.'),
                child: Text(
                  'Rechazar',
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  'Cambiar',
                  style: TextStyle(fontFamily: fontFamilyPrimary),
                ),
                onPressed: () => _handleUpdateTaskSuggestion(suggestion),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NUEVO: Widget para mostrar sugerencia de ELIMINACIÓN
  Widget _buildDeleteTaskSuggestionCard(Map<String, dynamic> suggestion) {
    final theme = Theme.of(context);
    final taskId = suggestion['taskId'] as String?;
    final taskTitle = suggestion['taskTitle'] as String?;
    final reason = suggestion['reason'] as String?;

    if (taskId == null) return SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12, left: 48), // Alineado
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(
          0.5,
        ), // Color distintivo para eliminación
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Sugerencia de Eliminación',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Tarea: ${taskTitle ?? taskId}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
            ),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.error.withOpacity(0.7),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.error.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    _showInfo('Sugerencia de eliminación rechazada.'),
                child: Text(
                  'Rechazar',
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(
                  'Borrar',
                  style: TextStyle(fontFamily: fontFamilyPrimary),
                ),
                onPressed: () => _handleDeleteTaskSuggestion(suggestion),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ... resto del archivo AIAssistantScreen.dart

  Widget _buildAnalysisCard(Map<String, dynamic> analysisData) {
    final theme = Theme.of(context);
    List<Widget> contentWidgets = [];

    // Summary (if exists and not empty)
    final summary = analysisData['summary'] as String?;
    if (summary != null && summary.isNotEmpty) {
      contentWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Insights
    final insights = analysisData['insights'] as List?;
    if (insights != null && insights.isNotEmpty) {
      contentWidgets.add(
        Text(
          'Insights Clave:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
          ),
        ),
      );
      contentWidgets.add(const SizedBox(height: 4));
      contentWidgets.addAll(
        insights.cast<String>().map(
          (insight) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    insight,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      contentWidgets.add(const SizedBox(height: 12));
    }

    // Recommendations / Action Items (Combined)
    List<String> recommendations = [];
    if (analysisData['recommendations'] is List)
      recommendations.addAll(
        (analysisData['recommendations'] as List).cast<String>(),
      );
    if (analysisData['action_items'] is List)
      recommendations.addAll(
        (analysisData['action_items'] as List).cast<String>(),
      );
    // Add other recommendation-like fields if your Gemini prompt generates them (e.g., efficiency_tips)

    if (recommendations.isNotEmpty) {
      contentWidgets.add(
        Text(
          'Recomendaciones/Acciones:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
          ),
        ),
      );
      contentWidgets.add(const SizedBox(height: 4));
      contentWidgets.addAll(
        recommendations.map(
          (rec) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: theme.colorScheme.secondary.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      contentWidgets.add(const SizedBox(height: 12));
    }

    // Metrics (if any)
    final metrics = analysisData['metrics'] as Map?;
    if (metrics != null && metrics.isNotEmpty) {
      contentWidgets.add(
        Text(
          'Métricas Adicionales:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
          ),
        ),
      );
      contentWidgets.add(const SizedBox(height: 4));
      metrics.forEach((key, value) {
        contentWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              '• ${key.toString().replaceAll("_", " ")}: ${value.toString()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: fontFamilyPrimary,
              ),
            ),
          ),
        );
      });
    }

    if (contentWidgets.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(
        top: 12,
        left: 48,
      ), // Alineado con el contenido del mensaje AI (ancho del avatar + padding)
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(
          0.15,
        ), // Color más sutil
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentWidgets,
      ),
    );
  }

  Widget _buildTaskSuggestionCard(Map<String, dynamic> suggestion) {
    final theme = Theme.of(context);
    final taskPriority = task_utils.TaskUtils.parseTaskPriority(
      suggestion['priority'] as String?,
    );

    return Container(
      margin: const EdgeInsets.only(top: 12, left: 48), // Alineado
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion['title'] as String? ?? 'Tarea Sugerida',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (suggestion['description'] != null &&
              (suggestion['description'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              suggestion['description'] as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                'Prioridad: ${taskPriority.displayName}',
                taskPriority.getColor(),
              ),
              if (suggestion['assignedToName'] != null &&
                  (suggestion['assignedToName'] as String).isNotEmpty &&
                  suggestion['assignedToName'] != 'Sin asignar')
                _buildInfoChip(
                  'Asignar a: ${suggestion['assignedToName']}',
                  theme.colorScheme.secondary,
                ),
              if (suggestion['dueDate'] != null &&
                  (suggestion['dueDate'] as String).isNotEmpty)
                _buildInfoChip(
                  'Fecha Límite: ${_formatDate(suggestion['dueDate'])}',
                  theme.colorScheme.tertiary,
                ),
            ],
          ),
          if (suggestion['reason'] != null &&
              (suggestion['reason'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion['reason'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    _showInfo('Sugerencia rechazada por el usuario.'),
                icon: Icon(Icons.close_rounded, size: 18),
                label: Text(
                  'Rechazar',
                  style: TextStyle(fontFamily: fontFamilyPrimary),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _createTaskFromSuggestion(suggestion),
                icon: Icon(Icons.add_task_rounded, size: 18),
                label: Text(
                  'Crear',
                  style: TextStyle(fontFamily: fontFamilyPrimary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ), // Un poco más de padding vertical
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Más sutil
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: fontFamilyPrimary,
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null || (date is String && date.isEmpty)) return 'Sin fecha';
    try {
      DateTime parsedDate;
      if (date is String) {
        parsedDate = DateTime.parse(
          date,
        ); // Asume formato ISO 8601 (YYYY-MM-DD)
      } else if (date is DateTime) {
        parsedDate = date;
      } else if (date is Timestamp) {
        parsedDate = date.toDate();
      } else {
        return 'Fecha inválida';
      }
      return DateFormat(
        'dd MMM yyyy',
        'es_ES',
      ).format(parsedDate); // Formato más legible y localizado
    } catch (e) {
      print("Error formateando fecha '$date': $e");
      return date is String
          ? date
          : 'Fecha inválida'; // Devuelve el string original si no se puede parsear
    }
  }

  // --- Show Snackbars on UI Thread ---
  void _showErrorOnUIThread(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showError(message);
    });
  }

  void _showSuccessOnUIThread(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSuccess(message);
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: fontFamilyPrimary)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: fontFamilyPrimary)),
        backgroundColor:
            Colors.green[700], // Un verde más oscuro para mejor contraste
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: fontFamilyPrimary)),
        backgroundColor: Colors.blue[700], // Un azul más oscuro
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool geminiReady = _model != null && _chatSession != null;
    final bool canInteract =
        geminiReady && !_isLoadingData && !_isTyping && !_isAnalyzing;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente IA',
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onBackground,
                    fontSize: 18,
                  ),
                ),
                if (_isLoadingData || _isAnalyzing || _isTyping)
                  Text(
                    _isLoadingData
                        ? 'Cargando datos...'
                        : (_isAnalyzing
                              ? 'Analizando...'
                              : (_isTyping ? 'IA está respondiendo...' : '')),
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 12,
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Botón de opciones de chat
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.colorScheme.primary,
            ),
            tooltip: 'Opciones de chat',
            onSelected: (value) async {
              switch (value) {
                case 'clear':
                  await _showClearChatDialog();
                  break;
                case 'refresh':
                  await _loadChatHistory();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Actualizar chat',
                      style: TextStyle(fontFamily: fontFamilyPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.clear_all,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Limpiar chat',
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          PopupMenuButton<AnalysisType>(
            icon: Icon(
              Icons.analytics_outlined,
              color: canInteract
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            tooltip: 'Realizar Análisis con IA',
            onSelected: _performDeepAnalysis,
            enabled: canInteract,
            itemBuilder: (context) => AnalysisType.values
                .map(
                  (type) => PopupMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(
                          _getAnalysisIcon(type),
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 12),
                        Text(
                          _getAnalysisDisplayName(type),
                          style: TextStyle(fontFamily: fontFamilyPrimary),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(vertical: 16),
              itemCount:
                  _messages.length +
                  (_isTyping &&
                          geminiReady &&
                          !_messages.any((m) => m.isStreaming)
                      ? 1
                      : 0),
              itemBuilder: (context, index) {
                bool showTypingIndicator =
                    _isTyping &&
                    geminiReady &&
                    !_messages.any(
                      (m) => m.isStreaming && m.type != MessageType.user,
                    );
                if (index == _messages.length && showTypingIndicator) {
                  return _buildTypingIndicator();
                }
                if (index < _messages.length) {
                  return _buildMessageBubble(_messages[index]);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).padding.bottom * 0.5,
            ), // Padding para teclado
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(28),
                      // border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)), // Opcional
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: !geminiReady
                                  ? 'Asistente IA no disponible'
                                  : 'Pregunta o pide un análisis...',
                              hintStyle: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.6),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            onSubmitted: (_) =>
                                canInteract ? _sendMessage() : null,
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            enabled: canInteract,
                          ),
                        ),
                        IconButton(
                          onPressed: canInteract ? _showImagePickerOptions : null,
                          icon: Stack(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: canInteract
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.outline,
                              ),
                              if (_selectedImages.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '${_selectedImages.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          tooltip: _selectedImages.isEmpty 
                              ? 'Adjuntar imagen' 
                              : 'Adjuntar imagen (${_selectedImages.length} seleccionadas)',
                        ),
                        IconButton(
                          onPressed: canInteract ? _sendMessage : null,
                          icon: Icon(
                            Icons.send_rounded,
                            color: canInteract
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          tooltip: 'Enviar mensaje',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    // Solo mostrar si no hay un mensaje de IA en streaming
    if (_messages.any(
      (m) =>
          m.isStreaming &&
          m.type != MessageType.user &&
          m.type != MessageType.error,
    )) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'IA está pensando...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers para el PopupMenu de Análisis
  IconData _getAnalysisIcon(AnalysisType type) {
    switch (type) {
      case AnalysisType.chat:
        return Icons.chat_bubble_outline_rounded;
      case AnalysisType.workload:
        return Icons.workspaces_outline;
      case AnalysisType.sentiment:
        return Icons.sentiment_satisfied_alt_outlined;
      case AnalysisType.productivity:
        return Icons.trending_up_rounded;
      case AnalysisType.deadlines:
        return Icons.event_available_outlined;
      case AnalysisType.multimedia:
        return Icons.photo_library_outlined;
    }
  }

  String _getAnalysisDisplayName(AnalysisType type) {
    switch (type) {
      case AnalysisType.chat:
        return 'Analizar Chat';
      case AnalysisType.workload:
        return 'Carga de Trabajo';
      case AnalysisType.sentiment:
        return 'Sentimientos Equipo';
      case AnalysisType.productivity:
        return 'Productividad';
      case AnalysisType.deadlines:
        return 'Deadlines';
      case AnalysisType.multimedia:
        return 'Análisis Multimedia';
    }
  }
}
