// lib/utils/file_utils.dart

/// Formatea un tamaño de archivo en bytes a una cadena legible (B, KB, MB).
String formatFileSize(int? bytes) {
  if (bytes == null || bytes == 0) return '';
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// Detecta automáticamente el tipo de archivo (imagen o archivo genérico) basado en su extensión.
String detectFileType(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;
  const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
  return imageExtensions.contains(extension) ? 'image' : 'file';
}
