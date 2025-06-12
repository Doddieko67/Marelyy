import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio para análisis de archivos e imágenes con IA
class AIFileService {
  static final AIFileService _instance = AIFileService._internal();
  factory AIFileService() => _instance;
  AIFileService._internal();

  // Reemplaza con tu API key de Gemini
  static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
  
  late final GenerativeModel _model;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Dio _dio = Dio();

  /// Inicializar el servicio de IA
  void initialize() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );
  }

  /// Analizar imagen con IA
  Future<Map<String, dynamic>> analyzeImage({
    required String imageUrl,
    required String communityId,
    String? messageId,
    String? customPrompt,
  }) async {
    try {
      // Descargar imagen temporalmente
      final imageFile = await _downloadImageTemporarily(imageUrl);
      if (imageFile == null) {
        throw Exception('No se pudo descargar la imagen');
      }

      // Leer imagen como bytes
      final imageBytes = await imageFile.readAsBytes();

      // Prompt por defecto para análisis de imagen
      final prompt = customPrompt ?? '''
Analiza esta imagen de manera detallada. Proporciona:

1. **Descripción general**: ¿Qué muestra la imagen?
2. **Objetos detectados**: Lista los elementos principales que ves
3. **Texto en la imagen**: Si hay texto, transcríbelo
4. **Contexto educativo**: ¿Cómo podría ser útil en un entorno educativo?
5. **Palabras clave**: Lista 5-10 palabras clave relevantes

Responde en español de manera clara y organizada.
''';

      // Crear contenido para Gemini
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      // Generar respuesta
      final response = await _model.generateContent(content);
      final analysisText = response.text ?? 'No se pudo analizar la imagen';

      // Extraer palabras clave del análisis
      final keywords = _extractKeywords(analysisText);

      // Guardar análisis en Firestore
      final analysisData = {
        'type': 'image_analysis',
        'imageUrl': imageUrl,
        'analysis': analysisText,
        'keywords': keywords,
        'communityId': communityId,
        'messageId': messageId,
        'analyzedAt': FieldValue.serverTimestamp(),
        'analyzedBy': _auth.currentUser?.uid,
      };

      await _saveAnalysis(analysisData);

      // Limpiar archivo temporal
      await imageFile.delete();

      return {
        'success': true,
        'analysis': analysisText,
        'keywords': keywords,
        'type': 'image',
      };
    } catch (e) {
      print('Error analizando imagen: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Analizar documento con IA
  Future<Map<String, dynamic>> analyzeDocument({
    required String documentUrl,
    required String fileName,
    required String communityId,
    String? messageId,
    String? customPrompt,
  }) async {
    try {
      // Determinar tipo de documento
      final fileExtension = fileName.split('.').last.toLowerCase();
      
      if (!_isSupportedDocument(fileExtension)) {
        return {
          'success': false,
          'error': 'Tipo de documento no soportado: $fileExtension',
        };
      }

      // Para documentos de texto, intentar extraer contenido
      String documentContent = '';
      
      if (fileExtension == 'txt') {
        documentContent = await _extractTextFromUrl(documentUrl);
      } else {
        // Para otros tipos, usar descripción básica
        documentContent = 'Documento de tipo $fileExtension: $fileName';
      }

      // Prompt para análisis de documento
      final prompt = customPrompt ?? '''
Analiza este documento y proporciona:

1. **Tipo de documento**: ¿Qué tipo de archivo es?
2. **Contenido principal**: Resume el contenido principal
3. **Temas clave**: Identifica los temas principales
4. **Utilidad educativa**: ¿Cómo puede ser útil para estudiantes?
5. **Palabras clave**: Lista 5-10 palabras clave relevantes

Contenido del documento:
$documentContent

Responde en español de manera clara y organizada.
''';

      // Generar análisis con Gemini
      final response = await _model.generateContent([Content.text(prompt)]);
      final analysisText = response.text ?? 'No se pudo analizar el documento';

      // Extraer palabras clave
      final keywords = _extractKeywords(analysisText);

      // Guardar análisis
      final analysisData = {
        'type': 'document_analysis',
        'documentUrl': documentUrl,
        'fileName': fileName,
        'fileExtension': fileExtension,
        'analysis': analysisText,
        'keywords': keywords,
        'communityId': communityId,
        'messageId': messageId,
        'analyzedAt': FieldValue.serverTimestamp(),
        'analyzedBy': _auth.currentUser?.uid,
      };

      await _saveAnalysis(analysisData);

      return {
        'success': true,
        'analysis': analysisText,
        'keywords': keywords,
        'type': 'document',
        'fileExtension': fileExtension,
      };
    } catch (e) {
      print('Error analizando documento: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Buscar contenido usando IA
  Future<List<Map<String, dynamic>>> searchContentWithAI({
    required String query,
    required String communityId,
    int limit = 10,
  }) async {
    try {
      // Buscar análisis existentes que coincidan con la consulta
      final searchResults = await _firestore
          .collection('ai_analysis')
          .where('communityId', isEqualTo: communityId)
          .orderBy('analyzedAt', descending: true)
          .limit(50) // Obtener más para filtrar con IA
          .get();

      if (searchResults.docs.isEmpty) {
        return [];
      }

      // Preparar datos para análisis de relevancia
      final analysisTexts = searchResults.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'analysis': data['analysis'] ?? '',
          'keywords': data['keywords'] ?? [],
          'type': data['type'] ?? 'unknown',
          'data': data,
        };
      }).toList();

      // Usar IA para determinar relevancia
      final relevantResults = await _findRelevantContent(query, analysisTexts);

      // Limitar resultados
      return relevantResults.take(limit).toList();
    } catch (e) {
      print('Error buscando con IA: $e');
      return [];
    }
  }

  /// Generar resumen de archivos de la comunidad
  Future<Map<String, dynamic>> generateCommunitySummary({
    required String communityId,
  }) async {
    try {
      // Obtener todos los análisis de la comunidad
      final analysisSnapshot = await _firestore
          .collection('ai_analysis')
          .where('communityId', isEqualTo: communityId)
          .orderBy('analyzedAt', descending: true)
          .limit(20)
          .get();

      if (analysisSnapshot.docs.isEmpty) {
        return {
          'success': false,
          'error': 'No hay contenido analizado en esta comunidad',
        };
      }

      // Preparar contenido para resumen
      final allAnalysis = analysisSnapshot.docs
          .map((doc) => doc.data()['analysis'] as String? ?? '')
          .join('\n\n---\n\n');

      final prompt = '''
Basándote en los siguientes análisis de archivos e imágenes de una comunidad educativa, genera un resumen ejecutivo que incluya:

1. **Temas principales**: ¿Cuáles son los temas más recurrentes?
2. **Tipos de contenido**: ¿Qué tipos de archivos se comparten más?
3. **Actividades educativas**: ¿Qué tipo de actividades se desarrollan?
4. **Recomendaciones**: Sugerencias para mejorar el contenido compartido

Análisis de archivos:
$allAnalysis

Responde en español de manera profesional y organizada.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final summary = response.text ?? 'No se pudo generar el resumen';

      // Contar estadísticas
      final stats = _calculateCommunityStats(analysisSnapshot.docs);

      return {
        'success': true,
        'summary': summary,
        'stats': stats,
        'totalFiles': analysisSnapshot.docs.length,
      };
    } catch (e) {
      print('Error generando resumen: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Descargar imagen temporalmente para análisis
  Future<File?> _downloadImageTemporarily(String imageUrl) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');

      final response = await _dio.download(imageUrl, file.path);
      
      if (response.statusCode == 200) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error descargando imagen: $e');
      return null;
    }
  }

  /// Extraer texto de URL (para archivos de texto)
  Future<String> _extractTextFromUrl(String url) async {
    try {
      final response = await _dio.get(url);
      return response.data.toString();
    } catch (e) {
      print('Error extrayendo texto: $e');
      return 'No se pudo extraer el contenido del archivo';
    }
  }

  /// Verificar si el documento es soportado
  bool _isSupportedDocument(String extension) {
    const supportedTypes = ['txt', 'pdf', 'doc', 'docx', 'md'];
    return supportedTypes.contains(extension);
  }

  /// Extraer palabras clave del análisis
  List<String> _extractKeywords(String analysisText) {
    // Implementación básica de extracción de palabras clave
    final words = analysisText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((word) => word.length > 3)
        .toSet()
        .toList();

    // Filtrar palabras comunes y seleccionar las más relevantes
    final stopWords = {
      'esta', 'esta', 'este', 'estos', 'estas', 'para', 'con', 'por', 'una', 
      'uno', 'como', 'que', 'son', 'tiene', 'puede', 'ser', 'muy', 'más'
    };

    final keywords = words
        .where((word) => !stopWords.contains(word))
        .take(10)
        .toList();

    return keywords;
  }

  /// Guardar análisis en Firestore
  Future<void> _saveAnalysis(Map<String, dynamic> analysisData) async {
    try {
      await _firestore.collection('ai_analysis').add(analysisData);
    } catch (e) {
      print('Error guardando análisis: $e');
    }
  }

  /// Encontrar contenido relevante usando IA
  Future<List<Map<String, dynamic>>> _findRelevantContent(
    String query, 
    List<Map<String, dynamic>> analysisTexts,
  ) async {
    try {
      // Simplificado: buscar por palabras clave
      final queryWords = query.toLowerCase().split(' ');
      
      final scored = analysisTexts.map((item) {
        final text = (item['analysis'] as String).toLowerCase();
        final keywords = item['keywords'] as List<dynamic>;
        
        int score = 0;
        
        // Puntuar por aparición en análisis
        for (final word in queryWords) {
          if (text.contains(word)) score += 2;
        }
        
        // Puntuar por palabras clave
        for (final keyword in keywords) {
          for (final word in queryWords) {
            if (keyword.toString().toLowerCase().contains(word)) score += 3;
          }
        }
        
        return {...item, 'relevanceScore': score};
      }).where((item) => item['relevanceScore'] > 0).toList();

      // Ordenar por relevancia
      scored.sort((a, b) => (b['relevanceScore'] as int).compareTo(a['relevanceScore'] as int));
      
      return scored;
    } catch (e) {
      print('Error determinando relevancia: $e');
      return [];
    }
  }

  /// Calcular estadísticas de la comunidad
  Map<String, dynamic> _calculateCommunityStats(List<QueryDocumentSnapshot> docs) {
    final typeCount = <String, int>{};
    final keywordCount = <String, int>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Contar tipos
      final type = data['type'] as String? ?? 'unknown';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
      
      // Contar palabras clave
      final keywords = data['keywords'] as List<dynamic>? ?? [];
      for (final keyword in keywords) {
        final keywordStr = keyword.toString();
        keywordCount[keywordStr] = (keywordCount[keywordStr] ?? 0) + 1;
      }
    }

    // Top 10 palabras clave
    final topKeywords = keywordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'typeDistribution': typeCount,
      'topKeywords': topKeywords.take(10).map((e) => {
        'keyword': e.key,
        'count': e.value,
      }).toList(),
      'totalAnalyzed': docs.length,
    };
  }

  /// Obtener análisis existente
  Stream<List<Map<String, dynamic>>> getCommunityAnalysis({
    required String communityId,
    String? type,
  }) {
    Query query = _firestore
        .collection('ai_analysis')
        .where('communityId', isEqualTo: communityId)
        .orderBy('analyzedAt', descending: true);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query.limit(50).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}