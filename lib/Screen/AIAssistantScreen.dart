// lib/screen/AIAssistantScreen.dart CORREGIDO
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:classroom_mejorado/theme/app_typography.dart';

// Configuración de Gemini - REEMPLAZA CON TU API KEY
const String GEMINI_API_KEY = String.fromEnvironment('GEMINI_API_KEY');

enum MessageType { user, ai, suggestion, analysis, error }

enum AnalysisType { chat, workload, sentiment, productivity, deadlines }

class AIMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? taskSuggestion;
  final List<Map<String, dynamic>>? multipleTasks;
  final Map<String, dynamic>? analysisData;
  final bool isStreaming;

  AIMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.taskSuggestion,
    this.multipleTasks,
    this.analysisData,
    this.isStreaming = false,
  });
}

class CommunityData {
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> tasks;
  final Map<String, dynamic> communityInfo;

  CommunityData({
    required this.members,
    required this.messages,
    required this.tasks,
    required this.communityInfo,
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

  // Estado de la aplicación
  bool _isTyping = false;
  bool _isAnalyzing = false;
  bool _isLoadingData = false;
  String _currentStreamingMessage = '';

  // Datos de la comunidad
  CommunityData? _communityData;

  // Cliente de Gemini
  late GenerativeModel _model;
  late ChatSession _chatSession;

  // Configuración avanzada
  final int _maxMessagesToAnalyze = 100;
  final int _maxTasksToAnalyze = 50;
  final Duration _analysisTimeout = const Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _initializeChat();
    _loadCommunityData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeGemini() {
    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: GEMINI_API_KEY,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.9,
          maxOutputTokens: 2048,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
          SafetySetting(
            HarmCategory.dangerousContent,
            HarmBlockThreshold.medium,
          ),
        ],
      );

      _chatSession = _model.startChat(
        history: [Content.text(_getSystemPrompt())],
      );
    } catch (e) {
      _showError('Error inicializando Gemini: $e');
    }
  }

  String _getSystemPrompt() {
    return '''
Eres un asistente de IA especializado en gestión de tareas y análisis de comunidades. Tu trabajo es:

1. ANALIZAR conversaciones de chat para identificar tareas pendientes, problemas y oportunidades
2. SUGERIR tareas específicas con asignaciones inteligentes
3. EVALUAR carga de trabajo y disponibilidad de miembros
4. PROPORCIONAR insights sobre productividad y colaboración

CONTEXTO: Trabajas con una comunidad/equipo que usa una app de gestión de tareas. Tienes acceso a:
- Mensajes del chat de la comunidad
- Tareas existentes y su estado
- Información de miembros
- Fechas y deadlines

FORMATO DE RESPUESTA:
- Para sugerencias de tareas, usa JSON con esta estructura:
{
  "type": "task_suggestion",
  "tasks": [
    {
      "title": "Título claro y conciso",
      "description": "Descripción detallada",
      "priority": "baja|media|alta|urgente",
      "assignedToId": "uid_del_usuario",
      "assignedToName": "Nombre del usuario",
      "dueDate": "YYYY-MM-DD",
      "reason": "Explicación de por qué esta tarea es necesaria",
      "confidence": 0.85
    }
  ]
}

- Para análisis, usa JSON:
{
  "type": "analysis",
  "summary": "Resumen ejecutivo",
  "insights": ["insight1", "insight2"],
  "metrics": {"key": "value"},
  "recommendations": ["rec1", "rec2"]
}

REGLAS:
- Sé específico y accionable
- Considera la carga de trabajo actual
- Asigna tareas según habilidades y disponibilidad
- Usa fechas realistas
- Explica tu razonamiento
- Mantén un tono profesional pero amigable
''';
  }

  void _initializeChat() {
    _messages.add(
      AIMessage(
        id: '1',
        content:
            '¡Hola! Soy tu asistente de IA avanzado para gestión de tareas. Estoy cargando los datos de tu comunidad para ofrecerte análisis inteligentes y sugerencias personalizadas.\n\nPuedo ayudarte con:\n\n🔍 **Análisis Profundo**\n• Análisis de conversaciones del chat\n• Evaluación de carga de trabajo\n• Análisis de sentimientos del equipo\n• Métricas de productividad\n\n📋 **Gestión Inteligente**\n• Creación automática de tareas\n• Asignaciones optimizadas\n• Planificación de deadlines\n• Sugerencias de mejora\n\n¿Qué te gustaría explorar primero?',
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _loadCommunityData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      // Cargar miembros
      final members = await _fetchCommunityMembers();

      // Cargar mensajes del chat
      final messages = await _fetchCommunityMessages();

      // Cargar tareas existentes
      final tasks = await _fetchCommunityTasks();

      // Cargar información de la comunidad
      final communityInfo = await _fetchCommunityInfo();

      _communityData = CommunityData(
        members: members,
        messages: messages,
        tasks: tasks,
        communityInfo: communityInfo,
      );

      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content:
              '✅ **Datos cargados exitosamente**\n\n📊 **Resumen de la comunidad:**\n• ${members.length} miembros activos\n• ${messages.length} mensajes analizados\n• ${tasks.length} tareas en seguimiento\n\n¡Listo para asistirte! Puedes pedirme un análisis completo o hacer preguntas específicas.',
          type: MessageType.ai,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content:
              '❌ Error cargando datos: $e\n\nPuedo seguir funcionando con capacidades limitadas.',
          type: MessageType.error,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      setState(() {
        _isLoadingData = false;
      });
      _scrollToBottom();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityMembers() async {
    try {
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (!communityDoc.exists) return [];

      final List<dynamic> memberUids = communityDoc.get('members') ?? [];
      List<Map<String, dynamic>> membersData = [];

      for (String uid in memberUids) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;

          // Calcular carga de trabajo actual
          final userTasks = await _getUserActiveTasks(uid);

          membersData.add({
            'uid': uid,
            'displayName':
                userData['name'] ??
                userData['displayName'] ??
                'Usuario Desconocido',
            'photoURL': userData['photoURL'],
            'email': userData['email'],
            'activeTasks': userTasks.length,
            'lastActive': userData['lastActive'],
            'skills': userData['skills'] ?? [],
            'availability': userData['availability'] ?? 'disponible',
          });
        }
      }

      return membersData;
    } catch (e) {
      throw Exception('Error fetching members: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityMessages() async {
    try {
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
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityTasks() async {
    try {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .limit(_maxTasksToAnalyze)
          .get();

      return tasksSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'state': data['state'] ?? '',
          'priority': data['priority'] ?? '',
          'assignedToId': data['assignedToId'],
          // ✅ CORREGIDO: Usar ambos nombres para compatibilidad
          'assignedToName': data['assignedToName'] ?? data['assignedToUser'],
          'assignedToImageUrl': data['assignedToImageUrl'],
          'createdAt': data['createdAt'],
          'dueDate': data['dueDate'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Error fetching tasks: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchCommunityInfo() async {
    try {
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (!communityDoc.exists) return {};

      return communityDoc.data()!;
    } catch (e) {
      throw Exception('Error fetching community info: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getUserActiveTasks(String userId) async {
    try {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .where('assignedToId', isEqualTo: userId)
          .where('state', whereIn: ['por hacer', 'en progreso'])
          .get();

      return tasksSnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = AIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: _messageController.text.trim(),
      type: MessageType.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
      _currentStreamingMessage = '';
    });

    final userInput = _messageController.text.trim();
    _messageController.clear();
    _scrollToBottom();

    _generateGeminiResponse(userInput);
  }

  Future<void> _generateGeminiResponse(String userInput) async {
    try {
      // Preparar contexto para Gemini
      final context = _prepareCommunityContext();
      final fullPrompt =
          '''
CONTEXTO DE LA COMUNIDAD:
$context

SOLICITUD DEL USUARIO: $userInput

Analiza la solicitud y proporciona una respuesta útil. Si es una solicitud de análisis o creación de tareas, usa el formato JSON especificado.
''';

      // Enviar a Gemini con streaming
      final response = _chatSession.sendMessageStream(Content.text(fullPrompt));

      String fullResponse = '';

      await for (final chunk in response) {
        fullResponse += chunk.text ?? '';
        setState(() {
          _currentStreamingMessage = fullResponse;
        });
        _scrollToBottom();
      }

      // Procesar respuesta final
      await _processGeminiResponse(fullResponse);
    } catch (e) {
      _handleGeminiError(e);
    } finally {
      setState(() {
        _isTyping = false;
        _currentStreamingMessage = '';
      });
    }
  }

  String _prepareCommunityContext() {
    if (_communityData == null) {
      return 'Datos de la comunidad no disponibles.';
    }

    final members = _communityData!.members;
    final messages = _communityData!.messages
        .take(20)
        .toList(); // Últimos 20 mensajes
    final tasks = _communityData!.tasks;

    return '''
MIEMBROS DE LA COMUNIDAD:
${members.map((m) => '- ${m['displayName']} (ID: ${m['uid']}, ${m['activeTasks']} tareas activas, disponibilidad: ${m['availability']})').join('\n')}

MENSAJES RECIENTES DEL CHAT:
${messages.map((m) {
      final timestamp = m['timestamp'] as Timestamp?;
      final timeStr = timestamp != null ? DateFormat('dd/MM HH:mm').format(timestamp.toDate()) : 'Sin fecha';
      return '[$timeStr] ${m['senderUser']}: ${m['text']}';
    }).join('\n')}

TAREAS ACTUALES:
${tasks.map((t) => '- ${t['title']} (${t['state']}, prioridad: ${t['priority']}, asignado a: ${t['assignedToName'] ?? 'nadie'})').join('\n')}

MÉTRICAS:
- Total miembros: ${members.length}
- Mensajes analizados: ${messages.length}
- Tareas en seguimiento: ${tasks.length}
- Tareas pendientes: ${tasks.where((t) => t['state'] == 'por hacer').length}
- Tareas en progreso: ${tasks.where((t) => t['state'] == 'en progreso').length}
''';
  }

  Future<void> _processGeminiResponse(String response) async {
    try {
      // Intentar extraer JSON de la respuesta
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);

      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final jsonData = json.decode(jsonStr);

        if (jsonData['type'] == 'task_suggestion') {
          _addTaskSuggestionMessage(response, jsonData);
        } else if (jsonData['type'] == 'analysis') {
          _addAnalysisMessage(response, jsonData);
        } else {
          _addRegularMessage(response);
        }
      } else {
        _addRegularMessage(response);
      }
    } catch (e) {
      _addRegularMessage(response); // Fallback a mensaje regular
    }
  }

  void _addTaskSuggestionMessage(
    String response,
    Map<String, dynamic> jsonData,
  ) {
    final tasks = List<Map<String, dynamic>>.from(jsonData['tasks'] ?? []);

    setState(() {
      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: _extractTextFromResponse(response),
          type: MessageType.suggestion,
          timestamp: DateTime.now(),
          multipleTasks: tasks,
        ),
      );
    });
    _scrollToBottom();
  }

  void _addAnalysisMessage(String response, Map<String, dynamic> jsonData) {
    setState(() {
      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: _extractTextFromResponse(response),
          type: MessageType.analysis,
          timestamp: DateTime.now(),
          analysisData: jsonData,
        ),
      );
    });
    _scrollToBottom();
  }

  void _addRegularMessage(String response) {
    setState(() {
      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          type: MessageType.ai,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  String _extractTextFromResponse(String response) {
    // Extraer texto antes del JSON
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    if (jsonMatch != null) {
      return response.substring(0, jsonMatch.start).trim();
    }
    return response;
  }

  void _handleGeminiError(dynamic error) {
    String errorMessage = 'Error de comunicación con IA: ';

    if (error.toString().contains('API_KEY')) {
      errorMessage +=
          'Clave de API inválida. Por favor configura GEMINI_API_KEY.';
    } else if (error.toString().contains('quota')) {
      errorMessage += 'Límite de uso excedido. Intenta más tarde.';
    } else if (error.toString().contains('network')) {
      errorMessage += 'Error de conexión. Verifica tu internet.';
    } else {
      errorMessage += error.toString();
    }

    setState(() {
      _messages.add(
        AIMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: errorMessage,
          type: MessageType.error,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _performDeepAnalysis(AnalysisType type) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      String analysisPrompt = _getAnalysisPrompt(type);
      final context = _prepareCommunityContext();

      final fullPrompt =
          '''
$analysisPrompt

DATOS DE LA COMUNIDAD:
$context

Realiza un análisis profundo y proporciona insights accionables en formato JSON.
''';

      final response = await _chatSession.sendMessage(Content.text(fullPrompt));
      await _processGeminiResponse(response.text ?? 'Error en el análisis');
    } catch (e) {
      _handleGeminiError(e);
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  String _getAnalysisPrompt(AnalysisType type) {
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
  "summary": "Resumen ejecutivo del análisis",
  "insights": ["insight1", "insight2", "insight3"],
  "action_items": ["acción1", "acción2"],
  "mentioned_deadlines": [{"task": "tarea", "date": "YYYY-MM-DD"}],
  "collaboration_opportunities": ["oportunidad1", "oportunidad2"]
}
''';

      case AnalysisType.workload:
        return '''
Analiza la distribución de carga de trabajo:
1. Balance de tareas entre miembros
2. Identificar sobrecarga o subcarga
3. Sugerir redistribución
4. Evaluar capacidad del equipo

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Estado general de la carga de trabajo",
  "workload_distribution": {"member": "tasks_count"},
  "overloaded_members": ["miembro1", "miembro2"],
  "underutilized_members": ["miembro3"],
  "redistribution_suggestions": ["sugerencia1", "sugerencia2"]
}
''';

      case AnalysisType.sentiment:
        return '''
Analiza el sentimiento y moral del equipo:
1. Tono general de las conversaciones
2. Indicadores de estrés o frustración
3. Niveles de colaboración
4. Satisfacción del equipo

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Estado emocional del equipo",
  "overall_sentiment": "positivo|neutral|negativo",
  "stress_indicators": ["indicador1", "indicador2"],
  "collaboration_level": "alto|medio|bajo",
  "recommendations": ["recomendación1", "recomendación2"]
}
''';

      case AnalysisType.productivity:
        return '''
Analiza la productividad del equipo:
1. Velocidad de completación de tareas
2. Patrones de actividad
3. Eficiencia de procesos
4. Cuellos de botella

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Análisis de productividad",
  "completion_rate": "percentage",
  "avg_task_duration": "days",
  "bottlenecks": ["bottleneck1", "bottleneck2"],
  "efficiency_tips": ["tip1", "tip2"]
}
''';

      case AnalysisType.deadlines:
        return '''
Analiza deadlines y planificación:
1. Tareas con riesgo de retraso
2. Conflictos de calendario
3. Optimización de fechas
4. Alertas tempranas

Formato de respuesta:
{
  "type": "analysis",
  "summary": "Estado de deadlines",
  "at_risk_tasks": [{"task": "nombre", "risk_level": "alto|medio|bajo"}],
  "calendar_conflicts": ["conflicto1", "conflicto2"],
  "optimization_suggestions": ["sugerencia1", "sugerencia2"]
}
''';
    }
  }

  // ✅ FUNCIÓN CORREGIDA: Crear tarea con campos consistentes
  Future<void> _createTaskFromSuggestion(
    Map<String, dynamic> suggestion,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Debes estar autenticado para crear tareas');
        return;
      }

      final communitySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      final communityName = communitySnapshot.exists
          ? (communitySnapshot.get('name') as String? ??
                'Comunidad Desconocida')
          : 'Comunidad Desconocida';

      // Convertir fecha string a DateTime si es necesario
      DateTime? dueDate;
      if (suggestion['dueDate'] is String) {
        try {
          dueDate = DateTime.parse(suggestion['dueDate']);
        } catch (e) {
          dueDate = DateTime.now().add(const Duration(days: 7)); // Fallback
        }
      }

      // ✅ VALIDAR Y OBTENER INFORMACIÓN DEL USUARIO ASIGNADO
      String? assignedToId = suggestion['assignedToId'];
      String? assignedToName = suggestion['assignedToName'];
      String? assignedToImageUrl;

      // Buscar la imagen del usuario asignado
      if (assignedToId != null && _communityData != null) {
        final member = _communityData!.members.firstWhere(
          (m) => m['uid'] == assignedToId,
          orElse: () => <String, dynamic>{},
        );
        assignedToImageUrl = member['photoURL'];

        // Si no tenemos el nombre, tomarlo de los datos de la comunidad
        if (assignedToName == null && member.isNotEmpty) {
          assignedToName = member['displayName'];
        }
      }

      // ✅ CORREGIR PRIORIDAD: Convertir a formato correcto con mayúscula inicial
      String priority = _normalizePriority(suggestion['priority'] ?? 'media');

      // ✅ CREAR TAREA CON LOS MISMOS CAMPOS QUE NewTaskScreen
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .add({
            'title': suggestion['title'],
            'description': suggestion['description'],
            'state': 'por hacer',
            'priority': priority, // ✅ CORREGIDO: Usar prioridad normalizada
            // ✅ CAMPOS DE ASIGNACIÓN CONSISTENTES
            'assignedToId': assignedToId,
            'assignedToName':
                assignedToName, // ✅ CORREGIDO: Usar assignedToName no assignedToUser
            'assignedToImageUrl': assignedToImageUrl,

            // Campos del creador
            'createdAtId': user.uid,
            'createdAtName': user.displayName ?? 'AI Assistant',
            'createdAtImageUrl': user.photoURL,

            // Fechas
            'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),

            // Información de la comunidad
            'communityId': widget.communityId,
            'communityName': communityName,

            // Metadata de IA
            'aiGenerated': true,
            'aiReason': suggestion['reason'],
            'aiConfidence': suggestion['confidence'] ?? 0.0,
          });

      _showSuccess('✅ Tarea "${suggestion['title']}" creada exitosamente');

      // Actualizar datos de la comunidad
      _loadCommunityData();
    } catch (e) {
      _showError('Error al crear la tarea: $e');
    }
  }

  // ✅ NUEVA FUNCIÓN: Normalizar prioridad a formato correcto
  String _normalizePriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'baja':
      case 'low':
        return 'Baja';
      case 'media':
      case 'medium':
        return 'Media';
      case 'alta':
      case 'high':
        return 'Alta';
      case 'urgente':
      case 'urgent':
        return 'Urgente';
      default:
        return 'Media'; // Fallback por defecto
    }
  }

  String? _getAssignedUserImage(String? userId) {
    if (userId == null || _communityData == null) return null;

    final member = _communityData!.members.firstWhere(
      (m) => m['uid'] == userId,
      orElse: () => <String, dynamic>{},
    );

    return member['photoURL'];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(AIMessage message) {
    final theme = Theme.of(context);
    final isUser = message.type == MessageType.user;
    final isError = message.type == MessageType.error;

    Color backgroundColor;
    Color textColor;
    IconData? icon;

    if (isError) {
      backgroundColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
      icon = Icons.error_outline;
    } else if (isUser) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else {
      backgroundColor = theme.colorScheme.surface;
      textColor = theme.colorScheme.onSurface;
      icon = _getMessageIcon(message.type);
    }

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
            children: [
              if (!isUser) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: isError
                        ? LinearGradient(colors: [Colors.red, Colors.redAccent])
                        : LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon ?? Icons.psychology,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
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
                      if (message.type == MessageType.analysis)
                        _buildAnalysisHeader(theme),

                      Text(
                        message.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                          if (message.type == MessageType.suggestion)
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: textColor.withOpacity(0.7),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                CircleAvatar(
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
              ],
            ],
          ),

          // Análisis adicional
          if (message.analysisData != null)
            _buildAnalysisCard(message.analysisData!),

          // Sugerencias de tareas
          if (message.taskSuggestion != null)
            _buildTaskSuggestionCard(message.taskSuggestion!),
          if (message.multipleTasks != null)
            ...message.multipleTasks!.map(
              (task) => _buildTaskSuggestionCard(task),
            ),
        ],
      ),
    );
  }

  IconData _getMessageIcon(MessageType type) {
    switch (type) {
      case MessageType.analysis:
        return Icons.analytics;
      case MessageType.suggestion:
        return Icons.lightbulb_outline;
      case MessageType.error:
        return Icons.error_outline;
      default:
        return Icons.psychology;
    }
  }

  Widget _buildAnalysisHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Análisis IA',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: fontFamilyPrimary,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> analysisData) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Análisis Detallado',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          if (analysisData['insights'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Insights:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...List<String>.from(analysisData['insights']).map(
              (insight) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 4,
                      height: 4,
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
          ],

          if (analysisData['recommendations'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Recomendaciones:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...List<String>.from(analysisData['recommendations']).map(
              (rec) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: theme.colorScheme.secondary,
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
          ],
        ],
      ),
    );
  }

  Widget _buildTaskSuggestionCard(Map<String, dynamic> suggestion) {
    final theme = Theme.of(context);
    final confidence = suggestion['confidence'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Sugerencia de Tarea',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            suggestion['title'] ?? 'Sin título',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            suggestion['description'] ?? 'Sin descripción',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                'Prioridad: ${suggestion['priority'] ?? 'Media'}',
                _getPriorityColor(suggestion['priority'] ?? 'media'),
              ),
              if (suggestion['assignedToName'] != null)
                _buildInfoChip(
                  'Asignado: ${suggestion['assignedToName']}',
                  theme.colorScheme.secondary,
                ),
              if (suggestion['dueDate'] != null)
                _buildInfoChip(
                  'Fecha: ${_formatDate(suggestion['dueDate'])}',
                  theme.colorScheme.tertiary,
                ),
            ],
          ),

          if (suggestion['reason'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion['reason'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
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
                onPressed: () {
                  _showInfo('Sugerencia rechazada');
                },
                icon: Icon(Icons.close, size: 16),
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
                icon: Icon(Icons.add_task, size: 16),
                label: Text(
                  'Crear Tarea',
                  style: TextStyle(fontFamily: fontFamilyPrimary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
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

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'baja':
      case 'low':
        return Colors.green;
      case 'media':
      case 'medium':
        return Colors.blue;
      case 'alta':
      case 'high':
        return Colors.orange;
      case 'urgente':
      case 'urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(dynamic date) {
    try {
      if (date is String) {
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(date));
      } else if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      }
      return 'Fecha inválida';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                Icons.psychology,
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
                if (_isLoadingData || _isAnalyzing)
                  Text(
                    _isLoadingData ? 'Cargando datos...' : 'Analizando...',
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
          PopupMenuButton<AnalysisType>(
            icon: Icon(Icons.analytics, color: theme.colorScheme.primary),
            tooltip: 'Análisis IA',
            onSelected: _performDeepAnalysis,
            enabled: !_isAnalyzing && !_isLoadingData,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AnalysisType.chat,
                child: Row(
                  children: [
                    Icon(Icons.chat, size: 20),
                    SizedBox(width: 12),
                    Text('Analizar Chat'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AnalysisType.workload,
                child: Row(
                  children: [
                    Icon(Icons.work, size: 20),
                    SizedBox(width: 12),
                    Text('Carga de Trabajo'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AnalysisType.sentiment,
                child: Row(
                  children: [
                    Icon(Icons.sentiment_satisfied, size: 20),
                    SizedBox(width: 12),
                    Text('Análisis de Sentimientos'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AnalysisType.productivity,
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 20),
                    SizedBox(width: 12),
                    Text('Productividad'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AnalysisType.deadlines,
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20),
                    SizedBox(width: 12),
                    Text('Deadlines'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Barra de entrada
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Pregúntame algo sobre tu equipo...',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: fontFamilyPrimary,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            maxLines: null,
                            enabled: !_isTyping && !_isLoadingData,
                          ),
                        ),
                        IconButton(
                          onPressed: (_isTyping || _isLoadingData)
                              ? null
                              : _sendMessage,
                          icon: Icon(
                            Icons.send_rounded,
                            color: (_isTyping || _isLoadingData)
                                ? theme.colorScheme.outline
                                : theme.colorScheme.primary,
                          ),
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
            child: const Icon(Icons.psychology, color: Colors.white, size: 20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStreamingMessage.isNotEmpty)
                    Text(
                      _currentStreamingMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurface,
                      ),
                    )
                  else
                    Row(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
